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

struct TGMessage: Decodable, Sendable {
    let messageId: Int
    let from: TGUser?
    let chat: TGChat
    let text: String?
    let replyToMessage: TGRepliedToMessage?
    let entities: [TGMessageEntity]?
}

struct TGRepliedToMessage: Decodable, Sendable {
    let messageId: Int
    let from: TGUser?
    let chat: TGChat
    let text: String?
    let entities: [TGMessageEntity]?
}

struct TGUser: Decodable, Sendable {
    let id: Int64
    let isBot: Bool
    let firstName: String
    let username: String?
}

struct TGChat: Decodable, Sendable, Identifiable {
    let id: Int64
    let type: TGChatType
    let title: String?
    
    let username: String?
    let firstName: String?
    let lastName: String?
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
}
