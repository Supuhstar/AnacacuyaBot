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
    /// - Returns: <#description#>
    func removingWholeMessageQuotes() -> Substring {
        // The regex which identifies a fully-quoted message and isolates the part to keep:
        let regex = /^"(?<keep>.+)"$/
        
        
        if let match = self.firstMatch(of: regex) {
            return match.output.keep
        }
        else {
            return self[...]
        }
    }
}
