//
//  ChatMessage.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation



/// A single message captured from a group chat, normalized to the bot's
/// internal representation so the rest of the system doesn't have to care
/// whether it originated from Telegram, the bot itself, or some future
/// source.
///
/// Construct one per inbound message and hand it to `ChatState.add(_:)`.
/// The `isBot` flag drives whether the LLM sees this message as
/// `assistant` or `user` when history is replayed into a chat completion
/// request, and also exempts bot-authored messages from the
/// message-count interjection trigger.
public struct ChatMessage: Sendable {
    
    /// The ID of the original Telegram message this represents, if it came from Telegram
    let id: TGMessage.ID?
    
    /// Display name of whoever sent this message.
    let senderName: String
    
    /// Distinguishes the bot's own utterances from human participants and system messages.
    /// Drives role assignment when building prompts and exempts bot
    /// messages from the message-count interjection trigger.
    let role: Role
    
    /// Whether this was a reply to another message
    let isReply: Bool
    
    /// Raw text content. Trimmed of surrounding whitespace at the
    /// boundary; the constructor trusts the caller not to pass empty
    /// strings.
    let text: String
}



extension ChatMessage {
    
    /// Builds a chat message using the given incoming message details
    ///
    /// - Parameters:
    ///   - incomingMessage: The original message sent from a Telegram user
    ///   - sender:          A pre-calculated pretty name for the sender
    ///   - wholeUserText:   The text of the message, already verified that it's non-empty
    init(_ incomingMessage: TGMessage, sender: String, wholeUserText: String) {
        self.init(
            id: incomingMessage.id,
            senderName: sender,
            role: (incomingMessage.from?.isBot ?? false)
                ? .assistant
                : .user,
            isReply: nil != incomingMessage.replyToMessage,
            text: wholeUserText)
    }
    
    
    /// Whether this was a random "autonomous" interjection by the bot
    var isBotInterjection: Bool {
        isBot && !isReply
    }
    
    
    private var isBot: Bool {
        switch role {
        case .assistant: return true
        case .system, .user: return false
        }
    }
    
    
    var contentForLlm: String {
        switch role {
        case .system:
            text
            
        case .assistant, .user:
            """
            \(senderName):
            \(text)
            """
        }
    }
}



extension ChatMessage {
    
    /// The role form which a chat message was sent
    enum Role: String, Codable, Sendable {
        
        /// The message was sent from the system (Telegram, system prompt, etc.)
        case system
        
        /// The message was sent by the bot itself
        case assistant
        
        /// The message was manually sent by a meatspace user
        case user
    }
}



// MARK: - Conveniences

//extension ChatMessage {
//    
//    /// The content of this chat message, formatted to send to an LLM
//    var formattedToShowToLlm: String {
//        switch role {
//        case .system:    "[SYSTEM: \(text)]"
//        case .assistant: "You: \(text)"
//        case .user:      "\(senderName): \(text)"
//        }
//    }
//}
//
//
//
//extension [ChatMessage] {
//    
//    /// All the messages in this chat message array, concatenate in a way that an LLM can process
//    var formattedToShowToLlm: String {
//        map(\.formattedToShowToLlm)
//        .joined(separator: "\n\n")
//    }
//}
