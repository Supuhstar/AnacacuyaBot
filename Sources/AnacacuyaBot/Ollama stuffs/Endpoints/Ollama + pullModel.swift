//
//  Ollama + pullModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



public extension Ollama {
    
    /// Downloads a model from the Ollama registry to the server's storage drive.
    ///  
    /// On a fresh install or after a model has been deleted, this is the call that makes a model usable.
    /// Attempting to pull a model that's already present is a fast no-op.
    ///  
    /// Pulls can take a while for larger models.
    /// This provides an explicit and required `timeout` field because a sufficiently large model on a slow connection will exceed the global timeout limit of this package.
    ///
    /// For background pulls of larger models, consider using a much longer timeout.
    /// 
    /// - Parameters:
    ///   - modelName: The qualified name of the model to pull
    ///   - timeout:   How long you're willing to wait until the download completes. Set this higher for larger models since they take more time.
    ///
    /// - Returns: The server's status response indicating completion.
    func pullModel(named modelName: ModelName, timeout: Duration) async throws -> OllamaStatusOnlyResponse {
        try await post(to: "pull",
            OllamaPullModelRequest(model: modelName),
            timeout: timeout,
        )
    }
}



/// Request body for `/api/pull`.
///
/// `stream` is hardcoded to `false` because this current Swift code assumes a single response object per request.
private struct OllamaPullModelRequest: OllamaRequest {
    
    /// Name of the model to download
    let model: ModelName
    
    /// Allow downloading over insecure connections
    let insecure = false
    
    /// Stream progress updates
    let stream = false
}
