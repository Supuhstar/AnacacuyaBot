//
//  TGSendMessageParseMode.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//



/// How Telegram should interpret formatting marks in an outgoing message's text.
///
/// Picking a parse mode lets the bot send bold, italic, code blocks, links, and
/// the like. The cost is that any literal characters in the parse mode's
/// metasyntax must be escaped — failing to escape them surfaces as a 400 from
/// Telegram. `String + Telegram stuffs.swift` carries the escaping helpers.
///
/// Source: https://core.telegram.org/bots/api#formatting-options
enum TGSendMessageParseMode: String, Encodable, Sendable {
    
    /// Telegram's MarkdownV2 dialect — a tightened version of Markdown with
    /// stricter escaping rules than the legacy `Markdown` mode. The legacy mode
    /// is deprecated; new code should always use this.
    case markdown = "MarkdownV2"
}
