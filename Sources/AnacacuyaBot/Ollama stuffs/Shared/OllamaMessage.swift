//
//  OllamaMessage.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public struct OllamaMessage: OllamaTranceivable {
    let role: ChatMessage.Role
    let content: String
    var thinking: String?
    var toolCalls: [OllamaToolCall]?
    var images: [Data]?
}



public extension OllamaMessage {
    init(_ chatMessage: ChatMessage) {
        self.init(
            role: chatMessage.role,
            content: chatMessage.contentForLlm,
            images: chatMessage.images
        )
    }
}
