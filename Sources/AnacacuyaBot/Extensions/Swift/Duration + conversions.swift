//
//  Duration + conversions.swift
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
    
    
    /// The number of seconds represented by this `Duration` (floored).
    ///
    /// This property provides direct access to the underlying number of seconds that the current `Duration` represents, ignoring finer precision..
    ///
    ///     let d = Duration.seconds(1.8)
    ///     print(d.seconds) // 1
    @inline(__always)
    var seconds: Int64 {
        components.seconds
    }
}
