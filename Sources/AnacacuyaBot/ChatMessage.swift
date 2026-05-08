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
struct ChatMessage: Sendable {
    /// Display name used to attribute the line when serializing history
    /// for the model. Resolved upstream from username → first name →
    /// fallback, so by the time it lands here it's a non-empty label.
    let senderName: String

    /// Raw text content. Trimmed of surrounding whitespace at the
    /// boundary; the constructor trusts the caller not to pass empty
    /// strings.
    let text: String

    /// Distinguishes the bot's own utterances from human participants.
    /// Drives role assignment when building prompts and exempts bot
    /// messages from the message-count interjection trigger.
    let isBot: Bool
    
    /// The name of the chat in which the message was sent.
    let chatName: String
}
