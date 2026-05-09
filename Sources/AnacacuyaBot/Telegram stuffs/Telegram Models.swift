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
    let messageId: ID
    let from: TGUser?
    let chat: TGChat
    let text: String?
    let replyToMessage: TGRepliedToMessage?
    let entities: [TGMessageEntity]?
}



extension TGMessage: Identifiable {
    var id: Int { messageId }
}



struct TGRepliedToMessage: Decodable, Sendable {
    let messageId: Int
    let from: TGUser?
    let chat: TGChat
    let text: String?
    let entities: [TGMessageEntity]?
}


extension TGRepliedToMessage {
    init(_ message: TGMessage) {
        self.init(
            messageId: message.messageId,
            from: message.from,
            chat: message.chat,
            text: message.text,
            entities: message.entities)
    }
}



struct TGUser: Decodable, Sendable {
    let id: Int64
    let isBot: Bool
    let firstName: String
    let username: String?
}



extension TGUser {
    var nameForLlm: String {
        if let username {
            "\(firstName) (\(username))"
        }
        else if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            "an anonymous user"
        }
        else {
            firstName
        }
    }
}



struct TGChat: Decodable, Sendable, Identifiable {
    let id: Int64
    let type: TGChatType
    let title: String?
    
    let username: String?
    let firstName: String?
    let lastName: String?
}



extension TGChat {
    var groupNameForLlm: String {
        title ?? username ?? "a group chat"
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
