//
//  Regex sugar.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-14.
//

import Foundation



public extension String {
    
    /// True iff this string matches the given regex
    ///
    /// - Parameter regex: The regex to check against
    func matches<R: RegexComponent>(_ regex: R) -> Bool {
        self.matches(of: regex).count > 0
    }
}
