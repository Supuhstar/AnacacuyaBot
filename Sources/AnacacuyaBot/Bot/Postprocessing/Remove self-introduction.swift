//
//  Remove self-introduction.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-20.
//

import Foundation



extension Substring {
    
    /// Sometimes, the bot will introduce itself (or a random user) at the start of its message. This removes it.
    ///
    /// Here's a real example:
    /// > "@AnacacuyaBot: Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts."
    ///
    /// - Returns: The message without the initial introduction, if'n it has one
    func removingSelfIntroduction() -> Substring {
        isolate(by: /^(?:.+? \(@\w+\):)?(?<keep>.+)$/, keeping: \.keep)
    }
}
