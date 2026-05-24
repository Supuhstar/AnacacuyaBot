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
    private(set) var thinking: String?
    private(set) var toolName: String?
    private(set) var toolCalls: [OllamaToolCall]?
    private(set) var images: [Data]?
}



// MARK: - Conversions

public extension OllamaMessage {
    
    /// Converts the given chat message into an ``OllamaMessage``
    ///
    /// - Parameter chatMessage: The generic chat message to encode as a message to Ollama
    init(_ chatMessage: ChatMessage) async {
        self.init(
            role: chatMessage.role,
            content: await chatMessage.contentForLlm,
            thinking: nil,
            toolName: .tool == chatMessage.role ? chatMessage.sender.firstName : nil,
            toolCalls: nil,
            images: chatMessage.images?.map(\.rawData)
        )
    }
}
