//
//  Duration + more time units.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-09.
//

import Foundation



public extension Duration {
    
    @inline(__always)
    static func minutes(_ minutes: Double) -> Duration {
        .seconds(minutes * 60)
    }
    
    
    @inline(__always)
    static func hours(_ hours: Double) -> Duration {
        .minutes(hours * 60)
    }
}
