//
//  TGResponse.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//



/// The standard envelope Telegram wraps around every API response.
///
/// Every successful call returns `{"ok": true, "result": ...}`; every failed
/// call returns `{"ok": false, "error_code": ..., "description": ...}`.
/// Threading every response through this one type means error checking and
/// payload extraction live in one place — `TelegramClient`'s helpers — rather
/// than scattered across each method's call site.
///
/// `Result` is generic so each call can describe its specific payload shape
/// while sharing this envelope. For methods that return no meaningful payload,
/// `Bool` is the conventional choice (Telegram returns `"result": true`).
///
/// Source: https://core.telegram.org/bots/api#making-requests
struct TGResponse<Result: Decodable & Sendable>: Decodable, Sendable {
    
    /// `true` when the call succeeded. The other fields' presence is determined
    /// by this — `result` on success, `description` and `errorCode` on failure.
    let ok: Bool
    
    /// The payload returned by the method. Present on success, absent on failure.
    let result: Result?
    
    /// Human-readable error message, when the call failed.
    let description: String?
    
    /// Integer error code, when the call failed. Subject to change per
    /// Telegram's documentation; useful for logging but not for branching.
    let errorCode: Int?
}
