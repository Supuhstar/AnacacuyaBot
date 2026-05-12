//
//  PersonaSanitizeTests.swift
//  AnacacuyaBotTests
//
//  Tests pinning the contract of `Persona.sanitize(_:botUsername:knownSenders:)`,
//  which strips spurious speaker prefixes that small models echo back from the
//  transcript shape we feed them.
//

import Testing
@testable import AnacacuyaBot



@Suite("Persona.sanitize")
struct PersonaSanitizeTests {
    
    /// The prompts on `Persona` don't affect sanitize, so we keep this minimal.
    private let persona = Persona(
        directResponseSystemPrompt: "—",
        interjectionSystemPrompt: "—"
    )
    
    // MARK: - Stripping the bot's own prefix
    
    @Test("Strips the bot's own username prefix")
    func stripsBotPrefix() {
        let result = persona.sanitize(
            "AnacacuyaBot: hello there",
            botUsername: "AnacacuyaBot",
            knownSenders: []
        )
        #expect("hello there" == result)
    }
    
    @Test("Strips @-prefixed bot username")
    func stripsAtBotPrefix() {
        let result = persona.sanitize(
            "@AnacacuyaBot: hello there",
            botUsername: "AnacacuyaBot",
            knownSenders: []
        )
        #expect("hello there" == result)
    }
    
    @Test("Case-insensitive bot username matching")
    func caseInsensitiveBot() {
        let result = persona.sanitize(
            "anacacuyabot: hi",
            botUsername: "AnacacuyaBot",
            knownSenders: []
        )
        #expect("hi" == result)
    }
    
    // MARK: - Stripping known-sender prefixes
    
    @Test("Strips a known human sender prefix")
    func stripsHumanPrefix() {
        let result = persona.sanitize(
            "KyNorthstar: yes please",
            botUsername: "AnacacuyaBot",
            knownSenders: ["KyNorthstar"]
        )
        #expect("yes please" == result)
    }
    
    @Test("Strips @-prefixed known sender")
    func stripsAtHumanPrefix() {
        let result = persona.sanitize(
            "@KyNorthstar: yes please",
            botUsername: "AnacacuyaBot",
            knownSenders: ["KyNorthstar"]
        )
        #expect("yes please" == result)
    }
    
    @Test("Case-insensitive known-sender matching")
    func caseInsensitiveHuman() {
        let result = persona.sanitize(
            "kynorthstar: hi",
            botUsername: "AnacacuyaBot",
            knownSenders: ["KyNorthstar"]
        )
        #expect("hi" == result)
    }
    
    @Test("Longest matching known sender wins")
    func longestMatchWins() {
        // If both `Ky` and `KyNorthstar` are known senders, `KyNorthstar:`
        // should strip the longer match — otherwise `Ky` would match first
        // and leave `Northstar:` dangling.
        let result = persona.sanitize(
            "KyNorthstar: hi",
            botUsername: "AnacacuyaBot",
            knownSenders: ["Ky", "KyNorthstar"]
        )
        #expect("hi" == result)
    }
    
    // MARK: - Negative cases
    
    @Test("Unknown sender-looking prefix is preserved")
    func preservesUnknownPrefix() {
        // "Honestly: yes" looks like a prefix but isn't a known sender —
        // it's legitimate prose and must survive.
        let result = persona.sanitize(
            "Honestly: yes",
            botUsername: "AnacacuyaBot",
            knownSenders: ["KyNorthstar"]
        )
        #expect("Honestly: yes" == result)
    }
    
    @Test("Input without any prefix passes through (after trim)")
    func noPrefixUnchanged() {
        let result = persona.sanitize(
            "just a message",
            botUsername: "AnacacuyaBot",
            knownSenders: ["KyNorthstar"]
        )
        #expect("just a message" == result)
    }
    
    @Test("Prefix-like substring not at the start is preserved")
    func midStringPrefixPreserved() {
        let result = persona.sanitize(
            "I think KyNorthstar: that's clever",
            botUsername: "AnacacuyaBot",
            knownSenders: ["KyNorthstar"]
        )
        #expect("I think KyNorthstar: that's clever" == result)
    }
    
    // MARK: - Whitespace and empty input
    
    @Test("Trims leading and trailing whitespace")
    func trimsSurroundingWhitespace() {
        let result = persona.sanitize(
            "  \n hello there  \n  ",
            botUsername: "AnacacuyaBot",
            knownSenders: []
        )
        #expect("hello there" == result)
    }
    
    @Test("Whitespace between prefix and body is consumed")
    func consumesWhitespaceAfterColon() {
        let result = persona.sanitize(
            "KyNorthstar:     hi",
            botUsername: "AnacacuyaBot",
            knownSenders: ["KyNorthstar"]
        )
        #expect("hi" == result)
    }
    
    @Test("Empty input returns empty")
    func emptyInput() {
        let result = persona.sanitize(
            "",
            botUsername: "AnacacuyaBot",
            knownSenders: []
        )
        #expect("" == result)
    }
    
    @Test("Whitespace-only input returns empty after trim")
    func whitespaceOnlyInput() {
        let result = persona.sanitize(
            "   \n\t  ",
            botUsername: "AnacacuyaBot",
            knownSenders: []
        )
        #expect("" == result)
    }
    
    // MARK: - Edge cases on inputs
    
    @Test("Empty bot username + empty senders strips nothing")
    func emptyCandidatesStripsNothing() {
        let result = persona.sanitize(
            "Whoever: hi",
            botUsername: "",
            knownSenders: []
        )
        #expect("Whoever: hi" == result)
    }
    
    @Test("Regex metacharacters in sender names are treated as literals")
    func regexMetacharactersAreEscaped() {
        // Sender names like `a.b` shouldn't act as regex patterns
        // (the function uses `NSRegularExpression.escapedPattern(for:)`).
        let result = persona.sanitize(
            "a.b: hello",
            botUsername: "AnacacuyaBot",
            knownSenders: ["a.b"]
        )
        #expect("hello" == result)
    }
}
