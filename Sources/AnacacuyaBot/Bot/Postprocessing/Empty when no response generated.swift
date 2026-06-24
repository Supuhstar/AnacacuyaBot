//
//  Empty when no response generated.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-21.
//

import Foundation

import RegexBuilder



extension Substring {
    
    /// The bot is encouraged to send `[no response generated]` if it doesn't want to respond.
    ///
    /// - Returns: The message, or an empty string, depending on whether the bot chose to respond
    func removingNoResponseGenerated() -> Substring {
        shouldRespond
            ? self
            : self.prefix(0)
    }
    
    
    private var shouldRespond: Bool {
        isEmpty
        || 0 == matches(of: noResponseRegex).count
    }
}



//unsafe: Unsure if there's a better way to do this. Pretty sure `Regex` is safe to be nonisolated anyway.
@safe
nonisolated(unsafe)
private let noResponseRegex = Regex {
        Anchor.startOfSubject
        ChoiceOf {
            bracketed("[", noResponseGeneratedString_unbracketed, "]")
            bracketed("{", noResponseGeneratedString_unbracketed, "}")
            bracketed("(", noResponseGeneratedString_unbracketed, ")")
        }
        ZeroOrMore(.whitespace)
        Optionally {
            "."
        }
        ZeroOrMore(.whitespace)
        Anchor.endOfSubject
    }
    .ignoresCase()



// /((?:\[|\\\[)\s*no response generated\s*(?:\]|\\\]))/
private func bracketed(_ opening: Character, _ body: String, _ closing: Character) -> Regex<(Substring, Substring)> {
    Regex {
        Capture {
            ChoiceOf {
                opening
                "\\\(opening)"
            }
            ZeroOrMore(.whitespace)
            body
            ZeroOrMore(.whitespace)
            ChoiceOf {
                closing
                "\\\(closing)"
            }
        }
    }
}
