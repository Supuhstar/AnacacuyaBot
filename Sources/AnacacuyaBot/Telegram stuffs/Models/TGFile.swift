//
//  TGFile.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//



/// A handle returned by Telegram's `getFile` method that lets the bot retrieve
/// the actual bytes of a file the user uploaded.
///
/// Telegram splits "I want this file" into a two-step dance: first call
/// `getFile` to receive this object, then GET
/// `https://api.telegram.org/file/bot<token>/<filePath>` to fetch the bytes.
/// The split exists because download links are time-limited and the server
/// needs to prepare the file before serving it. Per Telegram's documentation,
/// the link is guaranteed valid for at least 1 hour; after that the request
/// must be re-issued.
///
/// Source: https://core.telegram.org/bots/api#file
public struct TGFile: Decodable, Sendable {
    
    /// Identifier for this file, which can be used to download or reuse the file.
    let fileId: String
    
    /// Unique identifier for this file, which is supposed to be the same over
    /// time and for different bots. Can't be used to download or reuse the file.
    let fileUniqueId: String
    
    /// File size in bytes. Telegram omits this when the size isn't known
    /// server-side; nil is "unknown", not "zero".
    let fileSize: Int?
    
    /// Path component for the file download URL. Combine with the file base URL
    /// as `https://api.telegram.org/file/bot<token>/<filePath>`. Nil when the
    /// file is known to Telegram but not currently retrievable — re-call
    /// `getFile` to refresh.
    let filePath: String?
}
