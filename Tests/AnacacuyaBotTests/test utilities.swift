//
//  test utilities.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-23.
//

import Foundation

import AnacacuyaBot



func setUpBot() async {
    await MainActor.run {
        TGUser.botUser = TGUser(id: 420, isBot: true, firstName: "Luna", username: "AnacacuyaBot")
    }
}



// MARK: - Test Persona

extension Persona {
    static let test = Persona(
        name: "Test Persona",
        directResponseSystemPrompt: "",
        interjectionSystemPrompt: "",
        tools: [],
    )
}
