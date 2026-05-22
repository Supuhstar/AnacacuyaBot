//
//  TGUpdate.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//



/// One event the bot receives from Telegram's update stream.
///
/// Each call to `getUpdates` returns an array of these. Only one of the optional
/// payload fields is populated per update — the field tells you what kind of
/// event happened. Currently this codebase only decodes `message`; if other
/// event kinds become relevant, add their fields here.
///
/// Source: https://core.telegram.org/bots/api#update
struct TGUpdate: Decodable, Sendable {
    
    /// Monotonically increasing identifier. The bot advances its server-side
    /// cursor by acknowledging updates up through this value, so any new
    /// `getUpdates` call must use `updateId + 1` from the highest seen update
    /// to avoid replay.
    let updateId: Int
    
    /// New incoming message of any kind — text, photo, sticker, etc. Present
    /// for the vast majority of updates this bot cares about.
    let message: TGMessage?
}
