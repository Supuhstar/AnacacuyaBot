//
//  TGChatType.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//



/// The flavor of conversation a message belongs to.
///
/// Distinguishes 1:1 DMs from multi-party group conversations, which matters
/// throughout the bot: dispatch rules are different (DMs are implicitly
/// addressed to the bot, groups require explicit mention or reply), and admin
/// checks are only meaningful in group contexts.
///
/// Source: https://core.telegram.org/bots/api#chat
enum TGChatType: String, Decodable, Sendable {
    
    /// A one-on-one conversation between the bot and a single user.
    case `private`
    
    /// A small basic group chat.
    case group
    
    /// A supergroup — Telegram's larger group format with admin tools.
    case supergroup
    
    /// A broadcast channel.
    case channel
}
