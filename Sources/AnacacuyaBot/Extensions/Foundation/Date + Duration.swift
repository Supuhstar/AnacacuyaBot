//
//  Date + Duration.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-15.
//

import Foundation



public extension Date {
    
    /// Determines whether this date occurs after `duration` ago
    ///
    /// - Parameter duration: How far into the past this date can be before this returns `false`
    /// - Returns: `true` iff this date occurs after `duration` ago
    func isSooner(than duration: Duration) -> Bool {
        self.addingTimeInterval(duration.timeInterval) > .now
    }
}
