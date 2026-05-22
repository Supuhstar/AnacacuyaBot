//
//  PromptCommand.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-08.
//

import Foundation



private let exampleContext = #"<UP TO \#(Limits.contextWindow_messageCount) CHAT MESSAGES HERE>"#



/// A command which only sends the current system prompts to the current chat
struct PromptCommand: BotCommand {
    
    static let name = "prompt"
    
    static let briefDescription = "Send just the current system prompts"
    
    static let help: String? = nil
    
    
    func run(arguments _: [BotCommandArgument], remainingText _: String?, context: CommandContext) async throws(CommandRunError) -> [CommandResponse] {
        
        func systemPrompt(for purpose: BotMessagePurpose, in chatType: TGChatType) async -> String {
            let (earlier, later, tail) = await context.persona
                .systemPromptStrings(
                    for: purpose,
                    in: .anyChat(type: chatType),
                    inReplyTo: .init(context.commandMessage),
                    capabilities: context.capabilities.subtracting([.textCompletion]),
                )
            
            return """
                \(earlier)
                
                ---<`Context messages would go here`>---
                
                \(later)
                
                \(tail)
                """
        }
        
        return [
            .message(.system(text: """
                __*When interjecting in a group:*__
                \(await systemPrompt(for: .interjection, in: .group))
                """)),
            
                .message(.system(text: """
                __*When replying in a group:*__
                \(await systemPrompt(for: .response, in: .group))
                """)),
            
                .message(.system(text: """
                __*When replying in DMs:*__
                \(await systemPrompt(for: .response, in: .private))
                """)),
        ]
    }
}



private extension TGChat {
    static func anyChat(type: TGChatType) -> TGChat {
        .init(
            id: 0,
            type: type,
            title: .private == type ? nil : "<CHAT NAME>",
            username: .private == type ? "<USERNAME>" : nil,
            firstName: .private == type ? "<FIRST NAME>" : nil,
            lastName: .private == type ? "<LAST NAME>" : nil
        )
    }
}
