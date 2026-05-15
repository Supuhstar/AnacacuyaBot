//
//  Telegram Models.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation



// MARK: - Incoming

struct TGUpdate: Decodable, Sendable {
    let updateId: Int
    let message: TGMessage?
}



public struct TGUser: Decodable, Sendable {
    let id: Int64
    let isBot: Bool
    let firstName: String
    let username: String?
}



extension TGUser {
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







enum TGChatType: String, Decodable, Sendable {
    case `private`
    case group
    case supergroup
    case channel
}

struct TGMessageEntity: Decodable, Sendable {
    let type: String
    let offset: Int
    let length: Int
}

struct TGGetUpdatesResponse: Decodable, Sendable {
    let ok: Bool
    let result: [TGUpdate]
}

// MARK: - Outgoing

struct TGSendMessageBody: Encodable, Sendable {
    let chatId: Int64
    let text: String
    let replyToMessageId: Int?
    
    let parseMode: TGSendMessageParseMode?
}




enum TGSendMessageParseMode: String, Encodable, Sendable {
    case markdown = "MarkdownV2"
}
