//
//  Body.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public extension Ollama {
    func chat(
        model: OllamaModel,
        messages: [OllamaMessage],
        tools: [OllamaTool]? = nil,
        options: ModelSettings? = nil,
        think: OllamaThinking? = nil,
        keepAlive: Duration? = nil,
        logProbabilities: Bool? = nil,
        top_logProbabilities: Int? = nil,
    ) async throws -> OllamaChatResponse {
        
        return try await post(
            to: "chat",
            Body(
                model: model.name,
                messages: messages,
                tools: tools,
                options: options,
                think: think,
                keepAlive: keepAlive,
                logProbabilities: logProbabilities,
                top_logProbabilities: top_logProbabilities,
            )
        )
    }
}



private struct Body: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let tools: [OllamaTool]?
    let options: ModelSettings?
    let stream = false
    let think: OllamaThinking?
    let keepAlive: Duration?
    let logProbabilities: Bool?
    let top_logProbabilities: Int?
}



public extension Ollama {
    
    func chat(
        with model: OllamaModel,
        context: [ChatMessage],
        settings: ModelSettings?,
    ) async throws -> String {
        try await chat(
            with: model,
            context: context.map(OllamaMessage.init),
            settings: settings,
        )
    }
    
    
    func chat(
        with model: OllamaModel,
        context: [OllamaMessage],
        settings: ModelSettings?,
    ) async throws -> String {
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
        
        
        
        async let context = context
            .reversed()
            .withoutDuplicates(equatingBy: { lhs, rhs in
                lhs.content == rhs.content
            })
            .reversed()
        
        
        return try await self.chat(
            model: model,
            messages: Array(await context),
            options: settings,
        )
        .message
        .content
    }
}



public struct OllamaChatResponse: OllamaResponse {
    let model: String
    let createdAt: Date
    let message: OllamaMessage
    let done: Bool
    let doneReason: String?
    let totalDuration: Duration?
    let loadDuration: Duration?
    let promptEvalCount: Int?
    let promptEvalDuration: Duration?
    let evalCount: Int?
    let evalDuration: Duration?
    let logProbabilities: [OllamaLogProbability]?
}
