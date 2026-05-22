//
//  Whole-message quote removal.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-18.
//

import Foundation



public extension Substring {
    
    /// Removes quotation marks from the start and end of the message.
    ///
    /// Sometimes, smollm will put quotation marks at the start and end of the message, presenting the whole message as a quote.
    /// This removes those, presenting the message as its own words.
    ///
    /// - Returns: The message, without quotes around it. If no quotes are detected, this returns the whole input unchanged.
    func removingWholeMessageQuotes() -> Substring {
        isolate(by: /^"(?<keep>.+)"$/, keeping: \.keep)
    }
}
