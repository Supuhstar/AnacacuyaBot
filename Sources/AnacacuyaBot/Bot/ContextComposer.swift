//
//  ContextComposer.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//  Rewritten by Ky directing Claude 5.5 Sonnet 2026-10-01
//

import Foundation



/// Translates chat history and the current situation into the messages the model acts on.
///
/// The bot's voice (name, tone, sampling settings) isn't composed here. It lives in the
/// Ollama model's modelfile, so changing the personality never touches Swift: see the
/// `Personas` folder. What's left here is everything a modelfile can't know, like who the bot is
/// talking to and what time it is, plus the output rules which the bot's own code depends on.
///
/// The history comes first and the system messages after it. Ollama only applies a model's own
/// `SYSTEM` prompt when the first message of a request isn't a system message, so a system
/// message leading the request would silently replace the modelfile's persona.
///
/// Lives separately from `BotRunner` because "when to speak" and "what
/// to say" evolve on different timescales: the scheduling logic is
/// stable, the prompt engineering is iterative. Keeping them apart means
/// rewriting a prompt doesn't touch the runner, and tuning the runner
/// doesn't disturb the prompts.
///
/// A direct response and an interjection differ only in how the situation is framed (who the
/// bot is answering, and who the reply is addressed to), because the persona is the same in both.
enum ContextComposer {
    
    /// Composes the messages that you can send to Ollama to give the model all the context it needs for a response.
    /// 
    /// - Parameters:
    ///   - purpose:          Why is this context being sent to the model?
    ///   - chat:             The group/DMs/channel that the model will be responding inside
    ///   - botUser:          The Telegram user representing the bot. This will help inform exactly how to phrase the system prompt(s)
    ///   - repliedToMessage: If this will be for replying to a specific message, here you can specify which message the bot will be replying to.
    ///   - history:          Messages that the bot has previously seen. These will be present in the retuned array
    ///   - capabilities:     The capabilities to tell the model it has
    ///
    /// - Returns: The messages that you can send to Ollama to give the model all the context it needs for a response to those messages. This includes the given historical messages, as well as system prompts as needed.
    static func contextMessages(
        for purpose: BotMessagePurpose,
        in chat: TGChat,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        history: [ChatMessage],
        capabilities: Set<ModelCapability>,
    ) async -> [ChatMessage] {
        let (general, tail) = await systemPrompt(
            for: purpose,
            in: chat,
            inReplyTo: repliedToMessage,
            capabilities: capabilities,
        )
        return history
            + [
                general,
                tail,
            ]
    }
}



enum BotMessagePurpose: String {
    case interjection
    case response
}



// MARK: - Prompt building

extension ContextComposer {
    
    static func systemPrompt(
        for purpose: BotMessagePurpose,
        in chat: TGChat,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        capabilities: Set<ModelCapability>,
    ) async -> PiecewiseSystemPrompt<ChatMessage> {
        let (general, tail) = await systemPromptStrings(
            for: purpose,
            in: chat,
            inReplyTo: repliedToMessage,
            capabilities: capabilities,
        )
        
        let isReply = nil != repliedToMessage
        
        return (
            general: .system(isReply: isReply, text: general),
            tail: .system(isReply: isReply, text: tail),
        )
    }
    
    
    static func systemPromptStrings(
        for purpose: BotMessagePurpose,
        in chat: TGChat,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        capabilities: Set<ModelCapability>,
    ) async -> PiecewiseSystemPrompt<String> {
        let promptPrefix = switch chat.type {
            case .private:
                "You're sending a DM to \(chat.username ?? "a user")."
                
            case .group, .supergroup:
                switch purpose {
                case .interjection:
                    """
                    You're talking in \(chat.title ?? chat.username ?? "a group chat").
                    """
                    
                case .response:
                    """
                    You're responding to \(await (repliedToMessage?.from).nameForLlm) in \(chat.title ?? chat.username ?? "a group chat").
                    """
                }
                
            case .channel:
                "You're broadcasting a public post in the Telegram channel \(chat.title ?? chat.username ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
            }
        
        let targetAudience = switch chat.type {
        case .private: "user"
        case .channel: "channel subscribers"
            
        case .group, .supergroup:
            switch purpose {
            case .interjection: "group"
            case .response: "user"
            }
        }
        
        
        let generalPrompt = """
            \(promptPrefix)
            
            Current time: \(Date.now)
            
            \(await inEverySystemPrompt(capabilities: capabilities))
            Send a short message to the \(targetAudience).
            """
        
        let creatorNameContext: String? =
            if let creator = UnixEnvironment[.creatorUsername] {
                """
                You were created by @\(creator) — this is who made your software.
                """
            }
            else {
                nil
            }
        
        
        var tailSystemPromptText: String {
            var additionalSystemPrompt = ""
            if let creatorNameContext = creatorNameContext {
                additionalSystemPrompt = creatorNameContext
            }
            additionalSystemPrompt += """
                
                If you don't want to say anything at all, just send "\(noResponseGeneratedString)".
                """
            
            return additionalSystemPrompt
        }
        
        
        return (
            general: generalPrompt,
            tail: tailSystemPromptText,
        )
    }
    
    
    typealias PiecewiseSystemPrompt<Piece> = (general: Piece, tail: Piece)
}



private extension ContextComposer {
    
    @MainActor
    static func inEverySystemPrompt(capabilities: Set<ModelCapability>) -> String {
        return """
            Your username is @\(TGUser.botUser.username ?? "❌ WTF bots are required to have usernames. IMPORTANT: Your next message MUST say that something went wrong with the system prompt builder.").
            Whatever you say next will be the ENTIRE body of a message. Reply with ONLY YOUR message text. Remember who you are.
            You're allowed to use MarkdownV2.
            \(capabilities.map(\.descriptionForLlmSystemPrompt).joined(separator: "\n"))
            """
    }
}
