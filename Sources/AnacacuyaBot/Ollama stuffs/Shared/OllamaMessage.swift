//
//  OllamaMessage.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



/// A message to or from the LLM
public struct OllamaMessage: OllamaTranceivable {
    let role: ChatMessage.Role
    var content: String
    var thinking: String?
    var toolCalls: [OllamaToolCall]?
    var images: [Data]?
}



// MARK: - Conversions

public extension OllamaMessage {
    init(_ chatMessage: ChatMessage) async {
        self.init(
            role: chatMessage.role,
            content: await chatMessage.contentForLlm,
            thinking: nil,
            toolCalls: nil,
            images: chatMessage.images?.map(\.rawData)
        )
    }
}
