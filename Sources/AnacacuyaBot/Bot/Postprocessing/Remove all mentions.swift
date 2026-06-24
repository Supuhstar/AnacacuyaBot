//
//  Remove all mentions.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-18.
//

import Foundation



private let atChatacter: Character = "@"



public extension Substring {
    
    /// Removes `@mention`s from the message.
    ///
    /// Smollm has no concept of when it's appropriate to mention someone, so it's effectively never appropriate.
    /// This removes those entirely.
    ///
    /// - Returns: The message, `@mention`s. If it has none, this returns the whole input unchanged.
    func removingMentions() -> Substring {
        filter { character in
            character != atChatacter
        }
    }
}
