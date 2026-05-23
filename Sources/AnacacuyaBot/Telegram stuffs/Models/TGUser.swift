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
    public let id: Int64
    
    /// `true` if this user is a bot account.
    public let isBot: Bool
    
    /// User's or bot's first name. Always present in the wire format.
    public let firstName: String
    
    /// Username, when the user has set one. Absent for users without a public
    /// handle.
    public let username: String?
    
    
    public init(id: Int64, isBot: Bool, firstName: String, username: String?) {
        self.id = id
        self.isBot = isBot
        self.firstName = firstName
        self.username = username
    }
}



extension TGUser {
    
    /// A display name suitable for inclusion in an LLM prompt context.
    /// 
    /// The bot's transcripts use this when serializing speaker labels. Picking
    /// a single canonical spelling per user keeps the same person from
    /// appearing under multiple aliases across messages, which would confuse
    /// small models that pattern-match on speaker names.
    ///
    /// - Returns: This user's name, appropriate to give to an LLM to describe its relationship to them
    @MainActor
    var nameForLlm: String {
        if TGUser.botUser.id == id {
            "you"
        }
        else if let username {
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



extension TGUser? {
    
    /// A display name suitable for inclusion in an LLM prompt context.
    ///
    /// The bot's transcripts use this when serializing speaker labels. Picking
    /// a single canonical spelling per user keeps the same person from
    /// appearing under multiple aliases across messages, which would confuse
    /// small models that pattern-match on speaker names.
    ///
    /// - Returns: This user's name, appropriate to give to an LLM to describe its relationship to them, or a placeholder if the user is unknown
    @MainActor
    var nameForLlm: String {
        self?.nameForLlm ?? "someone"
    }
}
