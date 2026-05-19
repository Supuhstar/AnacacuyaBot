//
//  OllamaTool.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



/// A callable function the model is permitted to invoke during a chat completion.
///
/// Ollama mirrors OpenAI's tool format: an object with a `type` field (currently only `function`), and a `function` field which wraps the function's name, description, and parameter schema.
///
/// - Note: The model can decide whether & when to call this tool. All we do is describe what's available to it, and what shape the tool's arguments take
public struct OllamaTool: OllamaRequest {
    let type: Kind
    let function: Function
}



extension OllamaTool {
    
    /// The kind of tool being declared.
    ///
    /// Currently Ollama only supports one tool kind: `function`.
    enum Kind: String, OllamaRequest {
        case function
    }
    
    
    
    /// A function that a LLM can use as a tool.
    struct Function: OllamaRequest {
        /// An arbitrary name for this tool . Keep it short, like `"search"` or `"get_current_weather"`.
        let name: String
        
        /// A longer-form plaintext description of this tool, like `"Perform a web search"` or `"Get the current weather for a location"`.
        let description: String
        
        /// An object schema describing the whole shape of the function's parameters.
        ///
        /// This is just one `.object(...)`.
        ///
        /// Top level keys are the names of the parameters, associated with their expected inputs.
        let parameters: JsonSchema
    }
}
