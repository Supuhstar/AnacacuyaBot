//
//  BotRunner.swift
//  AnacacuyaBot
//
//  Made by Ky 2026-05-08
//

import Foundation



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



// MARK: - Media limits

extension Limits {
    
    /// Soft ceiling for photo downloads.
    ///
    /// Telegram delivers every photo in multiple resolutions and the bot picks
    /// one. The vision model resizes internally regardless of input size, so
    /// the bottleneck on quality isn't pixel count — it's how long the byte
    /// transfer takes. This cap keeps the largest downloaded rendition modest
    /// enough that the user doesn't wait noticeably while still being big
    /// enough for OCR to work reliably on typical chat content.
    ///
    /// When no rendition reports a size at or below this value, the picker
    /// falls back to the largest by pixel count regardless — see
    /// ``Array/largest(under:)``.
    ///
    /// The hard ceiling from Telegram's standard Bot API is 20MB; this value
    /// sits well below that to keep latency predictable.
    static let preferredMaxPhotoSize = Measurement<UnitInformationStorage>(value: 2, unit: .megabytes)
}
