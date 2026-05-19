//
//  TGMessageEntity.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//



/// A special region of text within a message — a mention, a URL, a bot
/// command, formatting, etc.
///
/// The bot uses these to detect when it's being addressed: a `mention` entity
/// pointing to the bot's username is the canonical "you, bot, this is for you"
/// signal in group chats. Other entity types are decoded but ignored.
///
/// Source: https://core.telegram.org/bots/api#messageentity
struct TGMessageEntity: Decodable, Sendable {
    
    /// The kind of entity — `"mention"`, `"bot_command"`, `"url"`, etc.
    /// Telegram's enum grows over time; left as a raw string so unknown
    /// values decode without throwing.
    let type: String
    
    /// Offset to the start of the entity, measured in UTF-16 code units.
    /// Important: not bytes, not characters. Telegram's clients are built
    /// around UTF-16 indexing for historical reasons.
    let offset: Int
    
    /// Length of the entity, measured in UTF-16 code units.
    let length: Int
}
