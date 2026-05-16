//
//  OllamaModel.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//


public struct OllamaModel: OllamaResponse {
    let name: String
    let capabilities: [ModelCapability]
}



public enum ModelCapability: OllamaResponse {
    case completion
    case thinking
    case vision
    case other(String)
}
