//
//  DebugShowFullContextCommand.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-12.
//

import Foundation



/// For debugging purposes only: This command sends all the messages in the current context.
///
/// - Attention: This will spam the current chat by sending each message as it was seen by the bot, separately. Only use this if you're actually debigging the bot's context.
struct DebugShowFullContextCommand: BotCommand {
    
    static let name: String = "debug_fullcontext"
    
    static let briefDescription: String = "For debugging purposes only."
    
    static let help: String = """
        This command sends all the messages in the current context.
        ⚠️ This will spam the current chat by sending each message as it was seen by the bot. Only use this if you're actually debugging the bot's context.
        """
    
    
    func run(arguments: [BotCommandArgument], remainingText: String?, context: CommandContext) async throws(CommandRunError) -> [CommandResponse] {
        await context.fullContextMessageHistory(arguments.purpose ?? (nil == context.commandMessage.replyToMessage ? .interjection : .response))
            .map(CommandResponse.message(_:))
    }
}



extension [BotCommandArgument] {
    var purpose: BotMessagePurpose? {
        self
            .first { argument in
                argument.name == "purpose"
            }
            .map(\.value.description)
            .flatMap(BotMessagePurpose.init(rawValue:))
    }
}
