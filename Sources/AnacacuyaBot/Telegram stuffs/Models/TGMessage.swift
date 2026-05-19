//
//  TGMessage.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-15.
//

import Foundation



/// A message the bot has received from Telegram.
///
/// Carries everything the bot might need to understand the message: who sent
/// it, where it lives, what it says (text or caption), what media it carries,
/// and what it's replying to. Fields are optional whenever the wire format
/// allows their absence — Telegram's documentation is the source of truth on
/// which combinations are valid.
///
/// Source: https://core.telegram.org/bots/api#message
struct TGMessage: Decodable, Sendable {
    
    /// Unique message identifier inside this chat.
    let messageId: ID
    
    /// Sender of the message. Absent for messages sent on behalf of a channel.
    let from: TGUser?
    
    /// Chat the message belongs to.
    let chat: TGChat
    
    /// Text of the message. Present for text messages and absent for media
    /// messages (whose user-typed text lives in `caption` instead).
    let text: String?
    
    /// Caption accompanying a media payload (animation, audio, document, paid
    /// media, photo, video, or voice). When the user attaches a photo and
    /// types something alongside it, the typed part arrives here, not in `text`.
    let caption: String?
    
    /// Special entities (mentions, URLs, bot commands, formatting) appearing
    /// in `text`.
    let entities: [TGMessageEntity]?
    
    /// Available sizes of the photo, when the message is a photo. Telegram
    /// pre-renders multiple resolutions of every photo and delivers them all
    /// here; see ``Array/largest(under:)`` for the selection policy.
    let photo: [TGPhotoSize]?
    
    /// Unix timestamp of when the message was sent.
    let date: Int
    
    /// The original message, when this message is a reply. The wire format
    /// guarantees no further nesting beyond one level.
    let replyToMessage: TGRepliedToMessage?
}



extension TGMessage {
    
    /// `date` as a Swift `Date`. The wire format gives Unix seconds; this
    /// surfaces them as the platform type the rest of the codebase uses.
    var sentDate: Date {
        Date(timeIntervalSince1970: .init(date))
    }
}



extension TGMessage: Identifiable {
    
    /// Identity tracks `messageId` because it's stable within a chat for the
    /// lifetime of the message.
    var id: Int { messageId }
}
