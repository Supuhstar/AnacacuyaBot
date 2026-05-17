//
//  OllamaModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//


public struct OllamaModel: OllamaResponse {
    let name: String
    let capabilities: [ModelCapability]?
}



public enum ModelCapability: OllamaResponse {
    case completion
    case thinking
    case vision
    case other(String)
}



public extension ModelCapability {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "completion": self = .completion
        case "thinking": self = .thinking
        case "vision": self = .vision
        default: self = .other(value)
        }
    }
}
