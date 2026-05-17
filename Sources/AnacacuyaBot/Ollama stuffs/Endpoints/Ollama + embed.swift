//
//  File.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//


public extension Ollama {
    func embed(
        model: OllamaModel,
        input: [String],
        truncate: Bool? = nil,
        dimensions: Int? = nil,
        keepAlive: Duration? = nil,
        options: OllamaModelOptions? = nil,
    ) async throws -> OllamaEmbedResponse {
        // ...
    }
}



public struct OllamaEmbedResponse: OllamaResponse {
    let model: String?
    let embeddings: [[Double]]?
    let totalDuration: Duration?
    let loadDuration: Duration?
    let promptEvalCount: Int?
}
