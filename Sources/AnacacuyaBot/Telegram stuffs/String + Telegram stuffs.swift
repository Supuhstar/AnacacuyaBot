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
        
        func escapePlaintext(_ text: Substring) -> String {
            text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in
                    let (marker, body): (String, Substring) =
                    if line.hasPrefix("**>") { ("**>", line.dropFirst(3)) }
                    else if line.hasPrefix(">") { (">", line.dropFirst()) }
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
                    let display = span[..<split.upperBound]
                    let url = span[split.upperBound..<span.index(before: span.endIndex)]
                    return "\(display)\(url.replacing(urlSpecials) { "\\\($0.output)" }))"
                }
            }
            return String(span)
        }
        
        var result = ""
        var cursor = startIndex
        for match in matches(of: spans) {
            result += escapePlaintext(self[cursor..<match.range.lowerBound])
            result += escapeSpan(self[match.range])
            cursor = match.range.upperBound
        }
        result += escapePlaintext(self[cursor...])
        return result
    }
}
