//
//  Ollama + embed.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public extension Ollama {
    
    /// Generates embedding vectors for one or more inputs.
    ///
    /// An embedding is a fixed-size numeric representation of a piece of text such
    /// that semantically similar texts end up close together in vector space. Use
    /// this for retrieval (find passages similar to a query), clustering, or as the
    /// first stage of a search pipeline. The model has to be an embedding model —
    /// asking a chat model produces meaningless vectors.
    ///
    /// Batching multiple inputs in one call is meaningfully cheaper than one call
    /// per input: the network round-trip dominates over the embedding itself for
    /// small strings. Hand this whatever batch your call site naturally produces;
    /// Ollama will tokenize and embed them in parallel server-side.
    ///
    /// - Parameters:
    ///   - model:      The embedding model to run.
    ///   - input:      The strings to embed. One vector is returned per string,
    ///                 in the same order.
    ///   - truncate:   _optional_ - `true` to silently truncate inputs that exceed the model's context length, `false` to fail the request
    ///                 instead. `nil` defers to Ollama's default, which is `true`.
    ///   - dimensions: _optional_ - Override the vector dimensionality. Only meaningful for
    ///                 models that support truncation of their native embedding
    ///                 space, like Matryoshka-trained models.
    ///   - keepAlive:  _optional_ - How long the model should remain loaded after this request.
    ///                 `nil` defers to Ollama's default (~5 minutes).
    ///   - options:    _optional_ - Per-call overrides for model parameters.
    ///                 It's rare that an `embed` call uses this, since embeddings are deterministic for a given input.
    ///
    /// - Returns: The embedding vectors, one per input, plus performance telemetry.
    func embed(
        model: OllamaModel,
        input: [String],
        truncate: Bool? = nil,
        dimensions: Int? = nil,
        keepAlive: Duration? = nil,
        options: OllamaModelOptions? = nil,
    ) async throws -> OllamaEmbedResponse {
        try await post(to: "embed",
            OllamaEmbedRequest(
                model: model.name,
                input: input,
                truncate: truncate,
                dimensions: dimensions,
                keepAlive: keepAlive.map { "\($0.seconds)s" },
                options: options,
            )
        )
    }
}



/// Request body for `/api/embed`. Embedding requests are inherently batched, so
/// `input` is an array even for single-string callers — keeping the wire shape
/// uniform avoids a special case in the response too, which always returns an
/// array of vectors regardless of input cardinality.
private struct OllamaEmbedRequest: OllamaRequest {
    
    /// Model name
    let model: ModelName
    
    /// Text or array of texts to generate embeddings for
    let input: [String]
    
    /// If `true`, truncate inputs that exceed the context window. If `false`, returns an error.
    let truncate: Bool?
    
    /// Number of dimensions to generate embeddings for
    let dimensions: Int?
    
    /// Model keep-alive duration
    let keepAlive: String?
    
    /// Runtime options that control text generation
    let options: OllamaModelOptions?
}



/// The vectors and telemetry returned by `/api/embed`. The vector dimensionality
/// is determined by the model — for `nomic-embed-text` it's 768, for
/// `mxbai-embed-large` it's 1024, and so on. Treat the count as part of the
/// model's contract, not a value to vary at the call site (unless you've passed
/// `dimensions` and the model honors it).
public struct OllamaEmbedResponse: OllamaResponse {
    
    /// Model that produced the embeddings
    let model: String?
    
    /// Array of vector embeddings
    let embeddings: [[Double]]?
    
    /// Total time spent generating
    let totalDuration: Duration?
    
    /// Load time
    let loadDuration: Duration?
    
    /// Number of input tokens processed to generate embeddings
    let promptEvalCount: Int?
}



extension OllamaEmbedResponse {
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model     = try container.decode(String.self, forKey: .model)
        
        self.embeddings =      try container.decodeIfPresent([[Double]].self, forKey: .embeddings)
        self.totalDuration =   try container.decodeIfPresent(Int.self, forKey: .totalDuration).map{.nanoseconds($0)}
        self.loadDuration =    try container.decodeIfPresent(Int.self, forKey: .loadDuration).map{.nanoseconds($0)}
        self.promptEvalCount = try container.decodeIfPresent(Int.self, forKey: .promptEvalCount)
    }
    
    
    enum CodingKeys: String, CodingKey {
        case model
        case embeddings
        case totalDuration
        case loadDuration
        case promptEvalCount
    }
}
