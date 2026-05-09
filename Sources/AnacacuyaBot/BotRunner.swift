//
//  BotRunner.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation



/// Top-level orchestrator that wires the inbound Telegram event stream,
/// the LLM client, per-chat memory, and the time-based interjector
/// together.
///
/// Holds no mutable state of its own — all mutability lives in the
/// actors it references — which is why it's expressed as a `Sendable`
/// struct rather than a class or actor. The shape keeps reasoning
/// trivial: the runner is a configuration bundle plus a few
/// orchestration methods, with isolation handled where the data
/// actually lives.
///
/// The update consumer treats Telegram's long-poll endpoint as an event
/// stream. Long polling is event-driven from the bot's perspective:
/// Telegram holds the HTTP request open for up to 30 seconds and
/// returns the moment an update arrives. There is no periodic
/// re-querying against a quiet server.
struct BotRunner: Sendable {
    let telegram: TelegramClient
    let ollama: OllamaClient
    let store: ChatStateStore
    let persona: Persona
    let commands: [any BotCommand]
    
    /// Bot's own username, resolved at startup via `getMe`. Used for
    /// detecting `@` mentions and identifying replies to the bot's own
    /// messages. Resolved up front so a misconfigured token fails
    /// loudly at startup rather than silently on the first message.
    let botUsername: String
}



// MARK: - Basics

extension BotRunner {
    
    /// Bootstraps the runner from environment configuration. Performs
    /// the `getMe` round-trip up front to cache the username and to
    /// surface auth errors immediately rather than at first traffic.
    static func start() async throws -> BotRunner {
        guard let token = ProcessInfo.processInfo.environment["TELEGRAM_BOT_TOKEN"],
              false == token.isEmpty
        else {
            throw BotError.missingToken
        }
        
        let model = ProcessInfo.processInfo.environment["OLLAMA_MODEL"] ?? "smollm2"
        let ollamaURL = ProcessInfo.processInfo.environment["OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        
        let telegram = try await TelegramClient(token: token)
        let me = telegram.botUser
        let username = me.username ?? "bot"
        
        print("🤖 Logged in as @\(username) | model: \(model)")
        
        return BotRunner(
            telegram: telegram,
            ollama: OllamaClient(baseURL: ollamaURL, model: model),
            store: ChatStateStore(),
            persona: .default,
            commands: [
                PromptCommand(),
            ],
            botUsername: username,
        )
    }
    
    
    /// Runs the bot until cancellation. The two long-running concerns —
    /// update consumption and time-based interjection — are sibling
    /// children of a single task group, so cancellation propagates
    /// uniformly and lifecycle is one thing instead of two.
    func run() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.listenForAllMessages() }
            group.addTask { await self.runTimeBasedInterjector() }
        }
    }
    
    
    var botUser: TGUser {
        telegram.botUser
    }
}


// MARK: - Message handling

private extension BotRunner {
    
    /// Consumes Telegram's long-poll event stream indefinitely. Errors
    /// are absorbed with a brief backoff rather than propagated: the
    /// most common failure modes (transient network blips, brief API
    /// hiccups) shouldn't take the bot down — they should resolve on
    /// the next cycle.
    private func listenForAllMessages() async {
        print("📡 Listening for messages...")
        while false == Task.isCancelled {
            do {
                let updates = try await telegram.getUpdates(timeout: 30)
                for update in updates {
                    if let message = update.message {
                        try await handleMessage(message)
                    }
                }
            } catch {
                print("⚠️ Update error: \(error). Backing off 5s.")
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
    
    
    /// Routes a single inbound message. Dispatch is deliberately simple:
    /// if the bot was addressed, it replies; otherwise, if this message
    /// just tripped the count trigger, it interjects; otherwise, silent.
    /// The two paths are mutually exclusive within a single message —
    /// a mention plus a count trigger yields one reply, not two
    /// back-to-back outputs.
    private func handleMessage(_ userMessage: TGMessage) async throws {
        guard let text = userMessage.text, false == text.isEmpty else { return }
        
        let sender = userMessage.from?.username ?? userMessage.from?.firstName ?? "someone"
        let shouldRespondToMessage = isDirectMessage(userMessage) || isMentioned(userMessage) || isReplyToBot(userMessage)
        
        print(
            shouldRespondToMessage ? "👀" : " ",
            "[\(userMessage.chat.title ?? userMessage.chat.username ?? "?")]",
            "\(sender):",
            text
        )
        
        var state = await store.state(for: userMessage.chat)
        
        if let command = commands.first(where: { type(of: $0).matches(text) }) {
            let commandContext = CommandContext(
                persona: persona,
                commandMessage: userMessage,
                botUser: telegram.botUser,
            )
            
            for response in try await command.run(with: text, context: commandContext) {
                switch response {
                case .text(let response):
                    try await send(message: response, inChat: userMessage.chat.id, replyingTo: userMessage.id, chatState: &state)
                }
            }
            
            return
        }
        
        // Uncomment when you're testing in production:
//        return try await send(message: "😴💤 [I'm in maintenance mode]", inChat: msg.chat.id, replyingTo: msg.messageId, chatState: &state)
        
        let chatMessage = ChatMessage(senderName: sender, text: text, isBot: false, isReply: nil != userMessage.replyToMessage)
        let nextStep = await state.register(didReceiveMessage: chatMessage)
        
        if shouldRespondToMessage {
            await respond(in: userMessage.chat, state: &state, inReplyTo: userMessage.replyToMessage, replyTo: userMessage.id)
        }
        else {
            switch nextStep {
            case .interject:
                await interject(in: userMessage.chat, inReplyTo: userMessage.replyToMessage, state: &state)
                
            case .none:
                break
            }
        }
    }
}



// MARK: - Sending messages

private extension BotRunner {
    func send(message: String, inChat chatId: TGChat.ID, replyingTo replyTo: TGMessage.ID?, chatState state: inout ChatState) async throws {
        guard false == message.isEmpty else { return }
        try await telegram.sendMessage(chatId: chatId, text: message.telegram_escapedForMarkdownV2, replyTo: replyTo)
        await state.register(didSendMessage: ChatMessage(
            senderName: botUsername,
            text: message,
            isBot: true,
            isReply: nil != replyTo)
        )
    }
}



// MARK: - Mention detection

private extension BotRunner {
    private func isDirectMessage(_ msg: TGMessage) -> Bool {
        .private == msg.chat.type
    }
    
    /// Reports whether a message addresses the bot directly. Both the
    /// raw text and any structured mention entities are checked because
    /// some clients send entities, some don't, and a substring check
    /// catches both cases without depending on entity reliability.
    private func isMentioned(_ msg: TGMessage) -> Bool {
        guard let text = msg.text else { return false }
        if text.localizedCaseInsensitiveContains("@\(botUsername)") { return true }
        guard let entities = msg.entities else { return false }
        for entity in entities where entity.type == "mention" {
            if let start = text.index(text.startIndex, offsetBy: entity.offset, limitedBy: text.endIndex),
               let end = text.index(start, offsetBy: entity.length, limitedBy: text.endIndex) {
                let mentioned = String(text[start..<end])
                if mentioned.lowercased() == "@\(botUsername.lowercased())" { return true }
            }
        }
        return false
    }
    
    
    /// Reports whether a message is a reply to one of the bot's own
    /// messages. Telegram surfaces the original sender on
    /// `replyToMessage.from`, so the check is a username comparison.
    private func isReplyToBot(_ msg: TGMessage) -> Bool {
        guard let reply = msg.replyToMessage, let from = reply.from else { return false }
        return true == (from.username?.lowercased() == botUsername.lowercased())
    }
    
    
    
    // MARK: - Generation
    
    /// Generates and sends a direct response, threading the result back
    /// into chat history so the bot's own utterances participate in
    /// future context.
    private func respond(
        in chat: TGChat,
        state: inout ChatState,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        replyTo: Int? = nil)
    async {
        let history = await state.recentMessages
        let messages = persona.directResponseMessages(in: chat, botUser: botUser, inReplyTo: repliedToMessage, history: history)
        await sendGeneratedReply(messages: messages, chatId: chat.id, state: &state, replyTo: replyTo)
    }
    
    
    /// Generates and sends an unprompted interjection. Distinguished
    /// from `respond` only by which prompt shape it asks the persona
    /// for — the send-and-record machinery is shared via `generate`.
    private func interject(in chat: TGChat, inReplyTo repliedToMessage: TGRepliedToMessage?, state: inout ChatState) async {
        let history = await state.recentMessages
        guard false == history.isEmpty else { return }
        let messages = persona.interjectionMessages(in: chat, botUser: botUser, inReplyTo: repliedToMessage, history: history)
        await sendGeneratedReply(messages: messages, chatId: chat.id, state: &state, replyTo: nil)
        print("💬 Interjected in chat \(chat.id)")
    }
    
    
    /// Shared completion path: call the model, send the result, record
    /// the bot's own message in chat history. Generation failures are
    /// logged and swallowed; a model hiccup shouldn't take down the
    /// runner — the next event will give it another chance.
    private func sendGeneratedReply(messages: [OllamaMessage], chatId: Int64, state: inout ChatState, replyTo: Int?) async {
        let reply: String
        
        do {
            reply = try await ollama.chat(messages: messages)
        }
        catch {
            print("⚠️ Generation error: \(error)")
            return
        }
        
        let recentSenders = await state.recentMessages
            .filter { false == $0.isBot }
            .map(\.senderName)
        let cleaned = persona.sanitize(
            reply,
            botUsername: botUsername,
            knownSenders: recentSenders
        )
        
        do {
            try await send(message: cleaned, inChat: chatId, replyingTo: replyTo, chatState: &state)
        }
        catch {
            print("⚠️ Failed to send generated reply: \(error)")
        }
    }
    
    
    
    // MARK: - Time-based interjector
    
    /// Background loop that fires unprompted interjections on a random
    /// schedule, independent of message volume. Pairs with the
    /// message-count trigger handled in `handleMessage`: the time-based
    /// path keeps quiet chats from going silent, while the count-based
    /// path scales engagement to busy chats. Two triggers, two
    /// purposes, one shared generation path.
    ///
    /// The initial delay prevents a startup-time burst before any chats
    /// are known to the store.
    private func runTimeBasedInterjector() async {
        // Only think about interjecting after 0.5~2 hours have passed
        try? await Task.sleep(for: .hours(.random(in: 0.5 ... 2)))
        
        while false == Task.isCancelled {
            do {
                // Only think about interjecting every 4~20 hours
                try await Task.sleep(for: .hours(.random(in: 4 ... 20)))
            }
            catch {
                return
            }
            
            guard let randomChat = await store.allChats().randomElement() else { continue }
            
            var state = await store.state(for: randomChat)
            guard await state.stillAllowedToInterjectToday() else { continue }
            
            await interject(in: randomChat, inReplyTo: nil, state: &state)
        }
    }
    
    
    
    // MARK: -
    
    /// Errors that prevent the runner from starting. Distinguished from
    /// runtime errors because these indicate misconfiguration the
    /// operator must address; retrying won't help.
    enum BotError: Error {
        case missingToken
    }
}
