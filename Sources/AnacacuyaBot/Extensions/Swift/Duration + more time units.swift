//
//  Duration + more time units.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-09.
//



public extension Duration {
    
    /// Construct a `Duration` given a number of minutes represented as a `Double` by converting the value into the closest attosecond scale value.
    ///
    ///       let d: Duration = .minutes(42.67)
    ///
    /// - Returns: A `Duration` representing the given number of minutes.
    @inline(__always)
    static func minutes(_ minutes: Double) -> Duration {
        .seconds(minutes * 60)
    }
    
    
    /// Construct a `Duration` given a number of minutes represented as a `Double` by converting the value into the closest attosecond scale value.
    ///
    ///       let d: Duration = .minutes(42.67)
    ///
    /// - Returns: A `Duration` representing the given number of minutes.
    @inline(__always)
    static func hours(_ hours: Double) -> Duration {
        .minutes(hours * 60)
    }
}
