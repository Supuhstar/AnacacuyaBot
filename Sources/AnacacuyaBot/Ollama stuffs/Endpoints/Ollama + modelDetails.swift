//
//  Ollama + modelDetails.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public extension Ollama {
    func modelDetails(
        modelName: String,
        verbose: Bool? = nil,
    ) async throws -> OllamaModelDetailsResponse {
        // ...
    }
}



public struct OllamaModelDetailsResponse: OllamaResponse {
    let parameters: String?
    let license: String?
    let modifiedAt: Date??
    let details: OllamaListModelsResponse.Model.Details?
    let template: String?
    let capabilities: [ModelCapability]?
    let modelInfo: JsonValue?
}
