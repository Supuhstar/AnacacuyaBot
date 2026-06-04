//
//  NoopCommand.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-06-03.
//

import Foundation




/// A command which does nothing
struct NoopCommand: BotCommand {
    
    static let name = "noop"
    
    static let briefDescription = "Do nothing. Useful for other bots which have trouble not responding to this one."
    
    static let help: String? = nil
    
    
    func run(arguments _: [BotCommandArgument], remainingText _: String?, context: CommandContext) async throws(CommandRunError) -> [CommandResponse] {
        return []
    }
}
