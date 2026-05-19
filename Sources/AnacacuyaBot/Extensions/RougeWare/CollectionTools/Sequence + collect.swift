//
//  Sequence + collect.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-18.
//

import Foundation



public extension Sequence {
    
    /// Collects the elements of this sequence into an array
    ///
    /// - Returns: An array containing the elements of this array
    func collect() -> [Element] {
        Array(self)
    }
}



public extension Array {
    
    /// Returns this instance unchanged.
    ///
    /// This exists in case callsites call `.collect()` on an array, to avoid unnecessary operations.
    /// For all other sequence types, this would convert them to an array and return that array.
    ///
    /// - Returns: `self`
    @inline(__always)
    func collect() -> [Element] {
        self
    }
}
