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
    
    /// Whoever sent this message.
    let sender: TGUser
    
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
    
    /// Tools that the LLM called in this message, if any
    let toolCalls: [OllamaToolCall]?
    
    /// Images attached to this message, pre-processed by a vision model.
    ///
    /// Nil whenever the message is text-only, which is the common case, including every outgoing message the bot itself sends right now.
    let images: [ProcessedImage]?
    
    
    /// Builds a `ChatMessage` with all fields specified explicitly.
    ///
    /// `images` defaults to `nil` because the common case is text-only messages (user messages to each other, system prompts, bot replies, etc.). Making image attachment opt-in via a default keeps the common call site terse while preserving access for the vision-handling path that does pass image bytes.
    init(
        id: TGMessage.ID?,
        sender: TGUser,
        role: Role,
        isReply: Bool,
        text: String,
        toolCalls: [OllamaToolCall]?,
        images: [ProcessedImage]? = nil,
    ) {
        self.id = id
        self.sender = sender
        self.role = role
        self.isReply = isReply
        self.text = text
        self.toolCalls = toolCalls
        self.images = images
    }
}



public extension ChatMessage {
    
    /// Builds a chat message using the given incoming message details
    ///
    /// - Parameters:
    ///   - incomingMessage: The original message sent from a Telegram user
    ///   - sender:          A pre-calculated pretty name for the sender
    ///   - wholeUserText:   The text of the message, already verified that it's non-empty
    ///   - images:          _optional_ - Any images attached to the message, when the bot has resolved & processed them.
    ///                      Nil when the message is text-only or when the bot couldn't download the photos.
    init(_ incomingMessage: TGMessage, sender: TGUser, wholeUserText: String, images: [ProcessedImage]? = nil) {
        self.init(
            id: incomingMessage.id,
            sender: sender,
            role: (incomingMessage.from?.isBot ?? false)
                ? .assistant
                : .user,
            isReply: nil != incomingMessage.replyToMessage,
            text: wholeUserText,
            toolCalls: nil,
            images: images)
    }
    
    
    /// Whether this was a random "autonomous" interjection by the bot
    var isBotInterjection: Bool {
        isBot && !isReply
    }
    
    
    private var isBot: Bool {
        switch role {
        case .assistant: return true
        case .system, .user, .tool: return false
        }
    }
    
    
    @MainActor
    var contentForLlm: String {
        switch role {
        case .system:
            textForLlm
        
        case .tool:
            text
        
        case .assistant, .user:
            """
            \(sender.nameForLlm):
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



public extension ChatMessage {
    
    /// Constructs a chat message to send to the bot as a way of communicating the result of calling a tool
    ///  
    /// - Parameters:
    ///   - originalToolCall: The original tool call from the LLM
    ///   - toolName:         The name of the tool which was called
    ///   - resultText:       The text of the result of the tool call, if any
    ///   - resultImages:     The images that the tool produced, if any
    static func toolCallResult(originalToolCall: OllamaToolCall, toolName: String, resultText: String?, resultImages: [ProcessedImage]?) -> Self {
        ChatMessage(
            id: nil,
            sender: .toolCall(toolName: toolName),
            role: .tool,
            isReply: false,
            text: resultText ?? "",
            toolCalls: [originalToolCall],
            images: resultImages,
        )
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
        
        /// The message is the result of a tool being run
        case tool
    }
}



// MARK: - Conversions

extension ChatMessage {
    
    init(_ ollamaMessage: OllamaMessage, isReply: Bool) async {
        self.init(
            id: nil,
            sender: await .botUser,
            role: ollamaMessage.role,
            isReply: isReply,
            text: ollamaMessage.content,
            toolCalls: ollamaMessage.toolCalls,
            images: ollamaMessage.images?.map { imageData in
                // TODO: Is this the best approach here?
                ProcessedImage(
                    rawData: imageData,
                    visionModelDescription: "(no description)",
                )
            },
        )
    }
}



// MARK: - Systemic conveniences

extension ChatMessage {
    
    static func system(isReply: Bool = false, text: String, images: [ProcessedImage]? = nil) -> Self {
        .init(
            id: nil,
            sender: .system,
            role: .system,
            isReply: isReply,
            text: text,
            toolCalls: nil,
            images: images,
        )
    }
}
