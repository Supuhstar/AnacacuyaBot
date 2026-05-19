//
//  String + postprocessed.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//

import Foundation



public extension String {
    
    /// Runs postprocessing on a bot message to make it good enough to send to the user
    ///
    /// - Returns: The bot's message, postprocessed to remove unwanted artifacts
    func postprocessed() -> String {
        String(self[...].postprocessed())
    }
}



public extension Substring {
    
    /// Runs postprocessing on a bot message to make it good enough to send to the user
    ///
    /// - Returns: The bot's message, postprocessed to remove unwanted artifacts
    func postprocessed() -> Substring {
        self.removingFakeChatLogs()
            .removingWholeMessageQuotes()
    }
}
