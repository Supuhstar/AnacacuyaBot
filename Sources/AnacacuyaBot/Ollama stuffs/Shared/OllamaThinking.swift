//
//  OllamaThinking.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



/// How much reasoning budget to grant a reasoning-capable model for a given call.
///
/// You may also use `true`/`false` instead of one of these cases.
///
/// Sending it to a model that doesn't declare the `thinking` capability will likely be silently ignored.
public enum OllamaThinking: OllamaRequest {
    
    /// Disable reasoning entirely
    case off
    
    /// Use the model's default reasoning budget
    case auto
    
    /// Constrain reasoning to a small budget
    case low
    
    /// Allow a moderate reasoning budget
    case medium
    
    /// Allow a large reasoning budget
    case high
}



extension OllamaThinking {
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .off:    try container.encode(false)
        case .auto:   try container.encode(true)
        case .low:    try container.encode("low")
        case .medium: try container.encode("medium")
        case .high:   try container.encode("high")
        }
    }
}



extension OllamaThinking: ExpressibleByBooleanLiteral {
    
    /// Allows callers write `think: true` and `think: false`, matching Ollama's request format.
    public init(booleanLiteral value: BooleanLiteralType) {
        switch value {
        case true:
            self = .auto
        case false:
            self = .off
        }
    }
}
