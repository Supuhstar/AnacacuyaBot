//
//  OllamaClient.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation
#if os(Linux) || os(Windows)
import FoundationNetworking
#endif



actor OllamaClient {
    private let chatUrl: URL
    private let mutex = Mutex()
    let model: String
    
    
    init(baseURL: URL, model: String) {
        self.model = model
        self.chatUrl = baseURL.appending(path: "api/chat") //URL(string: "\(baseURL)/api/chat")!
    }
    
    
    nonisolated func chat(context: [ChatMessage], settings: ModelSettings?) async throws -> String {
        try await chat(context: context.map(OllamaMessage.init),
                       settings: settings)
    }
    
    
    nonisolated func chat(context: [OllamaMessage], settings: ModelSettings?) async throws -> String {
        try await mutex.run {
            struct Body: Encodable {
                let model: String
                let messages: [OllamaMessage]
                let options: ModelSettings?
                let stream: Bool
            }
            
            
            
            struct Response: Decodable {
                let message: Body
                
                
                
                struct Body: Decodable {
                    let content: String
                }
            }
            
            
            
            return try await Body(
                    model: model,
                    messages: context.reversed().withoutDuplicates().reversed(),
                    options: settings,
                    stream: false,
                )
                .post(to: chatUrl, receiving: Response.self)
                .message
                .content
        }
    }
}



struct OllamaMessage: Codable, Sendable, Equatable {
    let role: ChatMessage.Role
    let content: String
}



extension OllamaMessage {
    init(_ chatMessage: ChatMessage) {
        self.init(role: chatMessage.role, content: chatMessage.contentForLlm)
    }
}
