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
import RegexBuilder

import SerializationTools



private let keyDecodingStrategy = JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase
private let keyEncodingStrategy = JSONEncoder.KeyEncodingStrategy.convertToSnakeCase



actor TelegramClient {
    private let base: String
    private var offset: Int = 0
    public let botUser: TGUser
    
    
    init(token: TelegramBotToken) async throws {
        let base = "https://api.telegram.org/bot\(token.withoutTypeSafety())"
        self.base = base
        
        self.botUser = try await {
            let url = URL(string: "\(base)/getMe")!
            let (data, _) = try await URLSession.shared.data(from: url)
            struct R: Decodable { let result: TGUser }
            return try R(jsonData: data, keyDecodingStrategy: keyDecodingStrategy).result
        }()
    }
    
    
    func getUpdates() async throws -> [TGUpdate] {
        var comps = URLComponents(string: "\(base)/getUpdates")!
        comps.queryItems = [
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "timeout", value: "\(Int(Limits.maxTimeToWaitForNewTelegramMessages.timeInterval))"),
            URLQueryItem(name: "allowed_updates", value: #"["message"]"#),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        
        do {
            let response = try TGGetUpdatesResponse(jsonData: data, keyDecodingStrategy: keyDecodingStrategy)
            if let last = response.result.last {
                offset = last.updateId + 1
            }
            return response.result
        }
        catch {
            throw UpdateError.unexpectedUpdate(data)
        }
    }
    
    
    func sendMessage(chatId: Int64, text: String, inReplyTo: Int? = nil) async throws {
        guard text.isNotEmpty
              || (text.matches(noResponseRegex))
        else {
            print("🙊 (chose to say nothing)")
            return
        }
        
        print("🗣️\(nil == inReplyTo ? "🤖" : "👩🏽‍💻"):", text)
        let url = URL(string: "\(base)/sendMessage")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = TGSendMessageBody(chatId: chatId, text: text, replyToMessageId: inReplyTo, parseMode: .markdown)
        req.httpBody = try body.jsonData(keyEncodingStrategy: keyEncodingStrategy)
        let response = try await URLSession.shared.data(for: req)
        
        if let httpResponse = (response.1 as? HTTPURLResponse),
           !(200..<299).contains(httpResponse.statusCode)
        {
            print("❌ \(httpResponse.statusCode) error: \(String(data: response.0, encoding: .utf8) ?? "(couldn't decode response)")")
        }
    }
    
    
    
    enum UpdateError: Error {
        case unexpectedUpdate(Data)
        
        
        var localizedDescription: String {
            switch self {
            case .unexpectedUpdate(let data): return "Unexpected update: \(String(data: data, encoding: .utf8) ?? "<COULD NOT DECODE>")"
            }
        }
    }
}



//unsafe: Unsure if there's a better way to do this. Pretty sure `Regex` is safe to be nonisolated anyway.
@safe
nonisolated(unsafe)
private let noResponseRegex = Regex {
        Anchor.startOfSubject
        ChoiceOf {
            bracketed("[", noResponseGeneratedString, "]")
            bracketed("{", noResponseGeneratedString, "}")
            bracketed("(", noResponseGeneratedString, ")")
        }
        ZeroOrMore(.whitespace)
        Optionally {
            "."
        }
        ZeroOrMore(.whitespace)
        Anchor.endOfSubject
    }
    .ignoresCase()



private func bracketed(_ opening: Character, _ body: String, _ closing: Character) -> Regex<(Substring, Substring)> {
    Regex {
        Capture {
            "["
            ZeroOrMore(.whitespace)
            body
            ZeroOrMore(.whitespace)
            "]"
        }
    }
}
