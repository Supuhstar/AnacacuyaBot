//
//  Ollama + pullModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//


public extension Ollama {
    func pullModel(
        named modelName: String,
    ) async throws -> OllamaStatusOnlyResponse {
        try await post(to: "pull",
            ["model": modelName],
        )
    }
}
