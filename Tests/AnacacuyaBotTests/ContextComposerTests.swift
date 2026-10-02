//
//  ContextComposerTests.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude Sonnet 5.5 2026-09-30
//

import Foundation
import Testing

@testable import AnacacuyaBot



@Suite("ContextComposer tests")
struct ContextComposerTests {
    
    private let chat = TGChat(id: 1, type: .private, title: nil, username: "friend", firstName: nil, lastName: nil)
    
    private let history = [
        ChatMessage(
            id: 1,
            sender: TGUser(id: 1, isBot: false, firstName: "Friend", username: "friend"),
            role: .user,
            isReply: false,
            text: "Hello",
        ),
    ]
    
    
    private func composed(for purpose: BotMessagePurpose) async -> [ChatMessage] {
        await setUpBot()
        return await ContextComposer.contextMessages(
            for: purpose,
            in: chat,
            inReplyTo: nil,
            history: history,
            capabilities: [.textCompletion],
        )
    }
    
    
    @Test("The first message is never a system message, so Ollama applies the modelfile's SYSTEM prompt", arguments: [BotMessagePurpose.response, .interjection])
    func firstMessageIsNotSystem(purpose: BotMessagePurpose) async throws {
        let first = try #require(await composed(for: purpose).first)
        #expect(.system != first.role)
    }
    
    
    @Test("The history is followed by exactly the two system messages", arguments: [BotMessagePurpose.response, .interjection])
    func historyThenSystemMessages(purpose: BotMessagePurpose) async {
        let messages = await composed(for: purpose)
        
        #expect(history.count + 2 == messages.count)
        #expect(messages.suffix(2).allSatisfy { .system == $0.role })
    }
}
