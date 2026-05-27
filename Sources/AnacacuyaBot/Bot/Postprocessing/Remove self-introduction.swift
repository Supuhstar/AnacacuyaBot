//
//  Remove self-introduction.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-20.
//

import Foundation

import RegexBuilder



internal extension Substring {
    
    /// Sometimes, the bot will introduce itself (or a random user) at the start of its message. This removes it.
    ///
    /// Here's a real example:
    /// > "@AnacacuyaBot: Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts."
    ///
    /// - Parameters:
    ///   - personaName: The name used in current persona that the bot sent the message as
    ///
    /// - Returns: The message without the initial introduction, if'n it has one
    @MainActor
    func removingSelfIntroduction(personaName: String?) -> Substring {
        guard let botUsername = TGUser.botUser.username else {
            fatalError("Bot shouldn't be able to run without a username")
        }
        return removingSelfIntroduction(botUsername: botUsername, personaName: personaName)
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
    /// - Parameters:
    ///   - botUsername: The bot's @username (without the @)
    ///   - personaName: The name used in current persona that the bot sent the message as
    ///
    /// - Returns: The message without the initial introduction, if'n it has one
    func removingSelfIntroduction(botUsername: String, personaName: String?) -> Substring {
        let keepRef = Reference(Substring.self)
        
        let regex = selfIntroductionRegex(
            botUsername: botUsername,
            personaName: personaName,
            keepRef: keepRef,
        )
            .regex.ignoresCase()
        
        return self.firstMatch(of: regex).map { $0[keepRef] } ?? self
    }
    
    
    /// Builds a regex which can isolate and remove the bot introducing itself at the start of messages (usually `you:`, `@BotUsername:`, or `Persona Name:`)
    ///
    /// - Parameters:
    ///   - botUsername: The bot's @username (without the @)
    ///   - personaName: The name used in current persona that the bot sent the message as
    ///   - keepRef:     A reference to the part of the regex to capture as the part to keep
    private func selfIntroductionRegex(botUsername: String, personaName: String?, keepRef: Reference<Substring>) -> some RegexComponent {
        Regex {
            Anchor.startOfSubject
            Optionally {
                ChoiceOf {
                    startsWithYou
                    usernameIntroductionRegex(botUsername)
                    userIntroductionRegex(botUsername)
                    personaIntroductionRegex(personaName)
                }
                
                ZeroOrMore(.whitespace)
            }
            Capture(as: keepRef) {
                ZeroOrMore(.anyGraphemeCluster)
            }
            Anchor.endOfSubject
        }
    }
    
    
    private var startsWithYou: some RegexComponent {
        /(?:[Yy]ou:\s*\n)+/
//        OneOrMore {
//            ChoiceOf{"Y";"y"};"ou:"
//            One(.newlineSequence)
//        }.regex.ignoresCase()
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
    
    
    private func personaIntroductionRegex(_ personaName: String?) -> any RegexComponent {
        if let personaName {
            return Regex {
                Optionally { OneOrMore(.anyNonNewline); " " }
                
                personaIntroductionRegex(unparsedName: personaName); /:[\s\n]*/
            }
        }
        else {
            return /\w+:/
        }
    }
    
    
    private func personaIntroductionRegex(unparsedName: String) -> any RegexComponent {
        let names = unparsedName.split(separator: /\s+/)
        
        if let firstName = names.first {
            if let lastName = names.last,
               lastName != firstName
            {
                return personaIntroductionRegex(
                    fullName: unparsedName,
                    firstName: firstName,
                    lastName: lastName,
                )
            }
            else {
                return personaIntroductionRegex(fullName: unparsedName, firstName: firstName)
            }
        }
        else {
            return personaIntroductionRegex(fullName: unparsedName)
        }
    }
    
    
    @RegexComponentBuilder
    private func personaIntroductionRegex(fullName: String) -> some RegexComponent {
        fullName
    }
    
    
    @RegexComponentBuilder
    private func personaIntroductionRegex(fullName: String, firstName: Substring) -> some RegexComponent {
        ChoiceOf {
            firstName
            fullName
        }
    }
    
    
    @RegexComponentBuilder
    private func personaIntroductionRegex(fullName: String, firstName: Substring, lastName: Substring) -> some RegexComponent {
        ChoiceOf {
            firstName
            fullName
            lastName
        }
    }
}
