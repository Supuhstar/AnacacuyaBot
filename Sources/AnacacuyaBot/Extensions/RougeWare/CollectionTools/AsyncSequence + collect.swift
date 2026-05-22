//
//  Sequence + collect.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-18.
//

import Foundation



public extension AsyncSequence where Failure == Never {
    
    /// Collects the elements of this async sequence into an array
    ///
    /// - Returns: An array containing the elements of this array
    func collect() async -> [Element] {
        await Array(self)
    }
}



public extension AsyncSequence {
    
    /// Collects the elements of this async sequence into an array
    ///
    /// - Returns: An array containing the elements of this array
    func collect() async throws/*(Failure)*/ -> [Element] { // throws(Failure) crashes the Swift 6.3 compiler
        try await Array(self)
    }
}
