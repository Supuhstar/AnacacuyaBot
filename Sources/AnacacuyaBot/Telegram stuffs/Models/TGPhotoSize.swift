//
//  TGPhotoSize.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//

import Foundation



/// One available rendition of a photo sent through Telegram.
///
/// Telegram pre-renders every photo at multiple resolutions and delivers all of
/// them in a single message, so clients can pick the size that fits their
/// bandwidth and display needs. For a bot doing vision work, the relevant choice
/// is between download speed and image fidelity — see ``Array/largest(under:)``
/// for the policy this codebase applies.
struct TGPhotoSize: Decodable, Sendable {
    
    /// Identifier for this file, which can be used to download or reuse the file.
    let fileId: String
    
    /// Unique identifier for this file, which is supposed to be the same over
    /// time and for different bots. Can't be used to download or reuse the file.
    let fileUniqueId: String
    
    /// Photo width.
    let width: Int
    
    /// Photo height.
    let height: Int
    
    /// File size in bytes. Telegram omits this when the size isn't known
    /// server-side; nil is "unknown", not "zero".
    let fileSize: Int?
}



extension TGPhotoSize: Identifiable {
    
    /// Identity tracks `fileUniqueId` because it's the only field Telegram
    /// guarantees stable across bots and over time. `fileId` rotates and
    /// shouldn't be relied on for equality.
    var id: String { fileUniqueId }
}



extension Array where Element == TGPhotoSize {
    
    /// Picks the highest-fidelity rendition that fits within the given size
    /// budget, falling back to the largest by pixel count if no rendition
    /// reports its bytes.
    ///
    /// Two layered considerations drive this policy. First, vision models like
    /// moondream resize internally regardless of input dimensions, so download
    /// time dominates over model performance — and download time scales with
    /// byte count, not pixel count. Capping by bytes is the right axis. Second,
    /// Telegram sometimes returns `fileSize` as nil for one or more renditions;
    /// when that happens, pixel count is the best signal we have left, and
    /// "largest by area" gives the OCR-friendly choice.
    ///
    /// - Parameter limit: The byte ceiling. Renditions reporting a size at or
    ///                    below this value are eligible.
    ///
    /// - Returns: The chosen rendition, or `nil` only if the array is empty.
    func largest(under limit: Measurement<UnitInformationStorage>) -> TGPhotoSize? {
        let limitBytes = Int(limit.converted(to: .bytes).value)
        
        let eligible = self.filter { photo in
            guard let size = photo.fileSize else { return false }
            return size <= limitBytes
        }
        
        if let best = eligible.max(by: { ($0.fileSize ?? 0) < ($1.fileSize ?? 0) }) {
            return best
        }
        
        return self.max(by: { ($0.width * $0.height) < ($1.width * $1.height) })
    }
}
