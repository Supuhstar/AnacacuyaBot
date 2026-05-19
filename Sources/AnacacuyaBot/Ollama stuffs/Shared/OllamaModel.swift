//
//  OllamaModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//


/// Represents a machine-learning model in Ollama
public struct OllamaModel: OllamaResponse {
    
    /// The name of the model
    let name: ModelName
    
    /// Any known capabilities that the model has
    let capabilities: [ModelCapability]?
}



extension OllamaModel: CustomStringConvertible {
    public var description: String {
        if let capabilities = capabilities?.nonEmptyOrNil {
            "\(name.description) (\(capabilities.map(\.description).joined(separator: ", ")))"
        }
        else {
            name.description
        }
    }
}



// MARK: - ModelCompatibility

/// A known capability of a machine-learning model
public enum ModelCapability: OllamaResponse, Equatable {
    
    /// The model can complete text
    case textCompletion
    
    /// The model can have a "thinking"/"reasoning" phase before composing its final output
    case thinking
    
    /// The model is capable of understanding images
    case vision
    
    /// A catchall for any capability not included in this enum
    case other(String)
}



public extension ModelCapability {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "completion": self = .textCompletion
        case "thinking": self = .thinking
        case "vision": self = .vision
        default: self = .other(value)
        }
    }
}



extension ModelCapability: CustomStringConvertible {
    public var description: String {
        switch self {
        case .textCompletion: return "text completion"
        case .thinking: return "thinking"
        case .vision: return "vision"
        case .other(let value): return value
        }
    }
}
