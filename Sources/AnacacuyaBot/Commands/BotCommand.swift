//
//  BotCommand.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-08.
//

import Foundation
import RegexBuilder



/// A command that a user can send to a bot, like `/start` or `/help`
public protocol BotCommand: Sendable {
    
    /// The name of the command.
    ///
    /// This is what the user types as the first word of their command message. For example, the command `/remind 1w Do the laundry`, this would be `"remind"`
    static var name: String { get }
    
    /// Synonyms for this command.
    ///
    /// These are alternative names that a user might reasonably expect for this command. For example, a `/remind` command might also accept `/reminder` or `/setReminder`, so this array would be `["reminder", "setReminder"]`
    ///
    /// This can be an empty array if there aren't any reasonable synonyms.
    static var alternativeNames: [String] { get }
    
    /// When the bot lists its commands, this is the little blurb which introduces this command to the user. Only a few words.
    ///
    /// For example, for a command which flips an image upside down
    static var briefDescription: String { get }
    
    /// As much text as you want, to tell the user about this command.
    ///
    /// This will appear when the user wants detailed info about this command, like `/help myCommand`
    static var help: String? { get }
    
    
    /// `true` iff the given message is one which wants this command to be run
    static func matches(_ messageText: String) -> Bool
    
    
    /// Run this command, with the given user input
    ///
    /// - Parameter userInput: The text from the user, if the user supplied any. This _never_ includes the /command itself
    /// - Returns: What to respond to the user with, or empty if no response is necessary
    func run(with userInput: String?, context: CommandContext) async throws(CommandRunError) -> [CommandResponse]
}



extension BotCommand {
    
    static var alternativeNames: [String] { [] }
    
    static var help: String? { nil }
    
    
    static func matches(_ messageText: String) -> Bool {
        let escapedNames = ([name] + alternativeNames)
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        
        guard let names = try? Regex(escapedNames) else {
            let pattern = Regex {
                "/"
                name
                Anchor.wordBoundary
            }
            
            return nil != messageText.prefixMatch(of: pattern)
        }
        
        let pattern = Regex {
            "/"
            names
            Anchor.wordBoundary
        }
        return nil != messageText.prefixMatch(of: pattern)
    }
}



/// Meta-info for a bot to best understand what to do when given a command
public struct CommandContext {
    let persona: Persona
    let commandMessage: TGMessage
    let botUser: TGUser
}



/// A bot's response to a command
public enum CommandResponse {
    
    /// Just some text
    case text(String)
}



public enum CommandRunError: Error {
    case invalidInput(recoverySuggestion: String)
}
