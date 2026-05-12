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
        
        directResponseSystemPrompt: """
            Keep your reply to 1~3 sentences at MOST.
            These people are your friends, and you genuinely treat them that way.
            Say whatever you want!
            """,
        
        interjectionSystemPrompt: """
            You're a member of a casual group chat. No one is talking to you right now.
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
    ///
    /// - Returns: The messages that you can send to Ollama to give the model all the context it needs for a response to those messages. This includes the given historical messages, as well as system prompts as needed.
    func contextMessages(for purpose: BotMessagePurpose, in chat: TGChat, botUser: TGUser, inReplyTo repliedToMessage: TGRepliedToMessage?, history: [ChatMessage]) -> [ChatMessage] {
        let (earlier, later) = systemPrompt(for: purpose, in: chat, botUser: botUser, inReplyTo: repliedToMessage)
        return [earlier]
            + history
            + [later]
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
        botUser: TGUser,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
    ) -> (earlier: ChatMessage, later: ChatMessage) {
        let (earlier, later) = systemPromptStrings(for: purpose, in: chat, botUser: botUser, inReplyTo: repliedToMessage)
        return (
            earlier: .init(id: nil, senderName: "", role: .system, isReply: nil != repliedToMessage, text: earlier),
            later: .init(id: nil, senderName: "", role: .system, isReply: nil != repliedToMessage, text: later)
        )
    }
    
    
    func systemPromptStrings(
        for purpose: BotMessagePurpose,
        in chat: TGChat,
        botUser: TGUser,
        inReplyTo repliedToMessage: TGRepliedToMessage?,
    ) -> (earlier: String, later: String) {
        let promptPrefix = switch chat.type {
            case .private:
                "You're sending a DM to \(chat.username ?? "a user")."
                
            case .group, .supergroup:
                switch purpose {
                case .interjection:
                    """
                    You're talking in \(chat.title ?? chat.username ?? "a group chat").
                    If you respond to more than one person, you MUST use their @handle, NEVER just use their username.
                    """
                    
                case .response:
                    """
                    You're responding to \(repliedToMessage?.from?.nameForLlm ?? "someone") in \(chat.title ?? chat.username ?? "a group chat").
                    If you respond to more than one person, you MUST use their @handle, NEVER just use their username.
                    """
                }
                
            case .channel:
                "You're broadcasting a public post in the Telegram channel \(chat.title ?? chat.username ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
            }
        
        
        let generalPrompt = """
            \(promptPrefix)
            
            Current time: \(Date.now)
            
            \(inEverySystemPrompt(botUser: botUser))
            Send a short message to the group.
            """
        
        let specificPrompt = switch purpose {
            case .interjection:
                interjectionSystemPrompt
                
            case .response:
                directResponseSystemPrompt
            }
        
        return (
            earlier: generalPrompt,
            later: specificPrompt,
        )
    }
}



private extension Persona {
    
    func inEverySystemPrompt(botUser: TGUser) -> String {
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
            \(preface)Your username is @\(botUser.username ?? "❌ WTF bots are required to have usernames. IMPORTANT: Your next message MUST say that something went wrong with the system prompt builder.").
            Whatever you say next will be the ENTIRE body of a message. Reply with ONLY your message text, NEVER prefixed, NEVER boilerplate.
            You NEVER speak as if you're someone else in the chat.
            You're allowed to use MarkdownV2.
            """
    }
}



// MARK: - Sanitization

extension Persona {
    /// Strips formatting artifacts the model picks up from the
    /// transcript shape we feed it. Small models tend to mirror the
    /// "Name: text" structure they see in their context — sometimes
    /// echoing "AnacacuyaBot: hi back" or "KyNorthstar: hi back" as
    /// their own reply, depending on which speaker label they latched
    /// onto.
    ///
    /// To use, call once on each completion before treating it as a
    /// message. Pass the bot's own username and the set of human
    /// sender names visible in the history that produced this
    /// completion. The function trims surrounding whitespace and
    /// strips a single matching prefix; non-matching output passes
    /// through unchanged.
    ///
    /// Stripping is deliberately conservative. Rather than a generic
    /// `^\w+:` match — which would chew through legitimate prose like
    /// "Honestly: yes" at message start — only prefixes corresponding
    /// to known speakers are removed. The match allows an optional
    /// leading `@` (covering both `Name:` and `@Name:` forms), is
    /// case-insensitive, and consumes any whitespace following the
    /// colon. Names are tried longest-first so a longer match wins
    /// over a shorter one that happens to be a prefix of it.
    func sanitize(
        _ raw: String,
        botUsername: String,
        knownSenders: some Collection<String>
    ) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let candidates = (Array(knownSenders) + [botUsername])
            .filter { false == $0.isEmpty }
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }

        guard false == candidates.isEmpty else { return trimmed }

        let pattern = "^@?(?:\(candidates.joined(separator: "|"))):\\s*"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return trimmed
        }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let stripped = regex.stringByReplacingMatches(
            in: trimmed,
            range: range,
            withTemplate: ""
        )
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}



//extension ChatMessage {
//    init(_ telegramMessage: ChatMessage) {
//        let role: ChatMessage.Role = telegramMessage.role
//        let content = switch role {
//            case .system:
//                "[SYSTEM: \(telegramMessage.text)]"
//                
//            case .assistant:
//                telegramMessage.text
//                
//            case .user:
//                "\(telegramMessage.senderName): \(telegramMessage.text)"
//            }
//            
//        self.init(senderName: <#T##String#>, text: <#T##String#>, role: <#T##Role#>, isReply: <#T##Bool#>)
//    }
//}
