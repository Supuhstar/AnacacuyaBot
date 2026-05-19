//
//  Ollama + modelDetails.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public extension Ollama {
    
    /// Fetches detailed metadata for a specific model.
    ///
    /// The capabilities array is a very important field; it's how you determine whether a model can receive images for vision input, support tool calls, perform reasoning, etc..
    ///
    /// - Parameters:
    ///   - modelName: The model to query. Use the exact name as it appears in
    ///                ``listModels(_:)``, including any tag suffix (`:latest`,
    ///                `:7b`).
    ///   - verbose:   _optional_ - Whether to receive the full template and Modelfile contents. `false`keeps the response compact by omitting details deemed "large verbose fields". Defaults to server's choice.
    ///
    /// - Returns: The model's metadata.
    func modelDetails(modelName: ModelName, verbose: Bool? = nil) async throws -> OllamaModelDetailsResponse {
        try await post(to: "show",
            OllamaModelDetailsRequest(model: modelName, verbose: verbose)
        )
    }
}



/// Request body for `/api/show`.
private struct OllamaModelDetailsRequest: OllamaRequest {
    /// Model name to show
    let model: ModelName
    
    /// If true, includes large verbose fields in the response
    let verbose: Bool?
}



/// Response body for `/api/show`.
public struct OllamaModelDetailsResponse: OllamaResponse {
    
    /// Model parameter settings serialized as text
    let parameters: String?
    
    /// The license of the model
    let license: String?
    
    /// The last modified timestamp
    let modifiedAt: Date?
    
    /// High-level model details
    let details: OllamaListModelsResponse.Model.Details? // probably?
    
    /// The template used by the model to render prompts
    let template: String?
    
    /// List of supported features
    let capabilities: [ModelCapability]?
    
    /// Additional model metadata
    let modelInfo: JsonValue?
}
