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
                name: "get_temperature",
                description: "Get the current temperature for a city",
                parameters: .object(
                    properties: [
                        "city" : .string(description: "The name of the city")
                    ],
                )
            ),
            
            
            botDidUse: { arguments throws(BotToolError) in
                guard let arguments else {
                    log(info: "Bot called the example tool with no arguments")
                    return "67"
                }
                
                for (key, value) in arguments {
                    switch key {
                    case "city":
                        switch value {
                        case .string(let city):
                            return "\(city.fakeTemperature_formatted)ºF"
                            
                        default:
                            do {
                                return "\(try value.jsonString().fakeTemperature_formatted)ºC"
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
                
                return "0ºK"
            },
        )
    }
}



private extension String {
    var fakeTemperature: Int {
        self.lazy
            .flatMap(\.unicodeScalars)
            .map(\.value)
            .map(Int.init)
            .reduce(into: 0, +=)
    }
    
    
    var fakeTemperature_formatted: String {
        (CGFloat(fakeTemperature) / 30).native.formatted(.number.precision(.fractionLength(1)))
    }
}
