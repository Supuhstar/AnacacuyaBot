//
//  Ollama + createModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//


public extension Ollama {
    /// Create a model
    ///
    /// - Parameters:
    ///   - model:          Name for the model to create
    ///   - existingModel:  Existing model to create from
    ///   - templatePrompt: Prompt template to use for the model
    ///   - license:        License string or list of licenses for the model
    ///   - systemPrompt:   System prompt to embed in the model
    ///   - parameters:     Key-value parameters for the model
    ///   - messages:       Message history to use for the model
    ///   - quantize:       Quantization level to apply (e.g. `q4_K_M`, `q8_0`)
    ///
    /// - Returns: Result status message
    func createModel(
        named model: ModelName,
        from existingModel: ModelName? = nil,
        templatePrompt: String? = nil,
        license: [String]? = nil,
        systemPrompt: String? = nil,
        parameters: JsonValue? = nil,
        messages: [OllamaMessage]? = nil,
        quantize: String? = nil,
    ) async throws -> OllamaStatusOnlyResponse {
        try await self.post(to: "create",
            OllamaCreateModelRequest(
                model: model,
                from: existingModel,
                template: templatePrompt,
                license: license,
                system: systemPrompt,
                parameters: parameters,
                messages: messages,
                quantize: quantize,
            )
        )
    }
}



/// Request body for `/api/create`.
///
/// `stream` is hardcoded to `false` because this current Swift code assumes a single response object per request.
private struct OllamaCreateModelRequest: OllamaRequest {
    
    /// Name for the model to create
    let model: ModelName
    
    /// Existing model to create from
    let from: ModelName?
    
    /// Prompt template to use for the model
    let template: String?
    
    /// License(s) for the model
    let license: [String]?
    
    /// System prompt to embed in the model
    let system: String?
    
    /// Key-value parameters for the model
    let parameters: JsonValue?
    
    /// Message history to use for the model
    let messages: [OllamaMessage]?
    
    /// Quantization level to apply
    let quantize: String?
    
    /// Stream status updates?
    let stream = false
}



extension OllamaCreateModelRequest {
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(model, forKey: .model)
        try container.encodeIfPresent(from, forKey: .from)
        try container.encodeIfPresent(template, forKey: .template)
        
        if let license {
            switch license.count {
            case 0:
                break
                
            case 1:
                try container.encode(license[0], forKey: .license)
                
            default:
                try container.encode(license, forKey: .license)
            }
        }
        
        try container.encodeIfPresent(system, forKey: .system)
        try container.encodeIfPresent(parameters, forKey: .parameters)
        try container.encodeIfPresent(messages, forKey: .messages)
        try container.encodeIfPresent(quantize, forKey: .quantize)
        try container.encode(stream, forKey: .stream)
        
    }
    
    
    enum CodingKeys: String, CodingKey {
        case model, from, template, license, system, parameters, messages, quantize, stream
    }
}
