//
//  OllamaToolCall.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public struct OllamaToolCall: OllamaTranceivable {
    let function: Function
}

extension OllamaToolCall {
    struct Function: OllamaTranceivable {
        let name: String
        let parameters: JsonSchema
        var description: String?
        var arguments: [String : JsonValue]?
    }
}
