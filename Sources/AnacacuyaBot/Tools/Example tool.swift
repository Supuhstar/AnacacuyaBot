//
//  ExampleTool.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-22.
//

import Foundation

import SimpleLogging



public extension BotTool {
    
    /// A tool that an LLM can use
    static var example: Self {
        Self.init(
            definition: .init(
                name: "example",
                description: "Use this tool whenever someone says 'Foobar!'",
                parameters: .object(
                    properties: [
                        "echo" : .string
                    ],
                    description: "Always reply in this format"
                )
            ),
            
            
            botDidUse: { arguments throws(BotToolError) in
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
                        continue
                    }
                }
                
                
                for (key, value) in arguments {
                    log(warning: "Unsupported argument sent to tool: \"\(key)\": \(value)")
                }
                
                return "BAZ"
            },
        )
    }
}
