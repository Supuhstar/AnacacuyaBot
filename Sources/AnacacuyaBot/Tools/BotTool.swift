//
//  BotTool.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-22.
//

import Foundation



/// A tool that an LLM can use
@dynamicMemberLookup
public struct BotTool: Sendable {
    
    /// The technical description of the tool which will be sent to Ollama
    public let definition: Definition
    
    
    /// Determines whether this tool matches a tool call
    public let matches: Matches
    
    /// If this tool requires any specific capabilities from the LLM (e.g. it must be able to see images), list them here
    public let requiredCapabilities: [ModelCapability]?
    
    
    /// This function is called when the bot has decided to use this tool
    /// 
    /// - Parameters:
    ///   - arguments: The arguments the bot sends to this tool
    public let botDidUse: BotDidUse
    
    
    init(definition: OllamaTool.Function,
         matches: Matches? = nil,
         requiredCapabilities: [ModelCapability]? = nil,
         botDidUse: @escaping BotDidUse)
    {
        self.definition = definition
        self.requiredCapabilities = requiredCapabilities
        self.botDidUse = botDidUse
        
        self.matches = matches ?? { toolCall in
            toolCall.function.name.localizedCaseInsensitiveCompare(definition.name) == .orderedSame
        }
    }
    
    
    /// Pass through all function members
    public subscript <T>(dynamicMember keyPath: KeyPath<OllamaTool.Function, T>) -> T {
        definition[keyPath: keyPath]
    }
    
    
    
    /// Defines how an LLM sees a tool
    public typealias Definition = OllamaTool.Function
    
    /// A function that's called when the bot uses a tool
    public typealias BotDidUse = @Sendable (_ arguments: [String : JsonValue]?) async throws(BotToolError) -> Result
    
    /// Determines whether a tool matches the LLM's attempt to call a tool
    public typealias Matches = @Sendable (_ toolCall: OllamaToolCall) -> Bool
}



public extension BotTool {
    
    /// Run this tool by the given call
    ///
    /// - Parameter call: The bot's calling of the tool
    ///
    /// - Returns: The result of calling the tool
    func run(_ call: OllamaToolCall) async throws(BotToolError) -> Result {
        try await botDidUse(call.function.arguments)
    }
    
    
    
    /// The result of a bot tool call
    struct Result: Sendable {
        
        /// The text result of calling the tool
        let text: String
        
        /// Any images the tool produced
        let images: [Data]?
        
        
        static func text(_ text: String) -> Self { .init(text: text, images: nil) }
        static func image(_ image: Data) -> Self { .init(text: "", images: [image]) }
        static func images(_ image: [Data]) -> Self { .init(text: "", images: image) }
    }
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
    init(_ botTool: BotTool) {
        self.init(function: botTool.definition)
    }
}
