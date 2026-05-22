//
//  Ollama + deleteModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



public extension Ollama {
    
    /// Removes the given model from the server's storage drive.
    ///
    /// The server returns 200 OK with an empty body on success (this returns silently), or 404 if the model wasn't there to begin with (this throws an error).
    ///
    /// - Attention: **This is irreversible!** There is no soft-delete or trash. The only recovery is to re-download or re-create the model
    ///
    /// - Parameter model: The model to delete.
    func deleteModel(_ model: OllamaModel) async throws {
        try await delete(from: "delete",
            OllamaDeleteModelRequest(model: model.name)
        )
    }
}



/// Request body for `/api/delete`
private struct OllamaDeleteModelRequest: OllamaRequest {
    
    /// Model name to delete
    let model: ModelName
}
