//
//  TGPhotoToSend.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-26.
//

import Foundation



/// What to send as the photo in ``sendPhoto(chatId:photo:caption:inReplyTo:)``.
public enum TGPhotoToSend: Sendable {
    
    /// Raw image bytes to upload. `filename` is what Telegram records;
    /// its extension should match the actual format.
    case bytes(Data, filename: String)
    
    /// A `file_id` of a photo already on Telegram's servers, or a public
    /// HTTPS URL Telegram can fetch. Sent as a plain string — no upload.
    case reference(String)
}
