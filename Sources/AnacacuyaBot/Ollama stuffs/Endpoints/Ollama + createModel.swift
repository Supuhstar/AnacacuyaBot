//
//  Ollama + createModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//


public extension Ollama {
    func createModel(
        named model: String,
        from existingModel: String? = nil,
        templatePrompt: String? = nil,
        license: [String]? = nil,
        systemPrompt: String? = nil,
        parameters: [String : Codable]? = nil,
        messages: [OllamaMessage]? = nil,
        quantize: String? = nil,
    ) async throws -> OllamaStatusOnlyResponse {
        // ...
    }
}
