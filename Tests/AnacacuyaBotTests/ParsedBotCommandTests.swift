//
//  ParsedBotCommandTests.swift
//  AnacacuyaBotTests
//
//  Tests pinning the contract of `ParsedBotCommand.init(_:)`.
//

import Testing
@testable import AnacacuyaBot



@Suite("ParsedBotCommand parsing")
struct ParsedBotCommandTests {
    
    // MARK: - Documented examples
    
    @Test("`/help` parses as a bare command")
    func bareCommand() throws {
        let parsed = try #require(ParsedBotCommand("/help"))
        #expect("help" == parsed.name)
        #expect(nil == parsed.taggedBotUser)
        #expect(true == parsed.body.arguments.isEmpty)
        #expect(nil == parsed.body.arbitraryUserText)
    }
    
    @Test("`/remind in:2w Work on motorcycle` → one arg, trailing text")
    func singleArgWithTrailingText() throws {
        let parsed = try #require(ParsedBotCommand("/remind in:2w Work on motorcycle"))
        #expect("remind" == parsed.name)
        #expect(nil == parsed.taggedBotUser)
        #expect(1 == parsed.body.arguments.count)
        #expect("in" == parsed.body.arguments.first.map { String($0.name) })
        #expect("2w" == parsed.body.arguments.first.map { String($0.value) })
        #expect("Work on motorcycle" == parsed.body.arbitraryUserText.map(String.init))
    }
    
    @Test("`/debug_fullcontext purpose:interjection` keeps the colon in the name")
    func nameContainsColon() throws {
        let parsed = try #require(ParsedBotCommand("/debug_fullcontext purpose:interjection"))
        #expect("debug_fullcontext" == parsed.name)
        #expect(1 == parsed.body.arguments.count)
        #expect("purpose" == parsed.body.arguments.first.map { String($0.name) })
        #expect("interjection" == parsed.body.arguments.first.map { String($0.value) })
        #expect(nil == parsed.body.arbitraryUserText)
    }
    
    @Test("`/ban @KyNorthstar being weird` keeps @mention in body text, not args")
    func mentionInBodyIsText() throws {
        let parsed = try #require(ParsedBotCommand("/ban @KyNorthstar being weird"))
        #expect("ban" == parsed.name)
        #expect(true == parsed.body.arguments.isEmpty)
        #expect("@KyNorthstar being weird" == parsed.body.arbitraryUserText.map(String.init))
    }
    
    // MARK: - @bot tag handling
    
    @Test("`/prompt@AnacacuyaBot` splits name from bot tag")
    func botTagOnBareCommand() throws {
        let parsed = try #require(ParsedBotCommand("/prompt@AnacacuyaBot"))
        #expect("prompt" == parsed.name)
        #expect("AnacacuyaBot" == parsed.taggedBotUser)
        #expect(true == parsed.body.arguments.isEmpty)
        #expect(nil == parsed.body.arbitraryUserText)
    }
    
    @Test("`/remind@AnacacuyaBot in:2w Foo` splits name, bot, args, and text")
    func botTagWithBody() throws {
        let parsed = try #require(ParsedBotCommand("/remind@AnacacuyaBot in:2w Foo"))
        #expect("remind" == parsed.name)
        #expect("AnacacuyaBot" == parsed.taggedBotUser)
        #expect(1 == parsed.body.arguments.count)
        #expect("Foo" == parsed.body.arbitraryUserText.map(String.init))
    }
    
    // MARK: - Whitespace handling
    
    @Test("Trailing newline is absorbed")
    func trailingNewline() throws {
        let parsed = try #require(ParsedBotCommand("/help\n"))
        #expect("help" == parsed.name)
        #expect(nil == parsed.body.arbitraryUserText)
    }
    
    @Test("Trailing spaces are absorbed")
    func trailingSpaces() throws {
        let parsed = try #require(ParsedBotCommand("/help   "))
        #expect("help" == parsed.name)
        #expect(nil == parsed.body.arbitraryUserText)
    }
    
    @Test("Multiple spaces between command and body are tolerated")
    func multipleInternalSpaces() throws {
        let parsed = try #require(ParsedBotCommand("/help    me"))
        #expect("help" == parsed.name)
        #expect("me" == parsed.body.arbitraryUserText.map(String.init))
    }
    
    // MARK: - Argument value variations
    
    @Test("Argument value can contain colons (e.g. `time:12:30`)")
    func argValueWithColons() throws {
        let parsed = try #require(ParsedBotCommand("/at time:12:30 Lunch"))
        #expect(1 == parsed.body.arguments.count)
        #expect("12:30" == parsed.body.arguments.first.map { String($0.value) })
        #expect("Lunch" == parsed.body.arbitraryUserText.map(String.init))
    }
    
    @Test("Argument value can contain dots (e.g. `temperature:0.8`)")
    func argValueWithDots() throws {
        let parsed = try #require(ParsedBotCommand("/setParameter temperature:0.8"))
        #expect("0.8" == parsed.body.arguments.first.map { String($0.value) })
    }
    
    @Test("Multiple arguments parse in order")
    func multipleArguments() throws {
        let parsed = try #require(ParsedBotCommand("/cmd a:1 b:2 c:3"))
        #expect(["a", "b", "c"] == parsed.body.arguments.map { String($0.name) })
        #expect(["1", "2", "3"] == parsed.body.arguments.map { String($0.value) })
        #expect(nil == parsed.body.arbitraryUserText)
    }
    
    @Test("Argument parsing stops at the first non-arg token")
    func argParsingStopsAtNonArg() throws {
        // After `a:1` matches, `plain` doesn't match `\w+:\S+`,
        // so everything from `plain` on becomes arbitrary text.
        let parsed = try #require(ParsedBotCommand("/cmd a:1 plain text b:2"))
        #expect(1 == parsed.body.arguments.count)
        #expect("a" == parsed.body.arguments.first.map { String($0.name) })
        #expect("plain text b:2" == parsed.body.arbitraryUserText.map(String.init))
    }
    
    // MARK: - Rejected inputs
    
    @Test(
        "Inputs that aren't commands parse to nil",
        arguments: [
            "",
            " ",
            "\n",
            "Hello",
            "no slash here",
            "/",            // no name after slash
            "/ ",           // whitespace where name should be
            "//double",     // `/` isn't a word char
        ] as [String]
    )
    func notACommand(input: String) {
        #expect(nil == ParsedBotCommand(input))
    }
    
    @Test("Multi-line input is allowed (the `.` in the regex may span newlines)")
    func multiLineAllowed() {
        #expect(nil != ParsedBotCommand("/help\nsome more text"))
    }
}
