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
    private let baseURL: String
    let model: String

    init(baseURL: String = "http://localhost:11434", model: String = "smollm2") {
        self.baseURL = baseURL
        self.model = model
    }
    
    
    func chat(context: [ChatMessage]) async throws -> String {
        try await chat(context: context.map(OllamaMessage.init))
    }
    
    
    func chat(context: [OllamaMessage]) async throws -> String {
        let url = URL(string: "\(baseURL)/api/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = Limits.maxTimeToWaitForModelResponse.timeInterval

        struct Body: Encodable {
            let model: String
            let messages: [OllamaMessage]
            let stream: Bool
        }
        struct Response: Decodable {
            struct Body: Decodable { let content: String }
            let message: Body
        }
        
        req.httpBody = try Body(model: model, messages: context, stream: false).jsonData()
        let (data, _) = try await URLSession.shared.data(for: req)
        return try Response(jsonData: data).message.content
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
