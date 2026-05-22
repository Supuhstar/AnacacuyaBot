//
//  BotTool.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-22.
//

import Foundation



/// A tool that an LLM can use
public protocol BotTool: Sendable {
    
    /// The technical description of the tool which will be sent to Ollama
    static var function: OllamaTool.Function { get }
    
    
    /// This function is called when the bot has decided to use this tool
    /// 
    /// - Parameters:
    ///   - arguments: The arguments the bot sends to this tool
    /// 
    /// - String:
    func botDidUse(arguments: [String : JsonValue]?) async throws(BotToolError) -> String
}



/// An error that can be thrown from a bot tool running
public enum BotToolError: Error {
    
    /// An error occurred that should be described to the bot
    case errorForBot(problemDescription: String)
    
    /// An error occurred that only the dev should know about (it'll remain secret to the dev)
    case errorForDev(Error)
}



// MARK: - Conversion

public extension OllamaTool {
    
    /// Create an Ollama tool spec based on the given bot tool
    init<Other: BotTool>(_ : Other) {
        self.init(function: Other.function)
    }
}