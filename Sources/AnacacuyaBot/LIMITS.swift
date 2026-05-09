//
//  BotRunner.swift
//  AnacacuyaBot
//
//  Made by Ky 2026-05-08
//

enum Limits {}



// MARK: - Interaction limits

extension Limits {
    
    // MARK: Autonomous interactions
    
    static let maxAutonomousMessagesPerday = 4
    
    static let minMessagesBeforeAutonomousMessageAllowed = 100
    static let maxMessagesBeforeAutonomousMessageGuaranteed = 400
}



// MARK: - Context limits

extension Limits {
    static let contextWindow_messageCount = 15
}