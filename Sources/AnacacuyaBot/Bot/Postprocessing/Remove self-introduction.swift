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
    /// > @AnacacuyaBot: Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts.
    ///
    /// The bot also tends to:
    /// > you:
    /// > :) Yeah, that's true, it does have an old-world charm to it. The bicycle stands out against the modern buildings, and the cobblestones are really cool. It feels like a different era.
    ///
    /// This function addresses both of those
    ///
    /// - Returns: The message without the initial introduction, if'n it has one
    func removingSelfIntroduction() -> Substring {
        guard isNotEmpty else { return self }
        let keepRef = Reference(Substring.self)
        let regex = selfIntroductionRegex(keepRef: keepRef)
        return self.firstMatch(of: regex).map { $0[keepRef] } ?? self
    }
    
    
    // /^(?:startsWithYou|userIntroductionRegex)?\s*(?<keepRef>.+)$/
    private func selfIntroductionRegex(keepRef: Reference<Substring>) -> some RegexComponent {
        Regex {
            Anchor.startOfSubject
            Optionally {
                ChoiceOf {
                    startsWithYou
                    userIntroductionRegex
                }
                
                ZeroOrMore(.whitespace)
            }
            Capture(as: keepRef) {
                OneOrMore(.anyGraphemeCluster)
            }
            Anchor.endOfSubject
        }
    }
    
    
    // /(?:you:\n)+/
    private var startsWithYou: some RegexComponent {
        /(?:you:\n)+/
    }
    
    
    // /([^\n]+ )?(?:\(@\w+?\):|@\w+?:)/
    private var userIntroductionRegex: some RegexComponent {
        Regex {
            Optionally { OneOrMore(.anyNonNewline); " " }
            /(?:\(@\w+?\)|@\w+?:)/
        }
    }
}
