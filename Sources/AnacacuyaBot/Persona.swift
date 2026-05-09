//
//  Persona.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation



let inEverySystemPrompt = """
Whatever you say will be the body of a message. Reply with ONLY your message text, NEVER a prefix, NEVER boilerplate.
"""



extension Persona {
    
    /// The default persona of the bot
    static let `default` = Persona(
        directResponseSystemPrompt: """
            You are a member of a casual group chat. Keep replies to 1~3 sentences.
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
    
    /// System prompt for direct responses. Sets the voice for replies
    /// that participate in turn-taking dialogue.
    let directResponseSystemPrompt: String

    /// System prompt for unprompted interjections. Stricter framing
    /// because the model must understand it's commenting on a
    /// conversation rather than continuing one.
    let interjectionSystemPrompt: String
    
    
    /// Builds the message array for a direct response, replaying history
    /// as multi-turn dialogue. The bot's own previous utterances become
    /// `assistant` turns so the model maintains continuity without being
    /// told to.
    func directResponseMessages(in chat: TGChat, history: [ChatMessage]) -> [OllamaMessage] {
        systemPromptMessages(for: .response, in: chat, context: history.formattedToShowToLlm)
        + history.map(OllamaMessage.init)
    }
    
    
    /// Builds the message array for an unprompted interjection. History
    /// is flattened into the user prompt as observed dialogue rather
    /// than replayed as turns — replaying as turns here causes the model
    /// to produce a continuation of the last speaker rather than fresh
    /// commentary.
    func interjectionMessages(in chat: TGChat, history: [ChatMessage]) -> [OllamaMessage] {
        systemPromptMessages(for: .interjection, in: chat, context: history.formattedToShowToLlm)
    }
}



enum BotMessagePurpose {
    case interjection
    case response
}



// MARK: - Prompt building

extension Persona {
    
    func systemPromptMessages(for purpose: BotMessagePurpose, in chat: TGChat, context: String) -> [OllamaMessage] {
        systemPrompt(for: purpose, in: chat, context: context)
        .map {
            OllamaMessage(
                role: .system,
                content: $0
            )
        }
    }
    
    
    func systemPrompt(for purpose: BotMessagePurpose, in chat: TGChat, context: String) -> [String] {
        
        let promptPrefix: String
        if let currentChatTitle = chat.title {
            promptPrefix = "Current chat: \(currentChatTitle)"
        }
        else {
            switch chat.type {
            case .private:
                promptPrefix = "You're sending a DM to \(chat.username ?? "a user")."
                
            case .group, .supergroup:
                promptPrefix = "You're talking in \(chat.username ?? "a group chat")."
                
            case .channel:
                promptPrefix = "You're broadcasting a public post in a Telegram channel."
            }
        }
        
        
        
        switch purpose {
        case .interjection:
            let generalPrompt = if context.isEmpty {
                    """
                    \(promptPrefix)
                    
                    Send a short message to the group.
                    \(inEverySystemPrompt)
                    """
                } else {
                    """
                    \(promptPrefix)
                    
                    Recent group messages:
                    
                    \(context)
                    
                    Chime in with one short comment.
                    \(inEverySystemPrompt)
                    """
                }
            
            return [
                generalPrompt,
                """
                Current time: \(Date.now)
                \(interjectionSystemPrompt)
                """,
            ]
            
        case .response:
            return [
                """
                \(promptPrefix)
                
                \(inEverySystemPrompt)
                """,
                """
                Current time: \(Date.now)
                \(directResponseSystemPrompt)
                """
            ]
        }
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



// MARK: - Conveniences

extension ChatMessage {
    var formattedToShowToLlm: String {
        "\(senderName): \(text)"
    }
}



extension [ChatMessage] {
    var formattedToShowToLlm: String {
        map(\.formattedToShowToLlm)
        .joined(separator: "\n\n")
    }
}



extension OllamaMessage {
    init(_ telegramMessage: ChatMessage) {
        let role: OllamaMessage.Role = telegramMessage.isBot
            ? .assistant
            : .user
        let content = telegramMessage.isBot
            ? telegramMessage.text
            : "\(telegramMessage.senderName): \(telegramMessage.text)"
            
        self.init(role: role, content: content)
    }
}
