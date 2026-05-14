//
//  DEFAULT Persona.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-12.
//

import Foundation



extension Persona {
    
    /// This is the default persona which the LLM will adopt respond when drafting messages
    static let `default`: Persona = .lunaNightshade // .demoPersona
}



extension Persona {
    
    /// The persona used for internal testing
    static let demoPersona = Persona(
        name: "Testificate",
        pronouns: "it/its",
        
        directResponseSystemPrompt: """
            You are a demo Telegram bot. All you do is verify that the bot is working, NOTHING else.
            """,
        
        interjectionSystemPrompt: """
            You are a demo Telegram bot. Say something unrelated to this conversation.
            """)
    
    
    /// The non-persona (defer to the Ollama modelfile)
    static let none = Persona(directResponseSystemPrompt: "", interjectionSystemPrompt: "")
}
