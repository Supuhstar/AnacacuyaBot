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

    func chat(messages: [OllamaMessage]) async throws -> String {
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
            struct Msg: Decodable { let content: String }
            let message: Msg
        }
        
        req.httpBody = try Body(model: model, messages: messages, stream: false).jsonData()
        let (data, _) = try await URLSession.shared.data(for: req)
        return try Response(jsonData: data).message.content
    }
}



struct OllamaMessage: Codable, Sendable {
    let role: Role
    let content: String
}



extension OllamaMessage {
    enum Role: String, Codable, Sendable {
        case system
        case assistant
        case user
    }
}
