//
//  TGUser + constants.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-21.
//

import Foundation



public extension TGUser {
    
    /// A fake user to use for system messages to the LLM
    static let system = TGUser(id: 0, isBot: false, firstName: "System", username: nil)
    
    
    /// A fake user to use for tool call result messages
    ///
    /// - Parameter toolName: The name of the tool which was called
    static func toolCall(toolName: String) -> Self {
        TGUser(id: 0, isBot: false, firstName: toolName, username: nil)
    }
}
