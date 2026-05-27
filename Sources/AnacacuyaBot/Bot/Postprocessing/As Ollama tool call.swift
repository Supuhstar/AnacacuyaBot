//
//  As Ollama tool call.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-26.
//

import Foundation



internal extension Substring {
    
    /// Extracts an Ollama tool call if it's there.
    ///
    /// The model is supposed to call tools in a specific separate field in its output, not in its standard message text, like this:
    /// ```json
    /// {
    ///     "model": "smollm3:latest",
    ///     "message": {
    ///         "role": "assistant",
    ///         "content": "",
    ///         "tool_calls": [
    ///             {
    ///                 "function": {
    ///                     "name": "get_temperature",
    ///                     "arguments": {
    ///                         "city": "Atlanta"
    ///                     }
    ///                 }
    ///             }
    ///         ]
    ///     }
    /// }
    /// ```
    ///
    /// Sometimes, the model will try to call the tool from within its message content, like this:
    /// ```json
    /// {
    ///     "model": "smollm3:latest",
    ///     "message": {
    ///         "role": "assistant",
    ///         "content": "tool\n</tool_call>\n{\"name\": \"get_temperature\", \"arguments\": {\"city\":\"Atlanta\"}}\n</tool_call>",
    ///     }
    /// }
    /// ```
    ///
    /// While this isn't how it's supposed to use its tools, we want to allow this usecase anyway.
    ///
    /// - Note: The example outputs in this documentation are trimmed versions of real outputs, pretty-printed and with extraneous fields removed for demonstration
    ///
    /// - Returns: An Ollama tool call, if one could be extracted from this message content
    func asOllamaToolCall() -> OllamaToolCall? {
        let toolCallRegex = /.*<\/?tool_call>(?<json>.*?)<\/tool_call>.*/.dotMatchesNewlines()
        
        if let match = self.firstMatch(of: toolCallRegex)?.output.json.nonEmptyOrNil {
            let matchString = String(match)
            return (try? OllamaToolCall(function: .init(jsonString: matchString)))
                ?? (try? OllamaToolCall(jsonString: matchString))
        }
        else {
            return try? OllamaToolCall(function: .init(jsonString: String(self)))
        }
    }
}
