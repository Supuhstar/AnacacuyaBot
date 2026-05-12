//
//  MarkdownV2EscapingTests.swift
//  AnacacuyaBotTests
//
//  Tests pinning the contract of the two `String` Telegram-escape helpers
//  in `String + Telegram stuffs.swift`.
//
//  Tests marked `// FAILS:` describe *desired* behavior that the current
//  implementation does not yet satisfy — see the comment for the reason.
//

import Testing
@testable import AnacacuyaBot



@Suite("Telegram MarkdownV2 escaping")
struct MarkdownV2EscapingTests {
    
    // MARK: - telegram_escapedToInsertAsPlaintextIntoMarkdownV2
    
    @Suite("Plain text → MarkdownV2 (escape everything)")
    struct PlaintextEscaping {
        
        @Test("Empty string stays empty")
        func empty() {
            #expect("" == "".telegram_escapedToInsertAsPlaintextIntoMarkdownV2)
        }
        
        @Test("Text without specials passes through")
        func noSpecials() {
            #expect("Hello world" == "Hello world".telegram_escapedToInsertAsPlaintextIntoMarkdownV2)
        }
        
        @Test(
            "Every MarkdownV2 special character gets backslash-escaped",
            arguments: [
                ("_", "\\_"),
                ("*", "\\*"),
                ("[", "\\["),
                ("]", "\\]"),
                ("(", "\\("),
                (")", "\\)"),
                ("~", "\\~"),
                ("`", "\\`"),
                (">", "\\>"),
                ("#", "\\#"),
                ("+", "\\+"),
                ("-", "\\-"),
                ("=", "\\="),
                ("|", "\\|"),
                ("{", "\\{"),
                ("}", "\\}"),
                (".", "\\."),
                ("!", "\\!"),
            ]
        )
        func singleSpecialChar(input: String, expected: String) {
            #expect(expected == input.telegram_escapedToInsertAsPlaintextIntoMarkdownV2)
        }
        
        // FAILS: the function's regex character class omits `\`. Per Telegram
        // rule 1 ("any character with code between 1 and 126 inclusively can
        // be escaped … this implies that `\` character usually must be
        // escaped with a preceding `\` character"), a stray backslash in
        // plaintext should become `\\` so Telegram's parser sees a literal
        // backslash. Currently it passes through unchanged.
        @Test("Backslash itself must be escaped (per Telegram rule 1)")
        func backslashIsEscaped() {
            #expect("\\\\" == "\\".telegram_escapedToInsertAsPlaintextIntoMarkdownV2)
        }
        
        @Test("All specials in one string get escaped")
        func combinedSpecials() {
            #expect(
                "Hello, world\\! \\(v1\\.0\\)" ==
                "Hello, world! (v1.0)".telegram_escapedToInsertAsPlaintextIntoMarkdownV2
            )
        }
    }
    
    // MARK: - telegram_escapedForMarkdownV2
    
    @Suite("Mixed input (preserve spans, escape gaps)")
    struct FullEscaping {
        
        // MARK: Trivial inputs
        
        @Test("Empty string stays empty")
        func empty() {
            #expect("" == "".telegram_escapedForMarkdownV2)
        }
        
        @Test("Plain text without specials passes through")
        func plainText() {
            #expect("Hello world" == "Hello world".telegram_escapedForMarkdownV2)
        }
        
        @Test("Specials outside spans get escaped")
        func plaintextSpecialsEscaped() {
            #expect("Hello\\." == "Hello.".telegram_escapedForMarkdownV2)
            #expect("a \\> b" == "a > b".telegram_escapedForMarkdownV2)
            #expect("1 \\+ 1 \\= 2" == "1 + 1 = 2".telegram_escapedForMarkdownV2)
        }
        
        // MARK: Spans pass through verbatim
        
        @Test("Italic span passes through unchanged")
        func italicSpan() {
            #expect("_great_" == "_great_".telegram_escapedForMarkdownV2)
        }
        
        @Test("Bold span passes through unchanged")
        func boldSpan() {
            #expect("*loud*" == "*loud*".telegram_escapedForMarkdownV2)
        }
        
        @Test("Underline span passes through unchanged")
        func underlineSpan() {
            #expect("__deep__" == "__deep__".telegram_escapedForMarkdownV2)
        }
        
        @Test("Strikethrough span passes through unchanged")
        func strikeSpan() {
            #expect("~gone~" == "~gone~".telegram_escapedForMarkdownV2)
        }
        
        @Test("Spoiler span passes through unchanged")
        func spoilerSpan() {
            #expect("||secret||" == "||secret||".telegram_escapedForMarkdownV2)
        }
        
        @Test("Inline code span passes through unchanged")
        func inlineCodeSpan() {
            #expect("`x = 1`" == "`x = 1`".telegram_escapedForMarkdownV2)
        }
        
        @Test("Triple-backtick code block passes through unchanged")
        func tripleBacktickBlock() {
            #expect("```\ncode\n```" == "```\ncode\n```".telegram_escapedForMarkdownV2)
        }
        
        @Test("Inline link passes through unchanged")
        func linkSpan() {
            #expect(
                "[click](https://example.com)" ==
                "[click](https://example.com)".telegram_escapedForMarkdownV2
            )
        }
        
        @Test("Custom emoji span passes through unchanged")
        func customEmojiSpan() {
            #expect(
                "![👍](tg://emoji?id=5368324170671202286)" ==
                "![👍](tg://emoji?id=5368324170671202286)".telegram_escapedForMarkdownV2
            )
        }
        
        // MARK: Specials inside vs. around spans
        
        @Test("Specials inside a span are not escaped (span is atomic)")
        func specialsInsideSpan() {
            // Telegram's parser is lenient about specials inside formatting spans;
            // the function preserves them verbatim rather than fighting that.
            #expect("*a.b*" == "*a.b*".telegram_escapedForMarkdownV2)
        }
        
        @Test("Specials around a span are escaped while the span stays intact")
        func specialsAroundSpan() {
            #expect(
                "That's _great_ \\>\\.\\>" ==
                "That's _great_ >.>".telegram_escapedForMarkdownV2
            )
        }
        
        // MARK: Inside code (rule 2)
        
        @Test("Backslash inside inline code gets escaped")
        func inlineCodeBackslash() {
            #expect("`a\\\\b`" == "`a\\b`".telegram_escapedForMarkdownV2)
        }
        
        @Test("Other specials inside inline code do not get escaped")
        func inlineCodeKeepsSpecials() {
            #expect("`hello.world`" == "`hello.world`".telegram_escapedForMarkdownV2)
            #expect("`a > b`" == "`a > b`".telegram_escapedForMarkdownV2)
        }
        
        @Test("Backslash inside triple-backtick block gets escaped")
        func tripleBacktickBackslash() {
            #expect(
                "```\nlet path = \"a\\\\b\"\n```" ==
                "```\nlet path = \"a\\b\"\n```".telegram_escapedForMarkdownV2
            )
        }
        
        // MARK: Inside link URL (rule 3)
        
        @Test("Backslash inside URL gets escaped")
        func urlBackslash() {
            // The only url-special the function can actually escape inside a span is `\`,
            // because `)` would have terminated the regex match before we got here.
            #expect(
                "[a](http://example.com/foo\\\\bar)" ==
                "[a](http://example.com/foo\\bar)".telegram_escapedForMarkdownV2
            )
        }

        @Test("Unescaped `)` inside a URL ends the link span (known limitation)")
        func unescapedParenEndsURL() {
            // The link regex's `[^)]*` stops the URL at the first `)`, so
            // `[ok](https://example.com/path)` becomes the matched span and the
            // trailing `more)` falls to the plaintext escaper.
            // If a user wants a literal `)` in a URL, they must pre-escape it as `\)`.
            #expect(
                "[ok](https://example.com/path)more\\)" ==
                "[ok](https://example.com/path)more)".telegram_escapedForMarkdownV2
            )
        }
        
        // MARK: Block quotes
        
        @Test("Leading `>` is preserved as a block-quote marker")
        func blockQuoteMarker() {
            #expect(">quote line" == ">quote line".telegram_escapedForMarkdownV2)
        }
        
        @Test("Leading `**>` is preserved as an expandable block-quote marker")
        func expandableBlockQuoteMarker() {
            #expect("**>expanded" == "**>expanded".telegram_escapedForMarkdownV2)
        }
        
        @Test("`>` in the middle of a line still gets escaped")
        func midLineGreaterThan() {
            #expect("a \\> b" == "a > b".telegram_escapedForMarkdownV2)
        }
        
        @Test("Multi-line block quote keeps the marker on every line")
        func multiLineBlockQuote() {
            #expect(
                ">first\n>second" ==
                ">first\n>second".telegram_escapedForMarkdownV2
            )
        }
        
        @Test("Block quote with specials in the body escapes them after the marker")
        func blockQuoteBodyEscaped() {
            #expect(">a\\.b" == ">a.b".telegram_escapedForMarkdownV2)
        }
        
        // MARK: Backslash
        
        @Test("Stray backslash outside any span gets escaped")
        func strayBackslash() {
            #expect("a\\\\b" == "a\\b".telegram_escapedForMarkdownV2)
        }
        
        // MARK: Realistic LLM-style output
        
        @Test("Realistic mixed message: prose + italic + specials")
        func realisticMessage() {
            let input = "Hey @KyNorthstar! That's _exactly_ what I meant. >.>"
            let expected = "Hey @KyNorthstar\\! That's _exactly_ what I meant\\. \\>\\.\\>"
            #expect(expected == input.telegram_escapedForMarkdownV2)
        }
    }
}
