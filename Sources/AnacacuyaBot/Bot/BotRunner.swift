//
//  BotRunner.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation

import CollectionTools



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
    let ollama: Ollama
    let models: (llm: OllamaModel, vision: OllamaModel?)
    let store: ChatStateStore
    let persona: Persona
    let commands: [any BotCommand]
    let limiter: BotLimiter
    
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
        guard let token = UnixEnvironment[.telegramBotToken],
              token.withoutTypeSafety().isNotEmpty
        else {
            throw BotError.missingToken
        }
        
        let telegram = try await TelegramClient(token: token)
        let me = telegram.botUser
        guard let username = me.username else {
            throw BotError.noUsername
        }
        
        let ollamaUrl = UnixEnvironment[.ollamaBaseUrl]
        let ollama = Ollama(baseUrl: ollamaUrl)
        
        let llmModelName = UnixEnvironment[.llmName]
        let visionModelName = UnixEnvironment[.visionModelName]
        
        guard let llmModel = try await ollama.model(named: llmModelName) else {
            throw BotError.failedToLoadLlm
        }
        
        let visionModel: OllamaModel?
        if let visionModelName {
            visionModel = try await ollama.model(named: visionModelName)
        }
        else {
            visionModel = nil
        }
        
        print("🤖 Logged in as @\(username) | llm: \(llmModel)")
        if let visionModel {
            print("👁️  Vision model: \(visionModel)")
        }
        
        return BotRunner(
            telegram: telegram,
            ollama: ollama,
            models: (llm: llmModel, vision: visionModel),
            store: ChatStateStore(),
            persona: .default,
            commands: [
                PromptCommand(),
                DebugShowFullContextCommand(),
            ],
            limiter: BotLimiter(),
            botUsername: username,
        )
    }
    
    
    /// Runs the bot until cancellation. The two long-running concerns —
    /// update consumption and time-based interjection — are sibling
    /// children of a single task group, so cancellation propagates
    /// uniformly and lifecycle is one thing instead of two.
    func run() async {
        await withTaskGroup { group in
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
                let updates = try await telegram.getUpdates()
                for update in updates {
                    if let message = update.message,
                       message.sentDate.isSooner(than: Limits.maxTimeToWaitForModelResponse)
                    {
                        try await handleIncomingMessage(message)
                    }
                }
            }
            catch {
                if let error = error as? TelegramHttpError {
                    print("⚠️", error.localizedDescription)
                }
                else {
                    print("⚠️ Update error:", error)
                }
                print("Backing off for 5s...")
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
    
    
    /// Process the given user message.
    ///
    /// If it's a command message, that command is run. Otherwise, the
    /// message is sent to the LLM to synthesize a response.
    ///
    /// Photos receive special handling: the inbound message's typed
    /// content might live in ``TGMessage/text`` (plain text messages) or
    /// ``TGMessage/caption`` (media messages with a comment), so we
    /// pull from whichever is present. When photos arrive *and* we're
    /// actually going to talk to the LLM about them, the most suitable
    /// rendition is downloaded eagerly up to ``Limits/preferredMaxPhotoSize``
    /// and the bytes ride along on the resulting `ChatMessage`. Downstream,
    /// ``modelForResponse(to:inReplyTo:)`` picks the vision model for
    /// turns whose final user message carries image data.
    ///
    /// The download is deliberately deferred past the command check so a
    /// `/command` accompanied by a photo doesn't burn a Telegram
    /// round-trip on bytes nothing will read.
    private func handleIncomingMessage(_ incomingMessage: TGMessage) async throws {
        // Telegram puts a user's typed content in `text` for plain messages
        // and in `caption` for media messages. Falling through to caption
        // means a photo with a comment behaves the same as a text message
        // to the rest of the dispatch logic.
        let wholeUserText = incomingMessage.text?.nonEmptyOrNil
            ?? incomingMessage.caption?.nonEmptyOrNil
            ?? ""
        
        let photos = incomingMessage.photo ?? []
        
        // Skip messages that carry neither user text nor a photo — service
        // messages, edits we don't care about, etc.
        guard false == wholeUserText.isEmpty || false == photos.isEmpty else { return }
        
        let sender = incomingMessage.from?.nameForLlm ?? "someone"
        let shouldRespondToMessage = shouldRespond(to: incomingMessage)
        
        print(
            shouldRespondToMessage ? "👀" : " ",
            "[\(incomingMessage.chat.title ?? incomingMessage.chat.username ?? "?")]",
            "\(sender)\(photos.isEmpty ? "" : " 📷"):",
            wholeUserText.isEmpty ? "(image)" : wholeUserText
        )
        
        var state = await store.state(for: incomingMessage.chat)
        
        
        if let commandResult = try await runAsCommand(wholeUserText, incomingMessage: incomingMessage, chatState: &state) {
            print("Command result:", commandResult)
            
            switch commandResult {
            case .consumedTurn:
                return
            }
        }
        
        // Photo download deferred until after the command check so a
        // command message with an attached photo doesn't waste a download
        // on bytes the LLM path will never see.
        let imageData = await resolvePhoto(from: photos)
        
        await sendLlmMessage(
            chatState: &state,
            incomingMessage: ChatMessage(
                incomingMessage,
                sender: sender,
                wholeUserText: wholeUserText,
                images: imageData.map { [$0] },
            ),
            shouldRespondToMessage: shouldRespondToMessage,
            inReplyTo: .init(incomingMessage),
        )
    }
    
    
    /// Downloads the photo rendition best suited for vision inference,
    /// or returns `nil` if there's nothing worth downloading.
    ///
    /// Returns `nil` in three cases, each meaning "proceed text-only":
    /// the message had no photos, no vision model is configured to
    /// consume them, or the download itself failed. Errors during
    /// download are logged but don't propagate — a photo turn that loses
    /// its photo is still a valid text turn, and the alternative would
    /// be to drop the whole message over a transient network blip.
    ///
    /// - Parameter photos: All renditions Telegram delivered for this
    ///                     message. Empty array is allowed and yields nil.
    ///
    /// - Returns: Image bytes ready to attach to an `OllamaMessage`, or
    ///            nil when the bot should treat this turn as text-only.
    private func resolvePhoto(from photos: [TGPhotoSize]) async -> Data? {
        guard false == photos.isEmpty,
              nil != models.vision
        else { return nil }
        
        guard let chosen = photos.largest(under: Limits.preferredMaxPhotoSize) else { return nil }
        
        do {
            return try await telegram.downloadFile(fileId: chosen.fileId)
        }
        catch {
            print("⚠️ Couldn't download photo: \(error)")
            return nil
        }
    }
    
    
    /// Attempts to run the given whole user text as a command.
    ///
    /// If the given text cannot be parsed as a command, then no command is run and this returns `.none`
    ///
    /// - Parameters:
    ///   - wholeUserText: The raw text straight from the Telegram user sending a message to this bot
    ///   - userMessage:   The whole message the user sent, including metadata
    ///   - state:         The state of the chat in which this command would be run
    ///
    /// - Returns: The result of running the command, or `.none` if a well-formed command couldn't be parsed out of `wholeUserText`
    private func runAsCommand(_ wholeUserText: String, incomingMessage: TGMessage, chatState state: inout ChatState) async throws -> CommandRunResult? {
        if let command = commands.first(where: { type(of: $0).matches(wholeUserText, as: botUser) }),
           let parsedCommand = type(of: command).parsing(wholeUserText, as: botUser)
        {
            let arguments = parsedCommand.body.arguments
            
            let commandContext = CommandContext(
                    persona: persona,
                    commandMessage: incomingMessage,
                    botUser: telegram.botUser,
                    fullContextMessageHistory: { [state] purpose in
                        await contextMessages(
                            for: purpose,
                            state: state,
                            botUser: botUser,
                            inReplyTo: incomingMessage.replyToMessage
                        )
                        .context
                    },
                )
            
            for response in try await command.run(arguments: arguments, remainingText: wholeUserText, context: commandContext) {
                switch response {
                case .message(let response):
                    try await send(message: response, inChat: incomingMessage.chat.id, replyingTo: incomingMessage.id, chatState: &state)
                }
            }
            
            return .consumedTurn
        }
        
        return .none
    }
    
    
    /// Asks the LLM to send a message in response to the incoming Telegram message
    ///
    /// - Parameters:
    ///   - state:                  This tracks the state of the chat. This function will mutate it to register that the given message was received and that the bot responded with its own.
    ///   - incomingMessage:        The original message from Telegram, like if a user mentions or replies to this bot's message.
    ///   - shouldRespondToMessage: Whether the bot should respond directly to the incoming message. `false` indicates that the bot will send a standalone message instead.
    ///   - repliedToMessage:       If there's a specific message that the bot should respond to, put that here
    private func sendLlmMessage(chatState state: inout ChatState, incomingMessage: ChatMessage, shouldRespondToMessage: Bool, inReplyTo repliedToMessage: TGRepliedToMessage?) async {
        // Uncomment when you're testing in production:
//        try? await send(message: "😴💤 [I'm in maintenance mode]", inChat: state.chat.id, replyingTo: incomingMessage.id, chatState: &state); return
        
        guard await limiter.isStillWithinDailyMessageLimit() else {
            return
        }
        
        let nextStep = await state.register(didReceiveMessage: incomingMessage)
        
        if shouldRespondToMessage {
            await respond(inReplyTo: repliedToMessage, state: &state)
        }
        else {
            switch nextStep {
            case .interject:
                await interject(inReplyTo: repliedToMessage, state: &state)
                
            case .none:
                break
            }
        }
    }
    
    
    private func shouldRespond(to incomingMessage: TGMessage) -> Bool {
        isDirectMessage(incomingMessage)
        || isMentioned(incomingMessage)
        || isReplyToBot(incomingMessage)
    }
    
    
    
    enum CommandRunResult {
        case consumedTurn
    }
}



// MARK: - Sending messages

private extension BotRunner {
    
    func send(
        message: ChatMessage,
        inChat chatId: TGChat.ID,
        replyingTo repliedToMessage: TGMessage.ID?,
        chatState state: inout ChatState,
    ) async throws {
        try await send(
            message: message.text,
            inChat: chatId,
            replyingTo: repliedToMessage,
            chatState: &state
        )
    }
    
    
    func send(
        message: String,
        inChat chatId: TGChat.ID,
        replyingTo repliedToMessage: TGMessage.ID?,
        chatState state: inout ChatState,
    ) async throws {
        guard false == message.isEmpty else { return }
        
        await limiter.registerDidSendMessage()
        
        try await telegram.sendMessage(
            chatId: chatId,
            text: message.telegram_escapedForMarkdownV2,
            inReplyTo: repliedToMessage)
        
        await state.register(didSendMessage: ChatMessage(
            id: nil,
            senderName: botUsername,
            role: .assistant,
            isReply: nil != repliedToMessage,
            text: message)
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
    ///
    /// Mention entities use UTF-16 code-unit offsets per Telegram's spec,
    /// so the entity walk indexes into `text.utf16` rather than `text`
    /// directly. Using Character offsets on UTF-16 counts silently shifts
    /// mentions past any emoji or non-BMP character earlier in the message.
    private func isMentioned(_ msg: TGMessage) -> Bool {
        guard let text = msg.text else { return false }
        if text.localizedCaseInsensitiveContains("@\(botUsername)") { return true }
        
        guard let entities = msg.entities else { return false }
        let utf16 = text.utf16
        let target = "@\(botUsername.lowercased())"
        
        for entity in entities where "mention" == entity.type {
            guard let start = utf16.index(utf16.startIndex, offsetBy: entity.offset, limitedBy: utf16.endIndex),
                  let end = utf16.index(start, offsetBy: entity.length, limitedBy: utf16.endIndex)
            else {
                continue
            }
            
            let mentioned = String(decoding: utf16[start..<end], as: UTF16.self)
            if mentioned.lowercased() == target {
                return true
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
}


// MARK: - Generation

internal extension BotRunner {
    
    /// All message we want to send to the bot, for its context in order to generate its response
    ///
    /// - Parameters:
    ///   - for:              Why is this context being composed?
    ///   - state:            The current state of the current chat
    ///   - botUser:          The user account for this bot
    ///   - repliedToMessage: If this response will be replying to an existing message, specify it here
    ///
    /// - Returns: An array of message ready to send to the bot so it can synthesize a reply.
    func contextMessages(
        for purpose: BotMessagePurpose,
        state: ChatState,
        botUser: TGUser,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
    ) async -> (context: [ChatMessage], settings: OllamaModelOptions?) {
        let history = await state.recentMessages
        let context = persona.contextMessages(for: purpose, in: state.chat, botUser: botUser, inReplyTo: repliedToMessage, history: history)
        let settings = persona.modelSettings
        return (context: context, settings: settings)
    }
}



private extension BotRunner {
    
    /// Generates and sends a direct response, threading the result back
    /// into chat history so the bot's own utterances participate in
    /// future context.
    private func respond(
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        state: inout ChatState,
    ) async {
        let (context, settings) = await contextMessages(for: .response, state: state, botUser: botUser, inReplyTo: repliedToMessage)
        await sendGeneratedResponse(context: context, settings: settings, chatId: state.chat.id, state: &state, inReplyTo: repliedToMessage?.messageId)
    }
    
    
    /// Generates and sends an unprompted interjection. Distinguished
    /// from `respond` only by which prompt shape it asks the persona
    /// for — the send-and-record machinery is shared via `generate`.
    private func interject(
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        state: inout ChatState,
    ) async {
        let (context, settings) = await contextMessages(for: .interjection, state: state, botUser: botUser, inReplyTo: repliedToMessage)
        
        
        await sendGeneratedResponse(
            context: context,
            settings: settings,
            chatId: state.chat.id,
            state: &state,
            inReplyTo: nil)
    }
    
    
    /// Tells the LLM to generate a respond to the given context messages, optionally explicitly replying to one.
    ///
    /// Whether this is a direct response or an interjection is inferred
    /// from `inReplyTo`: non-nil means we're answering a specific
    /// message, nil means we're commenting on the conversation overall.
    /// That distinction is forwarded to ``modelForResponse(to:inReplyTo:)``
    /// because it changes which model is appropriate — see that method
    /// for why.
    private func sendGeneratedResponse(
        context: [ChatMessage],
        settings: OllamaModelOptions?,
        chatId: Int64,
        state: inout ChatState,
        inReplyTo: Int?,
    ) async {
        let model = modelForResponse(to: context, inReplyTo: inReplyTo)
        let reply: String
        
        do {
            async let deduplicated = context.deduplicated()
            
            reply = String(
                try await ollama.chat(
                    with: model,
                    context: await deduplicated,
                    settings: settings
                )
                .removingFakeChatLogs()
            )
        }
        catch {
            print("⚠️ Generation error: \(error)")
            return
        }
        
        let recentSenders = await state.recentMessages
            .filter { .assistant != $0.role }
            .map(\.senderName)
        let cleaned = persona.sanitize(
            reply,
            botUsername: botUsername,
            knownSenders: recentSenders
        )
        
        do {
            try await send(message: cleaned, inChat: chatId, replyingTo: inReplyTo, chatState: &state)
        }
        catch {
            print("⚠️ Failed to send generated reply: \(error)")
        }
    }
    
    
    /// Picks the model best suited to generate this particular turn.
    ///
    /// Two ideas combine here. First, interjections are commentary on the
    /// conversation as a whole, not a focused response to one message.
    /// Reaching for the vision model just because some old message in
    /// history was a photo would burn its bigger latency on a turn that
    /// isn't actually about the photo — so interjections always go
    /// through the text LLM regardless of what's in history.
    ///
    /// Second, for direct responses, the question is whether the message
    /// we're answering carries image data. If it does and a vision model
    /// is configured, that's what we want. If no vision model is
    /// configured, the text LLM is the only choice — the response will
    /// be image-blind, which is a degraded but functional fallback.
    private func modelForResponse(to context: [ChatMessage], inReplyTo: Int?) -> OllamaModel {
        // Interjections aren't focused on any one message, so the bigger
        // vision model isn't earned.
        guard nil != inReplyTo else { return models.llm }
        
        let lastUserHasImages = context
            .last(where: { .user == $0.role })?
            .images?
            .isEmpty == false
        
        if lastUserHasImages, let vision = models.vision {
            return vision
        }
        return models.llm
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
            
            await interject(inReplyTo: nil, state: &state)
        }
    }
    
    
    
    // MARK: -
    
    /// Errors that prevent the runner from starting. Distinguished from
    /// runtime errors because these indicate misconfiguration the
    /// operator must address; retrying won't help.
    enum BotError: Error {
        case missingToken
        case noUsername
        case failedToLoadLlm
    }
}



// MARK: - Global limiter

actor BotLimiter {
    private var todayStart: Date = .distantPast
    private var totalMessagesToday = 0
    private let maxMessagesPerDay = Limits.maxTotalMessagesSentPerDay
    
    
    
    func registerDidSendMessage() {
        rolloverDayIfNeeded()
        totalMessagesToday += 1
    }
    
    
    func isStillWithinDailyMessageLimit() -> Bool {
        rolloverDayIfNeeded()
        return totalMessagesToday < maxMessagesPerDay
    }
    
    
    /// Lazily resets the daily counter when the local day has advanced.
    /// Called from every read or write of the time-based budget, so we
    /// never need a separate timer firing at midnight.
    private func rolloverDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        if today > todayStart {
            todayStart = today
            totalMessagesToday = 0
        }
    }
}
