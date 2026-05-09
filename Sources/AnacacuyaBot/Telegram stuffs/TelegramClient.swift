//
//  TelegramClient.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation
#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

import SerializationTools



private let keyDecodingStrategy = JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase
private let keyEncodingStrategy = JSONEncoder.KeyEncodingStrategy.convertToSnakeCase



actor TelegramClient {
    private let token: String
    private let base: String
    private var offset: Int = 0
    public let botUser: TGUser
    
    
    init(token: String) async throws {
        self.token = token
        let base = "https://api.telegram.org/bot\(token)"
        self.base = base
        
        self.botUser = try await {
            let url = URL(string: "\(base)/getMe")!
            let (data, _) = try await URLSession.shared.data(from: url)
            struct R: Decodable { let result: TGUser }
            return try R(jsonData: data, keyDecodingStrategy: keyDecodingStrategy).result
        }()
    }
    
    
    func getUpdates(timeout: Int = 30) async throws -> [TGUpdate] {
        var comps = URLComponents(string: "\(base)/getUpdates")!
        comps.queryItems = [
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "timeout", value: "\(timeout)"),
            URLQueryItem(name: "allowed_updates", value: #"["message"]"#),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let response = try TGGetUpdatesResponse(jsonData: data, keyDecodingStrategy: keyDecodingStrategy)
        if let last = response.result.last {
            offset = last.updateId + 1
        }
        return response.result
    }
    
    
    func sendMessage(chatId: Int64, text: String, replyTo: Int? = nil) async throws {
        print("🗣️\(nil == replyTo ? "🤖" : "👩🏽‍💻"):", text)
        let url = URL(string: "\(base)/sendMessage")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = TGSendMessageBody(chatId: chatId, text: text, replyToMessageId: replyTo, parseMode: .markdown)
        req.httpBody = try body.jsonData(keyEncodingStrategy: keyEncodingStrategy)
        let response = try await URLSession.shared.data(for: req)
        
        if let httpResponse = (response.1 as? HTTPURLResponse),
           !(200..<299).contains(httpResponse.statusCode)
        {
            print("❌ \(httpResponse.statusCode) error: \(String(data: response.0, encoding: .utf8) ?? "(couldn't decode response)")")
        }
    }
}
