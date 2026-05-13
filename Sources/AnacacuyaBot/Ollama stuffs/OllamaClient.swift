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

    init(baseURL: String = "http://localhost:11434", model: String = "smollm2") {
        self.model = model
        self.chatUrl = URL(string: "\(baseURL)/api/chat")!
    }
    
    
    nonisolated func chat(context: [ChatMessage]) async throws -> String {
        try await chat(context: context.map(OllamaMessage.init))
    }
    
    
    nonisolated func chat(context: [OllamaMessage]) async throws -> String {
        try await mutex.run {
            var req = URLRequest(url: chatUrl)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = Limits.maxTimeToWaitForModelResponse.timeInterval
            
            
            
            struct Body: Encodable {
                let model: String
                let messages: [OllamaMessage]
                let stream: Bool
            }
            
            
            
            struct Response: Decodable {
                let message: Body
                
                
                
                struct Body: Decodable {
                    let content: String
                }
            }
            
            
            
            req.httpBody = try Body(model: model, messages: context, stream: false).jsonData()
            let (data, _) = try await URLSession.shared.data(for: req)
            return try Response(jsonData: data).message.content
        }
    }
}



struct OllamaMessage: Codable, Sendable {
    let role: ChatMessage.Role
    let content: String
}



extension OllamaMessage {
    init(_ chatMessage: ChatMessage) {
        self.init(role: chatMessage.role, content: chatMessage.contentForLlm)
    }
}
