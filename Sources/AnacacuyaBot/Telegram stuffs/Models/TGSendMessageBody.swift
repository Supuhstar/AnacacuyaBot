//
//  TGSendMessageBody.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//



/// Request body for Telegram's `sendMessage` method.
///
/// Source: https://core.telegram.org/bots/api#sendmessage
struct TGSendMessageBody: Encodable, Sendable {
    
    /// Unique identifier for the target chat.
    let chatId: Int64
    
    /// Text of the message to be sent, 1-4096 characters after entities parsing.
    let text: String
    
    /// Identifier of the message this is a reply to, when threading semantics
    /// are desired. Nil for a fresh top-level send.
    let replyToMessageId: Int?
    
    /// Mode for parsing entities in the message text. When nil, Telegram treats
    /// the text as plain.
    let parseMode: TGSendMessageParseMode?
}
