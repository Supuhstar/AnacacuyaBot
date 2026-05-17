//
//  Ollama + generate.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public extension Ollama {
    // Ideally, these are each in a separate file alongside their bespoke types
    
    func generate(
        model: OllamaModel,
        prompt: String,
        suffix: String? = nil,
        images: [Data]? = nil,
        systemPrompt: String? = nil,
        think: OllamaThinking? = nil,
        raw: Bool? = nil,
        keepAlive: Duration? = nil,
        option: OllamaModelOptions? = nil,
        logProbabilities: Bool? = nil,
        top_logProbabilities: Int? = nil,
    ) async throws -> OllamaGenerateResponse {
        // ...
    }
}



public struct OllamaGenerateResponse: OllamaResponse {
    let model: String
    let createdAt: Date
    let response: String
    let thinking: String?
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
