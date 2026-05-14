//
//  String + Telegram stuffs.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-09.
//

import Foundation



public extension String {
    
    /// Escape this string so that it can be inserted into a Telegram message using their MarkdownV2 syntax, but as plaintext without formatting.
    ///
    /// Because if you don't escape it, they'll just reject it with a 400 error.
    var telegram_escapedToInsertAsPlaintextIntoMarkdownV2: String {
        self.replacing(/[\\_*\[\]()~`>#+=|{}.!-]/) { "\\\($0.output)" }
    }
    
    
    /// Escape this string so that it can be sent as a Telegram message using their MarkdownV2 syntax for formatting.
    ///
    /// Because if you don't escape it, they'll just reject it with a 400 error.
    var telegram_escapedForMarkdownV2: String {
        // Thanks to Claude 4.7 Opus for doing this bullshit so I don't have to
        
        let spans = #/```[\s\S]*?```|`[^`\n]+`|!?\[[^\]]*\]\([^)]*\)|__(?:[^_]|_(?!_))+__|\*[^*\n]+\*|_[^_\n]+_|~[^~\n]+~|\|\|[^|\n]+\|\|/#
        // Rules 1 + 4: plaintext specials, including `\` itself.
        let plaintextSpecials = /[\\_*\[\]()~`>#+=|{}.!-]/
        // Rule 2: inside pre/code, only ` and \ need escaping.
        let codeSpecials = /[\\`]/
        // Rule 3: inside (...) of link/emoji, only ) and \ need escaping.
        let urlSpecials = /[\\)]/
        
        func escapePlaintext(_ text: Substring, lineStart: Bool) -> String {
            text.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .map { index, line in
                    // Only treat `>` as a block-quote marker when it's genuinely
                    // at the start of a line. Segments that follow a span mid-line
                    // pass lineStart: false, so a `>` right after a span doesn't
                    // get the block-quote treatment even though it starts the segment.
                    let atLineStart = 0 == index ? lineStart : true
                    let (marker, body): (String, Substring) =
                    if atLineStart && line.hasPrefix("**>") { ("**>", line.dropFirst(3)) }
                    else if atLineStart && line.hasPrefix(">") { (">", line.dropFirst()) }
                    else { ("", line) }
                    return marker + body.replacing(plaintextSpecials) { "\\\($0.output)" }
                }
                .joined(separator: "\n")
        }
        
        func escapeSpan(_ span: Substring) -> String {
            if span.hasPrefix("```") {
                let inner = span.dropFirst(3).dropLast(3)
                return "```\(inner.replacing(codeSpecials) { "\\\($0.output)" })```"
            }
            if span.hasPrefix("`") {
                let inner = span.dropFirst().dropLast()
                return "`\(inner.replacing(codeSpecials) { "\\\($0.output)" })`"
            }
            if span.hasPrefix("[") || span.hasPrefix("![") {
                if let split = span.range(of: "](", options: .backwards) {
                    let leadingMarker = span.hasPrefix("![") ? "![" : "["
                    let displayStart  = span.index(span.startIndex, offsetBy: leadingMarker.count)
                    let display       = span[displayStart..<split.lowerBound]
                    let url           = span[split.upperBound..<span.index(before: span.endIndex)]
                    let escapedDisplay = display.replacing(plaintextSpecials) { "\\\($0.output)" }
                    let escapedUrl     = url.replacing(urlSpecials) { "\\\($0.output)" }
                    return "\(leadingMarker)\(escapedDisplay)](\(escapedUrl))"
                }
            }
            // Formatting spans: *, _, __, ~, ||
            // Rule 4 applies inside these too — specials must be escaped.
            let delimLen = (span.hasPrefix("__") || span.hasPrefix("||")) ? 2 : 1
            let delim    = String(span.prefix(delimLen))
            let inner    = span.dropFirst(delimLen).dropLast(delimLen)
            return "\(delim)\(inner.replacing(plaintextSpecials) { "\\\($0.output)" })\(delim)"
        }
        
        var result = ""
        var cursor = startIndex
        
        // True when `cursor` sits at the very beginning of a line — either the
        // start of the string or right after a newline. Used to distinguish a
        // genuinely line-leading `>` from one that follows a span mid-line.
        func isAtLineStart() -> Bool {
            cursor == startIndex || "\n" == self[self.index(before: cursor)]
        }
        
        for match in matches(of: spans) {
            result += escapePlaintext(self[cursor..<match.range.lowerBound], lineStart: isAtLineStart())
            result += escapeSpan(self[match.range])
            cursor = match.range.upperBound
        }
        result += escapePlaintext(self[cursor...], lineStart: isAtLineStart())
        return result
    }
}
