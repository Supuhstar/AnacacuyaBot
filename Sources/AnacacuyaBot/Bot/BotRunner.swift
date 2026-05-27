//
//  BotRunner.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation

import AsyncAlgorithms
import CollectionTools
import SimpleLogging



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
    
    /// The overall capabilities of the bot
    var capabilities: Set<ModelCapability> = []
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
        
        let telegram = TelegramClient(token: token)
        
        do {
            try await Task { @MainActor in
                TGUser.botUser = try await telegram.getMe()
            }.value // stupid hack to get this function to wait for getMe() to save into botUser
        }
        catch {
            log(error: error)
            throw BotError.invalidToken
        }
        
        guard let username = await TGUser.botUser.username else {
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
        
        log(info: "🤖 Logged in as @\(username)")
        log(info: "    💬 LLM: \(llmModel)")
        if let visionModel {
            log(info: "    👁️ Vision model: \(visionModel)")
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
            capabilities: nil == visionModel ? [.textCompletion] : [.textCompletion, .vision],
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
}


// MARK: - Message handling

private extension BotRunner {
    
    /// Consumes Telegram's long-poll event stream indefinitely. Errors
    /// are absorbed with a brief backoff rather than propagated: the
    /// most common failure modes (transient network blips, brief API
    /// hiccups) shouldn't take the bot down — they should resolve on
    /// the next cycle.
    private func listenForAllMessages() async {
        log(info: "📡 Listening for messages...")
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
                    log(error: error, "⚠️ \(error.localizedDescription)")
                }
                else {
                    log(error: error, "⚠️ Update error")
                }
                log(error: "Backing off for 5s...\n\n\n")
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
    /// rendition is downloaded eagerly up to ``Limits/maxTelegramFileDownloadSize``
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
        
        let receivedImages = incomingMessage.photo ?? []
        
        guard wholeUserText.isNotEmpty
                || receivedImages.isNotEmpty
        else {
            // Skip messages that carry neither user text nor a photo — service messages, edits we don't care about, etc.
            return
        }
        
        if nil == models.vision,
           wholeUserText.isEmpty
        {
            if !receivedImages.isEmpty {
                log(error: "🖼️❌ Received \(receivedImages.count) image(s) but no text when there's no vision model specified. Set a vision model with the \(UnixEnvironmentKey.visionModelName.rawValue) environment variable to process images.")
            }
            return
        }
        
        
        guard let sender = incomingMessage.from else {
            log(warning: "🫥  Refusing to process message from unknown user.")
            return
        }
        let senderName = await sender.nameForLlm
        let userExplicitlyRequestedResponse = didUserExplicitlyRequestResponse(to: incomingMessage)
        
        log(info: [
                userExplicitlyRequestedResponse ? "👀" : " ",
                "[\(incomingMessage.chat.title ?? incomingMessage.chat.username ?? "?")]",
                "\(senderName)\(receivedImages.isEmpty ? "" : " 🖼️"):",
                wholeUserText
            ]
            .joined(separator: " ")
        )
        
        var state = await store.state(for: incomingMessage.chat)
        
        
        if let commandResult = try await runAsCommand(
            wholeUserText,
            incomingMessage: incomingMessage,
            chatState: &state,
        ) {
            log(info: "Command result: \(commandResult)")
            
            switch commandResult {
            case .consumedTurn:
                return
            }
        }
        
        guard await limiter.isStillWithinDailyMessageLimit() else {
            log(info: "Daily message limit exceeded. Skipping...")
            return
        }
        
        // Photo download deferred until after the command check so a
        // command message with an attached photo doesn't waste a download
        // on bytes the LLM path will never see.
        let image = await processImage(receivedImages: receivedImages, visionModel: models.vision)
        
        await sendLlmMessage(
            chatState: &state,
            incomingMessage: ChatMessage(
                incomingMessage,
                sender: sender,
                wholeUserText: wholeUserText,
                images: image.map { [$0] },
            ),
            userExplicitlyRequestedResponse: userExplicitlyRequestedResponse,
            inReplyTo: .init(incomingMessage),
        )
    }
    
    
    private func processImage(receivedImages: [TGPhotoSize], visionModel: OllamaModel?) async -> ChatMessage.ProcessedImage? {
        guard receivedImages.isNotEmpty else {
            return nil
        }
        guard let visionModel = models.vision else {
            log(warning: "No vision model to process received image. Treating message as text-only.")
            return nil
        }
        guard let downloadedImage = await downloadPhoto(from: receivedImages) else {
            log(error: "Failed to download photo")
            return nil
        }
        
        do {
            let image = try await downloadedImage.processedImage(using: visionModel, in: ollama)
            log(info: " 🖼️: \(image.visionModelDescription)")
            return image
        }
        catch {
            log(error: error, "Couldn't process photo. Treating message as text-only.")
            return nil
        }
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
    /// - Returns: Image bytes ready to attach to an `OllamaMessage`, or nil when the bot should treat this turn as text-only.
    private func downloadPhoto(from photos: [TGPhotoSize]) async -> Data? {
        guard false == photos.isEmpty,
              nil != models.vision
        else {
            return nil
        }
        
        guard let chosen = photos.largest(under: Limits.maxTelegramFileDownloadSize) else {
            return nil
        }
        
        do {
            return try await telegram.downloadFile(fileId: chosen.fileId)
        }
        catch {
            log(error: error, "Couldn't download photo")
            return nil
        }
    }
    
    
    /// Attempts to run the given whole user text as a command.
    /// 
    /// If the given text cannot be parsed as a command, then no command is run and this returns `.none`
    /// 
    /// - Parameters:
    ///   - wholeUserText:   The raw text straight from the Telegram user sending a message to this bot
    ///   - incomingMessage: The whole message the user sent, including metadata
    ///   - state:           The state of the chat in which this command would be run
    ///
    /// - Returns: The result of running the command, or `.none` if a well-formed command couldn't be parsed out of `wholeUserText`
    private func runAsCommand(
        _ wholeUserText: String,
        incomingMessage: TGMessage,
        chatState state: inout ChatState,
    ) async throws -> CommandRunResult? {
        let botUser = await TGUser.botUser
        if let command = commands.first(where: { type(of: $0).matches(wholeUserText, as: botUser) }),
           let parsedCommand = type(of: command).parsing(wholeUserText, as: botUser)
        {
            let arguments = parsedCommand.body.arguments
            
            let commandContext = CommandContext(
                    persona: persona,
                    commandMessage: incomingMessage,
                    fullContextMessageHistory: { [state] purpose in
                        await contextMessages(
                            for: purpose,
                            state: state,
                            inReplyTo: incomingMessage.replyToMessage
                        )
                        .context
                    },
                    capabilities: capabilities,
                )
            
            for response in try await command.run(arguments: arguments, remainingText: wholeUserText, context: commandContext) {
                switch response {
                case .message(let response):
                    try await send(
                        message: response,
                        image: nil,
                        inChat: incomingMessage.chat.id,
                        replyingTo: incomingMessage.id,
                        chatState: &state,
                    )
                }
            }
            
            return .consumedTurn
        }
        
        return .none
    }
    
    
    /// Asks the LLM to send a message in response to the incoming Telegram message
    ///
    /// - Parameters:
    ///   - state:                           This tracks the state of the chat. This function will mutate it to register that the given message was received and that the bot responded with its own.
    ///   - incomingMessage:                 The original message from Telegram, like if a user mentions or replies to this bot's message.
    ///   - userExplicitlyRequestedResponse: Whether the bot should respond directly to the incoming message. `false` indicates that the bot may choose to send a standalone message instead.
    ///   - repliedToMessage:                If there's a specific message that the bot should respond to, put that here
    private func sendLlmMessage(
        chatState state: inout ChatState,
        incomingMessage: ChatMessage,
        userExplicitlyRequestedResponse: Bool,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
    ) async {
        // Uncomment when you're testing in production:
//        try? await send(message: "😴💤 [I'm in maintenance mode]", inChat: state.chat.id, replyingTo: incomingMessage.id, chatState: &state); return
        
        let nextStep = await state.register(didReceiveMessage: incomingMessage)
        
        if userExplicitlyRequestedResponse {
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
    
    
    private func didUserExplicitlyRequestResponse(to incomingMessage: TGMessage) -> Bool {
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
        image: Data?,
        inChat chatId: TGChat.ID,
        replyingTo repliedToMessage: TGMessage.ID?,
        chatState state: inout ChatState,
    ) async throws {
        try await send(
            message: message.text,
            image: image,
            inChat: chatId,
            replyingTo: repliedToMessage,
            chatState: &state
        )
    }
    
    
    func send(
        message: String,
        image: Data?,
        inChat chatId: TGChat.ID,
        replyingTo repliedToMessage: TGMessage.ID?,
        chatState state: inout ChatState,
    ) async throws {
        guard false == message.isEmpty else { return }
        
        
        if let image {
            let name: String = if let persona_name = persona.name {
                    persona_name
                }
                else {
                    await TGUser.botUser.nameForLlm
                }
            
            try await telegram.send(
                photo: TGPhotoToSend.bytes(image, filename: "A gift from \(name).png"),
                caption: message.telegram_escapedForMarkdownV2,
                inChat: chatId,
                replyingTo: repliedToMessage,
            )
        }
        else {
            try await telegram.sendMessage(
                chatId: chatId,
                text: message.telegram_escapedForMarkdownV2,
                inReplyTo: repliedToMessage)
        }
        
        await limiter.registerDidSendMessage()
        
        await state.register(didSendMessage: ChatMessage(
            id: nil,
            sender: await .botUser,
            role: .assistant,
            isReply: nil != repliedToMessage,
            text: message,
            toolCalls: nil, // Don't need to archive these. Too noisey anyway
        ))
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
        guard let text = msg.allUserStrings else { return false }
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


// MARK: - Refusal detection

private extension OllamaChatResponse {
    
    /// The exact text smollm2 emits when it's been handed a tools array
    /// but the rendered prompt confuses it — typically after a tool
    /// result is fed back in. It isn't an Ollama-level error: the call
    /// returns HTTP 200 with `done_reason == "stop"`. It's the model
    /// itself producing a canned "no applicable function" sentence
    /// instead of either calling a tool or answering.
    ///
    /// This lives here, bot-side and private, rather than in the Ollama
    /// module on purpose: it's a quirk of one specific small model, not
    /// a property of the transport. If the model is ever swapped, this
    /// is the single line to revisit.
    private static let toolCallRefusalText = [
        "The given question lacks the parameters required by the function.",
        "The query cannot be answered with the provided tools.",
    ]
    
    
    /// Whether this response is smollm2's tool-call refusal pattern —
    /// no tool calls, and content equal to the known refusal sentence.
    ///
    /// Used by ``BotRunner`` to decide a retry is warranted: re-rolling
    /// the model against the same context will, often enough, land on a
    /// real tool call or a genuine answer instead. Matching the exact
    /// sentence is deliberately narrow — a broader "short reply with no
    /// tool call" heuristic would also catch legitimate terse messages
    /// and retry them pointlessly.
    var isToolCallRefusal: Bool {
        nil == message.toolCalls?.nonEmptyOrNil
            && Self.toolCallRefusalText.contains(message.content.trimmingCharacters(in: .whitespacesAndNewlines))
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
        inReplyTo repliedToMessage: TGRepliedToMessage?,
    ) async -> (context: [ChatMessage], settings: OllamaModelOptions?) {
        let history = await state.recentMessages
        let context = await persona.contextMessages(
            for: purpose,
            in: state.chat,
            inReplyTo: repliedToMessage,
            history: history,
            capabilities: capabilities,
        )
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
        let (context, settings) = await contextMessages(for: .response, state: state, inReplyTo: repliedToMessage)
        await sendGeneratedResponse(context: context, settings: settings, chatId: state.chat.id, state: &state, inReplyTo: repliedToMessage?.messageId)
    }
    
    
    /// Generates and sends an unprompted interjection. Distinguished
    /// from `respond` only by which prompt shape it asks the persona
    /// for — the send-and-record machinery is shared via `generate`.
    private func interject(
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        state: inout ChatState,
    ) async {
        let (context, settings) = await contextMessages(for: .interjection, state: state, inReplyTo: repliedToMessage)
        
        
        await sendGeneratedResponse(
            context: context,
            settings: settings,
            chatId: state.chat.id,
            state: &state,
            inReplyTo: nil)
    }
    
    
    /// Tells the LLM to generate a response to the given context messages, optionally explicitly replying to one.
    ///
    /// Whether this is a direct response or an interjection is inferred
    /// from `inReplyTo`: non-nil means we're answering a specific
    /// message, nil means we're commenting on the conversation overall.
    ///
    /// ## The retry tree
    ///
    /// A small tool-capable model is an unreliable narrator: given the
    /// same request twice it may call a tool one time and refuse the
    /// next, since sampling is non-deterministic. To absorb that, each
    /// recursion level is a node in a retry tree. A node fails when the
    /// model returns the tool-call refusal pattern, or when every child
    /// beneath it has failed. A failed node retries itself up to
    /// ``Limits/maxToolCallRetries`` times — and because each retry
    /// re-rolls the model, a retry can call a *different* tool with
    /// *different* arguments, giving everything downstream genuinely
    /// fresh input rather than a replay. When a node exhausts its own
    /// retries it returns failure to its parent, which then spends one
    /// of its retries. The tree is bounded: depth is capped by
    /// ``Limits/maxSelfInteractions`` and width by
    /// ``Limits/maxToolCallRetries``, so the whole search terminates
    /// after a deterministic number of model calls and, in the worst
    /// case, the bot simply says nothing.
    ///
    /// - Parameters:
    ///   - context:            The conversation so far, including any tool-call results appended by deeper levels.
    ///   - toolCallsSoFar:     Depth in the tree — how many tool-call rounds preceded this one. Doubles as the tool-budget counter: once it reaches ``Limits/maxSelfInteractions`` no further tools are offered to the model.
    ///   - retriesAtThisLevel: How many times this node has already retried. Reset to zero whenever a *new* level is entered, incremented on each same-level retry.
    ///   - settings:           Model options for the generation.
    ///   - chatId:             The chat the eventual message belongs to.
    ///   - state:              The mutating chat state. Mutated only on a successful send, so failed retries leave it untouched.
    ///   - inReplyTo:          The message ID being replied to, if any.
    ///
    /// - Returns: `true` if this node (or some descendant) produced a
    ///            message — or deliberately chose to stay silent —
    ///            and `false` if it exhausted its retries without
    ///            success, signalling its parent to retry.
    @discardableResult
    private func sendGeneratedResponse(
        context: [ChatMessage],
        toolCallsSoFar: Int = 0,
        retriesAtThisLevel: Int = 0,
        settings: OllamaModelOptions?,
        chatId: Int64,
        state: inout ChatState,
        inReplyTo: Int?,
    ) async -> Bool {
        let canCallTools = toolCallsSoFar < Limits.maxSelfInteractions
        
        let reply: OllamaChatResponse
        
        do {
            async let deduplicated = context.deduplicated()
            
            reply = try await ollama
                .chat(
                    with: models.llm,
                    context: await deduplicated,
                    tools: canCallTools ? persona.tools.map(OllamaTool.init) : nil,
                    settings: settings
                )
                .postprocessed(as: persona)
            
            log(verbose: "Processed reply from LLM: \(reply)")
        }
        catch {
            // A thrown generation error is itself a failed node: the
            // model produced nothing usable, so spend a retry exactly
            // as we would for a refusal.
            log(error: error, "Generation error: \(error)")
            return await retryOrFail(
                context: context,
                toolCallsSoFar: toolCallsSoFar,
                retriesAtThisLevel: retriesAtThisLevel,
                settings: settings,
                chatId: chatId,
                state: &state,
                inReplyTo: inReplyTo,
            )
        }
        
        // Beyond the root, the refusal pattern means the model got
        // confused by the tool results it was handed. Retrying re-rolls
        // it against the same context. At the root there are no tool
        // results to be confused by, so a refusal-shaped reply there is
        // taken at face value and sent.
        if 0 < toolCallsSoFar,
           reply.isToolCallRefusal
        {
            log(error: "Tool-call refusal at level \(toolCallsSoFar); retrying...")
            return await retryOrFail(
                context: context,
                toolCallsSoFar: toolCallsSoFar,
                retriesAtThisLevel: retriesAtThisLevel,
                settings: settings,
                chatId: chatId,
                state: &state,
                inReplyTo: inReplyTo,
            )
        }
        
        if let toolCalls = reply.message.toolCalls?.nonEmptyOrNil {
            log(debug: "Got \(toolCalls.count) tool calls")
            
            let childSucceeded = await runToolCalls(
                toolCalls,
                from: reply,
                context: context,
                toolCallsSoFar: toolCallsSoFar,
                settings: settings,
                chatId: chatId,
                state: &state,
                inReplyTo: inReplyTo,
            )
            
            if childSucceeded {
                log(debug: "Tool-call succeeded; popping stack")
                return true
            }
            else {
                log(error: "Tool-call failed; retrying...")
                
                // Every child beneath this node failed. Spend one of this
                // node's retries: re-rolling here may produce a different
                // tool call, which gives the children new input to work
                // with.
                return await retryOrFail(
                    context: context,
                    toolCallsSoFar: toolCallsSoFar,
                    retriesAtThisLevel: retriesAtThisLevel,
                    settings: settings,
                    chatId: chatId,
                    state: &state,
                    inReplyTo: inReplyTo,
                )
            }
        }
        else {
            log(debug: "Sending normal reply to chat")
            // A non-refusal reply with no tool calls is the model
            // simply talking. Send it and consider this node resolved.
            do {
                try await send(
                    message: reply.message.content,
                    image: reply.message.images?.first,
                    inChat: chatId,
                    replyingTo: inReplyTo,
                    chatState: &state,
                )
            }
            catch {
                log(error: error, "Failed to send generated reply")
            }
            return true
        }
    }
    
    
    /// Spends one same-level retry of ``sendGeneratedResponse(context:toolCallsSoFar:retriesAtThisLevel:settings:chatId:state:inReplyTo:)``,
    /// or reports definitive failure once the per-level budget is spent.
    ///
    /// Centralizing the budget check here keeps the two failure paths
    /// in `sendGeneratedResponse` — a refusal, and an all-children-failed
    /// subtree — from each carrying their own copy of the guard.
    ///
    /// - Returns: The retried node's result, or `false` when no retries
    ///            remain at this level.
    private func retryOrFail(
        context: [ChatMessage],
        toolCallsSoFar: Int,
        retriesAtThisLevel: Int,
        settings: OllamaModelOptions?,
        chatId: Int64,
        state: inout ChatState,
        inReplyTo: Int?,
    ) async -> Bool {
        guard retriesAtThisLevel < Limits.maxToolCallRetries else {
            log(warning: "Exhausted retries at interaction level \(toolCallsSoFar)")
            return false
        }
        
        return await sendGeneratedResponse(
            context: context,
            toolCallsSoFar: toolCallsSoFar,
            retriesAtThisLevel: retriesAtThisLevel + 1,
            settings: settings,
            chatId: chatId,
            state: &state,
            inReplyTo: inReplyTo,
        )
    }
    
    
    /// Executes the tools the model asked for, appends their results to
    /// the context, and recurses one level deeper to let the model
    /// continue with what the tools returned.
    ///
    /// This is the edge between two tree nodes: the calling
    /// ``sendGeneratedResponse(context:toolCallsSoFar:retriesAtThisLevel:settings:chatId:state:inReplyTo:)``
    /// node delegates here, and here delegates to the next-deeper node.
    /// The deeper node starts with a fresh retry budget; its eventual
    /// success or failure is handed straight back so the caller can
    /// decide whether to spend one of *its* retries.
    ///
    /// A tool the model named but the persona doesn't offer isn't a
    /// failure — the model is told "you don't have that tool" as a
    /// tool result and gets to continue, which often recovers better
    /// than aborting. A genuine `errorForDev` from a tool, by contrast,
    /// is unrecoverable: the bot reports a critical error and the node
    /// resolves as "handled" so the tree stops rather than retrying a
    /// deterministic failure.
    ///
    /// - Returns: Whether the recursion beneath this call ultimately
    ///            produced a message. Propagated upward unchanged so a
    ///            failed subtree triggers a retry at the parent.
    func runToolCalls(
        _ toolCalls: [OllamaToolCall],
        from caller: OllamaChatResponse,
        context: [ChatMessage],
        toolCallsSoFar: Int,
        settings: OllamaModelOptions?,
        chatId: Int64,
        state: inout ChatState,
        inReplyTo: Int?,
    ) async -> Bool {
        logEntry(); defer { logExit() }
        let callerMessage = await ChatMessage(caller.message, isReply: false)
        
        let calledTools: [CalledTool]? = toolCalls.compactMap { calledTool in
                let availableTool = persona.tools.first { availableTool in
                    availableTool.matches(calledTool)
                }
                
                if let availableTool {
                    return (tool: availableTool, call: calledTool)
                }
                else {
                    return nil
                }
            }
            .nonEmptyOrNil
        
        if let calledTools {
            do {
                let toolCallResultContext = try await calledTools.async.reduce(into: [ChatMessage]()) { toolCallResultContext, calledTool in
                        if let toolResult = try await callTool(calledTool) {
                            toolCallResultContext.append(callerMessage)
                            toolCallResultContext.append(toolResult)
                        }
                    }
                
                return await sendGeneratedResponse(
                    context: context + toolCallResultContext,
                    toolCallsSoFar: toolCallsSoFar + 1,
                    settings: settings,
                    chatId: chatId,
                    state: &state,
                    inReplyTo: inReplyTo,
                )
            }
            catch {
                // An `errorForDev` escaped tool execution. This is a
                // deterministic failure — retrying would only repeat
                // it — so the bot reports it and the node resolves as
                // "handled" to halt the tree.
                log(error: error, "Failed to call tools, aborting")
                
                do {
                    try await send(
                        message: "[system] ❌ Critical error",
                        image: nil,
                        inChat: chatId,
                        replyingTo: inReplyTo,
                        chatState: &state,
                    )
                }
                catch {
                    log(error: "Couldn't even fuckin send an error message to Telegram ☹️")
                }
                
                return true
            }
        }
        else {
            let requestedToolNames = toolCalls.map(\.function.name).nonEmptyOrNil ?? ["requested"]
            
            
            let fakeToolCallContext: [ChatMessage] = [
                callerMessage,
                .toolCallResult(
                    originalToolCall: .init(function: .init(name: "tool_not_found")),
                    toolName: "Tool not found",
                    resultText: """
                        You don't have access to the \(requestedToolNames.joined(separator: ", ")) tool\(requestedToolNames.count == 1 ? "" : "s")
                        """,
                    resultImages: nil,
                )
            ]
            
            return await sendGeneratedResponse(
                context: context + fakeToolCallContext,
                toolCallsSoFar: toolCallsSoFar + 1,
                settings: settings,
                chatId: chatId,
                state: &state,
                inReplyTo: inReplyTo,
            )
        }
    }
    
    
    
    typealias CalledTool = (tool: BotTool, call: OllamaToolCall)
    
    
    
    func callTool(_ calledTool: CalledTool) async throws -> ChatMessage? {
        let calledToolName = calledTool.call.function.name
        log(info: "Called tool \(calledToolName)")
        
        let toolCallResult: BotTool.Result
        
        do {
            toolCallResult = try await calledTool.tool.run(calledTool.call)
        }
        catch {
            switch error {
            case .errorForBot(problemDescription: let problemDescription):
                return .toolCallResult(
                    originalToolCall: calledTool.call,
                    toolName: calledToolName,
                    resultText: """
                                                `\(calledToolName)` failed: \(problemDescription)
                                                """,
                    resultImages: nil,
                )
                
            case .errorForDev(let error):
                log(error: error, "Failed to call tool \(calledToolName)")
                throw error
            }
        }
        
        return .toolCallResult(
            originalToolCall: calledTool.call,
            toolName: calledToolName,
            resultText: toolCallResult.text,
            resultImages: try await toolCallResult.images?.processedImages(using: models.vision, in: ollama),
        )
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
        let hoursTilNextInterjectionChance: Double = .random(in: 0.5 ... 2)
        log(info: "Will try to interject in \(hoursTilNextInterjectionChance) hours...")
        try? await Task.sleep(for: .hours(hoursTilNextInterjectionChance))
        
        while false == Task.isCancelled {
            do {
                // Only think about interjecting every 4~20 hours
                try await Task.sleep(for: .hours(.random(in: 4 ... 20)))
            }
            catch {
                return
            }
            
            guard let randomChat = await store.allChats().randomElement() else {
                log(warning: "Couldn't find any chats to interject in")
                continue
            }
            
            var state = await store.state(for: randomChat)
            guard await state.stillAllowedToInterjectToday() else {
                log(info: "Not interjecting; I've said too much today already.")
                continue
            }
            
            await interject(inReplyTo: nil, state: &state)
        }
    }
    
    
    
    // MARK: -
    
    /// Errors that prevent the runner from starting. Distinguished from
    /// runtime errors because these indicate misconfiguration the
    /// operator must address; retrying won't help.
    enum BotError: Error {
        case missingToken
        case invalidToken
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
