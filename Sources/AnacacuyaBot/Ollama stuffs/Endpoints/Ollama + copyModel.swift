//
//  Ollama + copyModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



public extension Ollama {
    
    /// Duplicates a model under a new name, leaving the original in place.
    ///
    /// Use this when authoring a customized variant of an upstream model: copy the
    /// base, then ``createModel(named:from:templatePrompt:license:systemPrompt:parameters:messages:quantize:)``
    /// to apply your Modelfile on top of the copy. Or use it to pin a tag — copying
    /// `smollm2:latest` to `smollm2:my-frozen` gives you a stable target that won't
    /// shift under your feet when upstream republishes.
    ///
    /// The server returns 200 OK with no response body on success, which is why
    /// this method returns `Void`. A 404 from the server means the source model
    /// does not exist; the underlying transport throws with that status.
    ///
    /// - Parameters:
    ///   - source:          The model to copy from.
    ///   - destinationName: The name to give the new copy.
    func copyModel(
        source: OllamaModel,
        destinationName: ModelName,
    ) async throws {
        try await post(to: "copy",
            OllamaCopyModelRequest(source: source.name, destination: destinationName)
        )
    }
}



/// Request body for `/api/copy`
private struct OllamaCopyModelRequest: OllamaRequest {
    
    /// Existing model name to copy from
    let source: ModelName
    
    /// New model name to create
    let destination: ModelName
}
