//
//  CREATOR_USERNAME.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



extension UnixEnvironmentKey where Value == String, Backup == Never {
    
    /// Your Telegram username, so the bot knows whether it's talking to its creator, like `"KyNorthstar"`
    static let creatorUsername: Self = "CREATOR_USERNAME"
}
