//
//  Ollama + listModels.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public extension Ollama {
    func listModels(
        _ modelCollection: OllamaModelCollection,
    ) async throws -> OllamaListModelsResponse {
        // ...
    }
}



public enum OllamaModelCollection: OllamaRequest {
    case all
    case currentlyRunning
}



public struct OllamaListModelsResponse: OllamaResponse {
    let models: [Model]?
}



extension OllamaListModelsResponse {
    struct Model: OllamaResponse {
        let name: String?
        let model: String?
        let remoteModel: String?
        let remoteHost: String?
        let modifiedAt: Date?
        let size: Int?
        let digest: String?
        let details: Details?
        let expiresAt: Date?
        let sizeVram: Int?
        let contextLength: Int?
    }
}



extension OllamaListModelsResponse.Model {
    struct Details: OllamaResponse {
        let parentModel: String?
        let format: String?
        let family: String?
        let families: [String]?
        let parameterSize: String?
        let quantizationLevels: String?
    }
}
