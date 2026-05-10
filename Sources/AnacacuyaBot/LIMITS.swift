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
    
    static let maxAutonomousMessagesPerDay = 4
    
    static let minMessagesBeforeAutonomousMessageAllowed = 25
    static let maxMessagesBeforeAutonomousMessageGuaranteed = 200
}



// MARK: - Context limits

extension Limits {
    static let contextWindow_messageCount = 15
}



// MARK: - Networking limits

extension Limits {
    static let maxTimeToWaitForModelResponse: Duration = .seconds(120)
    static let maxTimeToWaitForNewTelegramMessages: Duration = .seconds(30)
}
