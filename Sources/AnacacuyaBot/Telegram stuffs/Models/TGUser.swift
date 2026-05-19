//
//  TGUser.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//

import Foundation



/// A Telegram user account, which may be a human or a bot.
///
/// Source: https://core.telegram.org/bots/api#user
public struct TGUser: Decodable, Sendable {
    
    /// Unique identifier for this user or bot. Telegram notes this may exceed
    /// 32 bits but stays within 52, so `Int64` is safe.
    let id: Int64
    
    /// `true` if this user is a bot account.
    let isBot: Bool
    
    /// User's or bot's first name. Always present in the wire format.
    let firstName: String
    
    /// Username, when the user has set one. Absent for users without a public
    /// handle.
    let username: String?
}



extension TGUser {
    
    /// A display name suitable for inclusion in an LLM prompt context.
    ///
    /// The bot's transcripts use this when serializing speaker labels. Picking
    /// a single canonical spelling per user keeps the same person from
    /// appearing under multiple aliases across messages, which would confuse
    /// small models that pattern-match on speaker names.
    var nameForLlm: String {
        if let username {
            "\(firstName) (@\(username))"
        }
        else if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            "an anonymous user"
        }
        else {
            firstName
        }
    }
}
