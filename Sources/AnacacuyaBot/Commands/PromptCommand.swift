//
//  PromptCommand.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-08.
//

import Foundation



private let exampleContext = #"<UP TO \#(Limits.contextWindow_messageCount) CHAT MESSAGES HERE>"#



struct PromptCommand: BotCommand {
    static let name = "prompt"
    
    static let briefDescription = "Send just the current system prompt"
    
    static let help: String? = nil
    
    
    func run(with userInput: String?, context: CommandContext) async throws(CommandRunError) -> [CommandResponse] {
        
        func systemPrompt(for purpose: BotMessagePurpose, in chatType: TGChatType) -> String {
            context.persona
                .systemPrompt(for: purpose, in: .anyChat(type: chatType), context: exampleContext)
                .joined(separator: "\n")
        }
        
        return [
            .text("""
                *When interjecting in a group*
                \(systemPrompt(for: .interjection, in: .group))
                """),
            
            .text("""
                *When replying in a group:*
                \(systemPrompt(for: .response, in: .group))
                """),
            
            .text("""
                *When replying in DMs:*
                \(systemPrompt(for: .response, in: .private))
                """),
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
