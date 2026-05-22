//
//  ExampleTool.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-22.
//

import Foundation

import SimpleLogging



/// A tool that an LLM can use
public struct ExampleTool: BotTool {
    
    /// The technical description of the tool which will be sent to Ollama
    public static let function = OllamaTool.Function(
        name: "Example",
        description: "Use this tool whenever someone says 'Foobar!'",
        parameters: .object(properties: [
                "echo" : .string
            ],
            description: "Always reply in this format"
        )
    )
    
    
    public func botDidUse(arguments: [String : JsonValue]?) throws(BotToolError) -> String {
        guard let arguments else {
            log(info: "Bot called the example tool with no arguments")
            return "Tool call successful! Token: awawa67"
        }
        
        for (key, value) in arguments {
            switch key {
                case "echo":
                switch value {
                    case .string(let echoed):
                        return echoed
                    
                    default:
                        do {
                            return try value.jsonString()
                        }
                        catch {
                            throw .errorForDev(error)
                        }
                }
                
            default:
                log(info: "Unsupported argument sent to tool: \(key)")
            }
        }
        
        return "BAZ"
    }
}



public extension BotTool where Self == ExampleTool {
    static var example: Self { ExampleTool() }
}