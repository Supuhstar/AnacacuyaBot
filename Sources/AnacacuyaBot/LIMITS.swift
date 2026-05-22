//
//  BotRunner.swift
//  AnacacuyaBot
//
//  Made by Ky 2026-05-08
//

import Foundation



enum Limits {}



// MARK: - Agentic limits

extension Limits {
    
    /// How many times should the bot be allowed to use a tool as the result of using another tool?
    static let maxSelfInteractions = 3
}



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



// MARK: - Media limits

extension Limits {
    
    /// Maximum amount of data for a single photo download.
    ///
    /// Telegram delivers every photo in multiple resolutions and the bot picks one.
    /// This cap keeps the largest downloaded rendition modest enough that the user doesn't wait much (and the host machine doesn't get DOS'd), while still being big enough for OCR to work reliably on typical chat content.
    ///
    /// The hard ceiling from Telegram's standard Bot API is 20MB; this value sits well below that to keep latency predictable.
    static let maxTelegramFileDownloadSize = Measurement<UnitInformationStorage>(value: 2, unit: .megabytes)
}
