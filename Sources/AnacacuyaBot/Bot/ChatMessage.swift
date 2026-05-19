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
    
    /// Textual content of the message. Trimmed of surrounding whitespace
    /// at the boundary.
    ///
    /// May be empty when ``images`` is non-empty — a user sending a bare
    /// photo with no caption produces a message with empty text and a
    /// non-empty images array. Otherwise empty text indicates the
    /// message wasn't worth recording, and the caller is expected to
    /// guard against that case before constructing.
    let text: String
    
    /// Images attached to this message, pre-processed by a vision model.
    ///
    /// Nil whenever the message is text-only, which is the common case, including every outgoing message the bot itself sends right now.
    let images: [ProcessedImage]?
    
    
    /// Builds a `ChatMessage` with all fields specified explicitly.
    ///
    /// `images` defaults to `nil` because the common case is text-only messages (user messages to each other, system prompts, bot replies, etc.). Making image attachment opt-in via a default keeps the common call site terse while preserving access for the vision-handling path that does pass image bytes.
    init(
        id: TGMessage.ID?,
        senderName: String,
        role: Role,
        isReply: Bool,
        text: String,
        images: [ProcessedImage]? = nil,
    ) {
        self.id = id
        self.senderName = senderName
        self.role = role
        self.isReply = isReply
        self.text = text
        self.images = images
    }
}



extension ChatMessage {
    
    /// Builds a chat message using the given incoming message details
    ///
    /// - Parameters:
    ///   - incomingMessage: The original message sent from a Telegram user
    ///   - sender:          A pre-calculated pretty name for the sender
    ///   - wholeUserText:   The text of the message, already verified that it's non-empty
    ///   - images:          _optional_ - Any images attached to the message, when the bot has resolved & processed them.
    ///                      Nil when the message is text-only or when the bot couldn't download the photos.
    init(_ incomingMessage: TGMessage, sender: String, wholeUserText: String, images: [ProcessedImage]? = nil) {
        self.init(
            id: incomingMessage.id,
            senderName: sender,
            role: (incomingMessage.from?.isBot ?? false)
                ? .assistant
                : .user,
            isReply: nil != incomingMessage.replyToMessage,
            text: wholeUserText,
            images: images)
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
            textForLlm
            
        case .assistant, .user:
            """
            \(senderName):
            \(textForLlm)
            """
        }
    }
    
    
    /// The message's text which we will show to the LLM.
    ///
    /// If this message includes images, then this returns image descriptions as well as user text.
    var textForLlm: String {
        if let imagesDescription {
            """
            \(imagesDescription)
            \(text)
            """
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        else {
            text
        }
    }
    
    
    /// The message's images' descriptions, all as one string
    var imagesDescription: String? {
        guard let images = images?.nonEmptyOrNil else {
            return nil
        }
        
        if images.count == 1 {
            return """
                Image attachment: \(images[0].visionModelDescription)
                """
        }
        else {
            return """
                \(images.count) images:
                \(images
                    .enumerated()
                    .map { (index, image) in
                        "- Image attachment \(index + 1): \(image.visionModelDescription)"
                    }
                    .joined(separator: "\n")
                )
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
