//
//  OllamaTool.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



public struct OllamaTool: OllamaRequest {
    let type: Kind
    let function: Function
}



extension OllamaTool {
    enum Kind: OllamaRequest {
        case function
    }
    
    struct Function: OllamaRequest {
        let name: String
        let parameters: [JsonSchema]
        let description: String
    }
}
