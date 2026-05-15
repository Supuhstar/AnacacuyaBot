//
//  TGMessage.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-15.
//

import Foundation



struct TGMessage: Decodable, Sendable {
    let messageId: ID
    let from: TGUser?
    let chat: TGChat
    let text: String?
    let date: Int
    let replyToMessage: TGRepliedToMessage?
    let entities: [TGMessageEntity]?
}



extension TGMessage {
    var sentDate: Date {
        Date(timeIntervalSince1970: .init(date))
    }
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
