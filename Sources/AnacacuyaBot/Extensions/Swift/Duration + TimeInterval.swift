//
//  Duration + TimeInterval.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-09.
//

import Foundation



let attosecondsPerSecond: TimeInterval = 1e18



extension Duration {
    /// The time interval (seconds) that this duration represents
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        
        return TimeInterval(seconds)
            + (TimeInterval(attoseconds) / attosecondsPerSecond)
    }
}
