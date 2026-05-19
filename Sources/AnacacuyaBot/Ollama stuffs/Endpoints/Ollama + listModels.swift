//
//  Ollama + listModels.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public extension Ollama {
    
    /// Enumerates models known to the Ollama server.
    ///
    /// Two views of the world are available, distinguished by the `modelCollection`
    /// argument. `.all` queries `tags` and returns everything on disk — useful for
    /// availability checks and UI listings. `.currentlyRunning` queries `ps` and
    /// returns only models presently loaded in memory, with VRAM and expiry
    /// telemetry — useful for monitoring resource usage or deciding whether a pull
    /// would evict something.
    ///
    /// The two collections return the same `Model` shape, but different fields are
    /// populated for each: `.all` includes `modifiedAt`, `.currentlyRunning`
    /// includes `expiresAt` and `sizeVram`. The struct flattens both into one type
    /// with optional fields rather than splitting into two types, on the principle
    /// that callers usually know which they asked for, and the type-level
    /// distinction would add ceremony without preventing real mistakes.
    ///
    /// - Parameter modelCollection: Which view to query.
    ///
    /// - Returns: The list of models matching the selected view.
    func listModels(_ modelCollection: OllamaModelCollection) async throws -> OllamaListModelsResponse {
        try await get(from: modelCollection.endpointPath)
    }
}



/// Which set of models to enumerate when calling ``Ollama/listModels(_:)``.
///
/// This is a control-flow choice within our code rather than a value sent over the
/// wire — each case picks a different endpoint to GET — so it deliberately does
/// not conform to `OllamaRequest`. Treating it as an encodable value would invite
/// confusion about whether it appears in a request body somewhere.
public enum OllamaModelCollection: Sendable {
    
    /// All models the server has on disk. Backed by `/api/tags`.
    case all
    
    /// Only models presently loaded into memory. Backed by `/api/ps`.
    case currentlyRunning
}



private extension OllamaModelCollection {
    
    /// The endpoint path segment that produces this collection
    var endpointPath: String {
        switch self {
        case .all:              return "tags"
        case .currentlyRunning: return "ps"
        }
    }
}



public struct OllamaListModelsResponse: OllamaResponse {
    let models: [Model]?
}



/// Response body for `/api/ps` and `/api/tags.
extension OllamaListModelsResponse {
    
    /// One row in a listing response. The same shape serves both `/api/tags` and
    /// `/api/ps`; fields specific to one view are nullable so the type can carry
    /// either flavor of result without splitting into siblings.
    struct Model: OllamaResponse {
        
        /// Model name
        let name: ModelName?
        
        /// Model name
        let model: ModelName?
        
        /// Name of the upstream model, if the model is remote
        let remoteModel: ModelName?
        
        /// URL of the upstream Ollama host, if the model is remote
        let remoteHost: URL?
        
        /// Last-modified timestamp
        let modifiedAt: Date?
        
        /// Total size of the model in bytes
        let size: Int?
        
        /// SHA256 digest of the model
        let digest: String?
        
        /// Additional information about the model's format and family
        let details: Details?
        
        /// Time when the model will be unloaded
        let expiresAt: Date?
        
        /// VRAM usage in bytes
        let sizeVram: Int?
        
        /// Context length for the running model
        let contextLength: Int?
    }
}



extension OllamaListModelsResponse.Model {
    
    /// Model architecture and quantization metadata reported by Ollama.
    ///
    /// Useful for distinguishing variants of the same base model when several are installed.
    struct Details: OllamaResponse {
        
        /// Model file format (for example `gguf`)
        let format: String?
        
        /// Primary model family (for example `llama`)
        let family: String?
        
        /// All families the model belongs to, when applicable
        let families: [String]?
        
        /// Approximate parameter count label (for example, `7B`, `13B`)
        let parameterSize: String?
        
        /// Quantization level used (for example `Q4_0`)
        let quantizationLevel: String?
    }
}
