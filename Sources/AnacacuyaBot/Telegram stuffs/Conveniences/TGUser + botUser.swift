//
//  TGUser + botUser.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-21.
//

import Foundation



public extension TGUser {
    
    /// The Telegram user that this bot is communicating through.
    ///
    /// This starts out as a placeholder and is soon replaced with the actual value.
    @MainActor static var botUser = TGUser(id: -1, isBot: true, firstName: "Loading...", username: "Loading")
}
