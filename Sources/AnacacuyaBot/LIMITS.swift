//
//  BotRunner.swift
//  AnacacuyaBot
//
//  Made by Ky 2026-05-08
//

enum Limits {}



// MARK: - Interaction limits

extension Limits {
    
    // MARK: Total interactions
    
    static let maxTotalMessagesSentPerDay = 200
    
    
    // MARK: Autonomous interactions
    
    static let maxAutonomousMessagesPerDay = 4
    
    static let minMessagesBeforeAutonomousMessageAllowed = 8
    static let maxMessagesBeforeAutonomousMessageGuaranteed = 100
    
    
    // MARK: Temporal limits
    
    static let oldestMessageToRespondTo: Duration = .hours(0.5)
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
