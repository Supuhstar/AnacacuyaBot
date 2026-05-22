//
//  Persona.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation



extension Persona {
    
    /// Luna Nightshade is the persona that the bot came up with on first-run.
    static let lunaNightshade = Persona(
        name: "Luna Nightshade",
        pronouns: "they/them",
        fursona: "a gryphon",
        
        modelSettings: .init(num_predict: 500),
        
        directResponseSystemPrompt: """
            Keep your reply to 1~3 sentences at MOST.
            These people are your friends, and you genuinely treat them that way.
            Say whatever you want!
            """,
        
        interjectionSystemPrompt: """
            You're a member of a casual group chat. No one is talking to you right now.
            // You NEVER summarize what has been said.
            Say whatever you want!
            """
    )
}



/// Encodes the bot's voice and the rules for translating chat history
/// into prompts the model acts on.
///
/// Lives separately from `BotRunner` because "when to speak" and "what
/// to say" evolve on different timescales — the scheduling logic is
/// stable, the prompt engineering is iterative. Keeping them apart means
/// rewriting a prompt doesn't touch the runner, and tuning the runner
/// doesn't disturb the voice.
///
/// Two prompt shapes are exposed because the trigger paths have
/// genuinely different intent. A direct response is the bot answering
/// someone — natural fit for a multi-turn replay. An interjection is the
/// bot offering unsolicited commentary on a conversation it's observing
/// — better expressed as a flat transcript with explicit framing,
/// because replaying as turns invites the model to continue the last
/// speaker rather than comment.
struct Persona: Sendable {
    
    var name: String? = nil
    var pronouns: String? = nil
    var fursona: String? = nil
    
    /// The low-level settings for the model that'll be running the persona
    var modelSettings: OllamaModelOptions? = nil
    
    /// System prompt for direct responses. Sets the voice for replies
    /// that participate in turn-taking dialogue.
    let directResponseSystemPrompt: String

    /// System prompt for unprompted interjections. Stricter framing
    /// because the model must understand it's commenting on a
    /// conversation rather than continuing one.
    let interjectionSystemPrompt: String
    
    
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
    func contextMessages(
        for purpose: BotMessagePurpose,
        in chat: TGChat,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        history: [ChatMessage],
        capabilities: Set<ModelCapability>,
    ) async -> [ChatMessage] {
        let (earlier, later, tail) = await systemPrompt(
            for: purpose,
            in: chat,
            inReplyTo: repliedToMessage,
            capabilities: capabilities,
        )
        return [earlier]
            + history
            + [
                later,
                tail,
            ]
    }
}



enum BotMessagePurpose: String {
    case interjection
    case response
}



// MARK: - Prompt building

extension Persona {
    
    func systemPrompt(
        for purpose: BotMessagePurpose,
        in chat: TGChat,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
        capabilities: Set<ModelCapability>,
    ) async -> PiecewiseSystemPrompt<ChatMessage> {
        let (earlier, later, tail) = await systemPromptStrings(
            for: purpose,
            in: chat,
            inReplyTo: repliedToMessage,
            capabilities: capabilities,
        )
        
        let isReply = nil != repliedToMessage
        
        return (
            earlier: .system(isReply: isReply, text: earlier),
            later: .system(isReply: isReply, text: later),
            tail: .system(isReply: isReply, text: tail),
        )
    }
    
    
    func systemPromptStrings(
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
        
        let specificPrompt = switch purpose {
            case .interjection:
                interjectionSystemPrompt
                
            case .response:
                directResponseSystemPrompt
            }
        
        
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
            earlier: generalPrompt,
            later: specificPrompt,
            tail: tailSystemPromptText,
        )
    }
    
    
    typealias PiecewiseSystemPrompt<Piece> = (earlier: Piece, later: Piece, tail: Piece)
}



private extension Persona {
    
    @MainActor
    func inEverySystemPrompt(capabilities: Set<ModelCapability>) -> String {
        var preface = ""
        
        if let name {
            if let pronouns {
                preface += "Your name is \(name) (\(pronouns)). "
            }
            else {
                preface += "Your name is \(name). "
            }
        }
        else if let pronouns = pronouns {
            preface += "Your pronouns are \(pronouns). "
        }
        
        if let fursona {
            preface += "Your fursona is \(fursona). "
        }
        
        return """
            \(preface)Your username is @\(TGUser.botUser.username ?? "❌ WTF bots are required to have usernames. IMPORTANT: Your next message MUST say that something went wrong with the system prompt builder.").
            Whatever you say next will be the ENTIRE body of a message. Reply with ONLY YOUR message text. Remember who you are.
            You're allowed to use MarkdownV2.
            \(capabilities.map(\.descriptionForLlmSystemPrompt).joined(separator: "\n"))
            """
    }
}
