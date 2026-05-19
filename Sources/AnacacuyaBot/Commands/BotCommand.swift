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
    static func matches(_ wholeUserText: String, as botUser: TGUser) -> Bool
    
    
    /// Run this command, with the given user input
    /// 
    /// - Parameter arguments:     Arguments that the user sent with this command message
    /// - Parameter remainingText: The text part of the command message _after_ the arguments
    /// - Parameter context:       Important context you might need to know when running this command
    ///
    /// - Returns: What to respond to the user with, or empty if no response is necessary
    func run(
        arguments: [BotCommandArgument],
        remainingText: String?,
        context: CommandContext,
    ) async throws(CommandRunError) -> [CommandResponse]
}



extension BotCommand {
    
    static var alternativeNames: [String] { [] }
    
    static var help: String? { nil }
    
    /// All the names that this command could use: its canonical name and all synonyms
    static var allNames: [String] { [name] + alternativeNames }
    
    
    /// Returns `true` iff the given whole user text is a valid representation of this command to this bot
    ///
    /// - Parameters:
    ///   - wholeUserText: The entire, unmodified, non-empty message from the user
    ///   - botUser:       This bot's Telegram user account
    static func matches(_ wholeUserText: String, as botUser: TGUser) -> Bool {
        nil != parsing(wholeUserText, as: botUser)
    }
    
    
    /// Parses the raw text of the command into something easier for us to use
    ///
    /// - Parameters:
    ///   - wholeUserText: The entire text of the message the user sent, without modification
    ///   - botUser:       This bot's Telegram user account
    ///
    /// - Returns: The parsed command, iff parsing was successful
    static func parsing(_ wholeUserText: String, as botUser: TGUser) -> ParsedBotCommand? {
        guard let parsed = ParsedBotCommand(wholeUserText),
              allNames.contains(parsed.name)
        else {
            return nil
        }
        
        if let botHandle = parsed.taggedBotUser {
            guard botUser.username == botHandle else {
                return nil
            }
        }
        
        return parsed
    }
}



/// Defines the structure of a bot command
struct ParsedBotCommand {
    
    /// The command name. In `/remind in:2w Work on motorcycle`, this would be `"remind"`
    let name: String
    
    /// The user that was tagged in the command. In `/prompt@Anacacuyabot`, this would be `"AnacacuyaBot".
    let taggedBotUser: String?
    
    /// The body of the command. In `/remind in:2w Work on motorcycle`, this would be `(arguments: (name: "in", value: "2w"), arbitraryUserText: "Work on motorcylce")`.
    ///
    /// Examples:
    /// - `/remind in:2w Work on motorcycle` ➡️ `(arguments: [(name: "in", value: "2w")], arbitraryUserText: "Work on motorcylce")`
    /// - `/debug_fullcontext purpose:interjection` ➡️ `(arguments: [(name: "purpose", value: "interjection"], arbitraryUserText: nil)`
    /// - `/ban @KyNorthstar being weird` ➡️ `(arguments: [], arbitraryUserText: "@KyNorthstar being weird")`
    /// - `/help` ➡️ `(arguments: [], arbitraryUserText: nil)`
    let body: Body
    
    
    
    /// The body of a command, splitting it semantically for easier machine-reading
    typealias Body = (arguments: [BotCommandArgument], arbitraryUserText: Substring?)
}



extension ParsedBotCommand {
    
    /// Attempts to build a command structure from the given raw user input.
    ///
    /// If the given text cannot be parsed into a command, this results in `nil`.
    ///
    /// Valid commands are structured like `/commandName@UsernameOfBot argument1:value1 argument2:value2 arbitrary remaining text`.
    ///
    /// - Parameter messageText: The whole message the user sent, unmodified
    init?(_ messageText: String) {
        let messageText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        // /<name>[@<taggedBotUser>][ <tail>]
        let commandRegex = /^\/(?<name>\w+?)(?:@(?<taggedBotUser>\w+))?(?:\s+(?<tail>.+?))?\s*$/
        
        guard let match = messageText.wholeMatch(of: commandRegex) else {
            return nil
        }
        
        self.name = String(match.name)
        self.taggedBotUser = match.taggedBotUser.map(String.init)
        self.body = match.tail.map(Self.parseBody) ?? ([], nil)
    }
    
    
    
    /// Parses the body of a command. In `/remind@ReminderBot in:4h Feed the cat`, this is `"in:4h Feed the cat"`
    /// - Parameter body: The unparsed body section of the command
    /// - Returns: The parsed body. This always succeeds, but misformatted commands might see would-be arguments in the arbitrary text section
    private static func parseBody(
        _ body: Substring
    ) -> Body {
        // Greedy \S+ on value so things like `temperature:0.8` and `time:12:30` work.
        let argRegex = /(?<name>\w+):(?<value>\S+)(?:\s+|$)/
        var remainder = body
        var arguments: [BotCommandArgument] = []
        
        while let match = remainder.prefixMatch(of: argRegex) {
            arguments.append(BotCommandArgument(name: match.name, value: match.value))
            remainder = remainder[match.range.upperBound...]
        }
        
        return (arguments: arguments,
                arbitraryUserText: remainder.nonEmptyOrNil?.trimmingCharacters(in: .whitespacesAndNewlines)[...]) //[...]: This converts the string into a substring, which is what the `Body` return type expects.
    }
}



/// An argument passed to a command, like `temperature:0.8` in `/setParameter temperature:0.8`
public struct BotCommandArgument: Equatable, Hashable {
    
    /// The name of the argument. In `temperature:0.8`, this is `"temperature"`
    let name: Substring
    
    /// The name of the argument. In `temperature:0.8`, this is `"0.8"`
    let value: Substring
}



/// Meta-info for a bot to best understand what to do when given a command
public struct CommandContext: Sendable {
    
    /// The bot's persona which was loaded when this command was run.
    let persona: Persona
    
    /// The full original message the user sent when running this command, as fetched from the Telegram API
    let commandMessage: TGMessage
    
    /// The user that represents the bot, as fetched from the Telegram API
    let botUser: TGUser
    
    /// Composes all the messages the bot saw when collecting context for its response
    let fullContextMessageHistory: @Sendable (BotMessagePurpose) async -> [ChatMessage]
    
    /// The current capabilities that the bot has
    let capabilities: Set<ModelCapability>
}



/// A bot's response to a command
public enum CommandResponse {
    
    /// Send a normal message
    case message(ChatMessage)
}



public enum CommandRunError: Error {
    case invalidInput(recoverySuggestion: String)
}
