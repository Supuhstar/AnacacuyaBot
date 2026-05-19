//
//  Ollama + model.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-17.
//

import Foundation



public extension Ollama {
    
    /// Loads and fills out the details for the given model. If no such model could be found, this returns `nil`.
    ///
    /// This makes multiple calls to the Ollama API.
    ///
    /// - Parameters:
    ///   - modelName:     The name of the model you want to load
    ///   - pullIfMissing: _optional_ - If this is `true` and a model with the given name couldn't be found, then this function will attempt to download that model and then retry once.
    ///                    Otherwise, this function just goes with what it can find in the Ollama server's listed models.
    ///                    Defaults to `true`.
    ///
    /// - Returns: The model that this function found, or `nil` if no such model could be found
    func model(named modelName: ModelName, pullIfMissing: Bool = true) async throws -> OllamaModel? {
        let listedModel = try await listModels(.all)
            .models?
            .first(where: { $0.name == modelName || $0.model == modelName })
        
        if let listedModel {
            let modelName =
                listedModel.name
                ?? listedModel.model
                ?? modelName
            
            return OllamaModel(
                name: modelName,
                capabilities: try await modelDetails(modelName: modelName).capabilities,
            )
        }
        else {
            if pullIfMissing {
                _ = try await pullModel(named: modelName, timeout: .minutes(10))
                return try await model(named: modelName, pullIfMissing: false)
            }
            else {
                return nil
            }
        }
    }
}
