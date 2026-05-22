//
//  Remove self-introduction.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-20.
//

import Foundation

import RegexBuilder



extension Substring {
    
    /// Sometimes, the bot will introduce itself (or a random user) at the start of its message. This removes it.
    ///
    /// Here's a real example:
    /// > "@AnacacuyaBot: Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts."
    ///
    /// - Returns: The message without the initial introduction, if'n it has one
    @MainActor
    func removingSelfIntroduction() -> Substring {
        guard let botUsername = TGUser.botUser.username else {
            fatalError("Bot shouldn't be able to run without a username")
        }
        return removingSelfIntroduction(botUsername: botUsername)
    }
    
    
    /// Sometimes, the bot will introduce itself (or a random user) at the start of its message. This removes it.
    /// 
    /// Here's a real example:
    /// > "@AnacacuyaBot: Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts."
    /// 
    /// - Parameter botUsername: The username of the bot (without an @)
    ///
    /// - Returns: The message without the initial introduction, if'n it has one
    func removingSelfIntroduction(botUsername: String) -> Substring {
        let keepRef = Reference(Substring.self)
        
        let regex = Regex {
            Anchor.startOfSubject
            Optionally {
                Optionally { OneOrMore(.any); " " }
                "(@"; botUsername; "):"
            }
            Capture(as: keepRef) {
                OneOrMore { ChoiceOf { One(.any); One(.newlineSequence) } }
            }
            Anchor.endOfSubject
        }
        
        return self.firstMatch(of: regex).map { $0[keepRef] } ?? self
    }
}
