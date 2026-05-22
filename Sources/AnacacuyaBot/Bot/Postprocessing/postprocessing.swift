//
//  postprocessing.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//

import Foundation



public extension String {
    
    /// Runs postprocessing on a bot message to make it good enough to send to the user
    ///
    /// - Returns: The bot's message, postprocessed to remove unwanted artifacts
    @MainActor
    func postprocessed() -> String {
        self[...]
            .postprocessed()
    }
}



public extension Substring {
    
    /// Runs postprocessing on a bot message to make it good enough to send to the user
    ///
    /// - Returns: The bot's message, postprocessed to remove unwanted artifacts
    @MainActor
    func postprocessed() -> String {
        self
            .removingSelfIntroduction()
            .removingFakeChatLogs()
            .removingWholeMessageQuotes()
            .removingFilenameTag()
            .removingSelfIntroduction()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}



internal extension Substring {
    
    /// Isolates part of this substring by matching against the given regex, only keeping the given capture
    ///
    /// - Parameters:
    ///   - regex:       A regex which can isolate part of this substring
    ///   - keptCapture: The captured substring to keep
    ///
    /// - Returns: The substring captured by `keptCapture`
    func isolate<R: RegexComponent>(by regex: R, keeping keptCapture: KeyPath<R.RegexOutput, Substring>) -> Substring {
        if let match = self.firstMatch(of: regex) {
            return match.output[keyPath: keptCapture]
        }
        else {
            return self
        }
    }
    
    /// Isolates part of this substring by matching against the given regex, only keeping the given capture
    ///
    /// - Parameters:
    ///   - regex:       A regex which can isolate part of this substring
    ///   - keptCapture: The captured substring to keep
    ///
    /// - Returns: The substring captured by `keptCapture`. If `keepCapture` ends up with a `nil` output, this returns an empty string
    func isolate<R: RegexComponent>(by regex: R, keeping keptCapture: KeyPath<R.RegexOutput, Substring?>) -> Substring {
        if let match = self.firstMatch(of: regex) {
            return match.output[keyPath: keptCapture] ?? ""
        }
        else {
            return self
        }
    }
}
