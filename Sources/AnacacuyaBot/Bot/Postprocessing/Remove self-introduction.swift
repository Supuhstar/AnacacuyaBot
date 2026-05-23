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
    /// > @AnacacuyaBot: Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts.
    ///
    /// The bot also tends to:
    /// > you:
    /// > :) Yeah, that's true, it does have an old-world charm to it. The bicycle stands out against the modern buildings, and the cobblestones are really cool. It feels like a different era.
    ///
    /// This function addresses both of those
    ///
    /// - Parameter botUsername: The username of the bot (without an @)
    ///
    /// - Returns: The message without the initial introduction, if'n it has one
    func removingSelfIntroduction(botUsername: String) -> Substring {
        let keepRef = Reference(Substring.self)
        
        let regex = selfIntroductionRegex(botUsername: botUsername, keepRef: keepRef)
        
        return self.firstMatch(of: regex).map { $0[keepRef] } ?? self
    }
    
    
    private func selfIntroductionRegex(botUsername: String, keepRef: Reference<Substring>) -> some RegexComponent {
        Regex {
            Anchor.startOfSubject
            Optionally {
                ChoiceOf {
                    startsWithYou
                    usernameIntroductionRegex(botUsername)
                    userIntroductionRegex(botUsername)
                }
                
                ZeroOrMore(.whitespace)
            }
            Capture(as: keepRef) {
                OneOrMore(.anyGraphemeCluster)
            }
            Anchor.endOfSubject
        }
    }
    
    
    private var startsWithYou: some RegexComponent {
        OneOrMore {
            "you:"
            One(.newlineSequence)
        }
    }
    
    
    private func usernameIntroductionRegex(_ username: String) -> some RegexComponent {
        Regex {
            "@"; username; ":"
        }
    }
    
    
    private func userIntroductionRegex(_ username: String) -> some RegexComponent {
        Regex {
            Optionally { OneOrMore(.anyNonNewline); " " }
            "(@"; username; "):"
        }
    }
}
