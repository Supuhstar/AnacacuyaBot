//
//  TGRepliedToMessage.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//



/// A message being replied to, in flattened form.
///
/// This mirrors `TGMessage` minus the recursive `replyToMessage` field —
/// Telegram's wire format guarantees that field is never populated on a
/// replied-to message, so flattening it out at the type level prevents
/// infinite-size struct issues on Linux while keeping the wire shape honest.
///
/// Source: https://core.telegram.org/bots/api#message
struct TGRepliedToMessage: Decodable, Sendable {
    
    /// Unique message identifier inside this chat.
    let messageId: Int
    
    /// Sender of the message. Absent for messages sent on behalf of a channel.
    let from: TGUser?
    
    /// Chat the message belongs to.
    let chat: TGChat
    
    /// Text of the message. Present for text messages and absent for media
    /// messages (whose user-typed text lives in `caption` instead).
    let text: String?
    
    /// Caption accompanying a media payload (animation, audio, document, paid
    /// media, photo, video, or voice).
    let caption: String?
    
    /// Special entities (mentions, URLs, bot commands, formatting) appearing
    /// in `text`.
    let entities: [TGMessageEntity]?
    
    /// Available sizes of the photo, when the message is a photo.
    let photo: [TGPhotoSize]?
}



extension TGRepliedToMessage {
    
    /// Lossy projection from a full `TGMessage`. Used when echoing a message
    /// back in another message's `replyToMessage` slot — for example, in
    /// testing or when constructing synthetic replies.
    init(_ message: TGMessage) {
        self.init(
            messageId: message.messageId,
            from: message.from,
            chat: message.chat,
            text: message.text,
            caption: message.caption,
            entities: message.entities,
            photo: message.photo
        )
    }
}
