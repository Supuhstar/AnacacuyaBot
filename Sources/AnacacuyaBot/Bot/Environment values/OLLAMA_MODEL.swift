//
//  OLLAMA_MODEL.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



extension UnixEnvironmentKey where Value == String?, Backup == String {
    
    /// The name of the LLM model that the bot uses, like `"smollm2"`
    static let llmName = Self("OLLAMA_MODEL", backup: "smollm2")
}
