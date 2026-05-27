//
//  postprocessing.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//

import Foundation



public extension OllamaChatResponse {
    
    /// Runs postprocessing on this bot response to make it good enough to send to the user
    ///
    /// - Parameter persona: The persona that the bot responded as
    ///
    /// - Returns: The bot's response, postprocessed to remove unwanted artifacts
    @MainActor
    func postprocessed(as persona: Persona) -> Self {
        var copy = self
        copy.message = message.postprocessed(as: persona)
        return copy
    }
}



public extension OllamaMessage {
    
    /// Runs postprocessing on this bot message to make it good enough to send to the user
    ///
    /// - Parameter persona: The persona that the bot responded as
    ///
    /// - Returns: The bot's message, postprocessed to remove unwanted artifacts
    @MainActor
    func postprocessed(as persona: Persona) -> Self {
        var copy = self
        
        switch content.postprocessed(as: persona) {
        case .string(let content):
            copy.content = content
            
        case .toolCall(let ollamaToolCall):
            copy.toolCalls = (copy.toolCalls ?? []) + [ollamaToolCall]
        }
        
        return copy
    }
}



public extension String {
    
    /// Runs postprocessing on this bot message to make it good enough to send to the user
    ///
    /// - Parameter persona: The persona that the bot responded as
    ///
    /// - Returns: The bot's message, postprocessed to remove unwanted artifacts
    @MainActor
    func postprocessed(as persona: Persona) -> PostprocessedString {
        self[...]
            .postprocessed(as: persona)
    }
}



public extension Substring {
    
    /// Runs postprocessing on this bot message to make it good enough to send to the user
    ///
    /// - Parameter persona: The persona that the bot responded as
    ///
    /// - Returns: The bot's message, postprocessed to remove unwanted artifacts
    @MainActor
    func postprocessed(as persona: Persona) -> PostprocessedString {
        if let toolCall = self.asOllamaToolCall() {
            .toolCall(toolCall)
        }
        else {
            .string(self
                .removingSelfIntroduction(personaName: persona.name)
                .removingFakeChatLogs()
                .removingWholeMessageQuotes()
                .removingFilenameTag()
                .removingSelfIntroduction(personaName: persona.name)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}



public enum PostprocessedString: Sendable, Equatable {
    case string(String)
    case toolCall(OllamaToolCall)
}



public extension PostprocessedString {
    static func == <LHS: StringProtocol> (lhs: LHS, rhs: Self) -> Bool {
        switch rhs {
        case .string(let string):
            lhs.description == string
            
        case .toolCall(_):
            false
        }
    }
    
    
    static func == <RHS: StringProtocol> (lhs: Self, rhs: RHS) -> Bool {
        rhs == lhs
    }
}



public extension PostprocessedString {
    static func == (lhs: OllamaToolCall, rhs: Self) -> Bool {
        switch rhs {
        case .string(_):
            false
            
        case .toolCall(let ollamaToolCall):
            lhs == ollamaToolCall
        }
    }
    
    
    static func == (lhs: Self, rhs: OllamaToolCall) -> Bool {
        rhs == lhs
    }
}



internal extension Substring {
    
    /// Isolates part of this substring by matching against the given regex, only keeping the given capture
    ///
    /// - Parameters:
    ///   - regex:       A regex which can isolate part of this substring
    ///   - keptCapture: The captured substring to keep
    ///
    /// - Returns: The substring captured by `keptCapture`
    func isolate<R: RegexComponent>(by regex: R, keeping keptCapture: KeyPath<R.RegexOutput, Substring>) -> Substring {
        if let match = self.firstMatch(of: regex) {
            return match.output[keyPath: keptCapture]
        }
        else {
            return self
        }
    }
    
    /// Isolates part of this substring by matching against the given regex, only keeping the given capture
    ///
    /// - Parameters:
    ///   - regex:       A regex which can isolate part of this substring
    ///   - keptCapture: The captured substring to keep
    ///
    /// - Returns: The substring captured by `keptCapture`. If `keepCapture` ends up with a `nil` output, this returns an empty string
    func isolate<R: RegexComponent>(by regex: R, keeping keptCapture: KeyPath<R.RegexOutput, Substring?>) -> Substring {
        if let match = self.firstMatch(of: regex) {
            return match.output[keyPath: keptCapture] ?? ""
        }
        else {
            return self
        }
    }
}
