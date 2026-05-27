//
//  OllamaToolCall.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public struct OllamaToolCall: OllamaTranceivable {
    public let function: Function
    
    
    public init(function: Function) {
        self.function = function
    }
}



public extension OllamaToolCall {
    struct Function: OllamaTranceivable {
        public let name: String
        public var description: String?
        public var arguments: [String : JsonValue]?
        
        
        public init(name: String, description: String? = nil, arguments: [String : JsonValue]? = nil) {
            self.name = name
            self.description = description
            self.arguments = arguments
        }
    }
}
