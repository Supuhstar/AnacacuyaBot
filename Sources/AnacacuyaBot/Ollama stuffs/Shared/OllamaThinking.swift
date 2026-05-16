//
//  OllamaThinking.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



public enum OllamaThinking: OllamaRequest {
    case off
    case auto
    case low
    case medium
    case high
}



extension OllamaThinking: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        switch value {
        case true:
            self = .auto
        case false:
            self = .off
        }
    }
}
