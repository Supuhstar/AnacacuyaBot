//
//  Ollama + pushModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



public extension Ollama {
    
    /// Uploads a local model to the Ollama registry under the namespace baked into its name.
    /// 
    /// The local Ollama instance **MUST** be authenticated to that namespace, typically by signing in with `ollama signin` at the CLI.
    ///
    /// - Attention: The Ollama instance **MUST** be authenticated in the same namespace as `modelName.namespace`.
    ///
    /// - Parameter modelName: The name of the model to push.
    ///                        The `namespace` of this name **MUST** be the same namespace in which the Ollama instance is authenticated.
    ///
    /// - Returns: A status response indicating completion.
    func pushModel(named modelName: ModelName) async throws -> OllamaStatusOnlyResponse {
        try await post(to: "push",
            OllamaPushModelRequest(model: modelName)
        )
    }
}



/// Request body for `/api/push`
///
/// `stream` is hardcoded to `false` because this current Swift code assumes a single response object per request.
private struct OllamaPushModelRequest: OllamaRequest {
    
    /// Name of the model to publish
    let model: ModelName
    
    /// Allow publishing over insecure connections
    let insecute = false
    
    /// Stream progress updates
    let stream = false
}
