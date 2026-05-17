//
//  OLLAMA_BASE_URL.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



private let defaultOllamaBaseUrl = URL(string: "http://localhost:11434")!



extension UnixEnvironmentKey where Value == URL?, Backup == URL {
    
    /// The base URL for the Ollama API, like `"http://localhost:11434"`
    static let ollamaBaseUrl = Self(
        "OLLAMA_BASE_URL",
        parse: URL.init(string:),
        backup: defaultOllamaBaseUrl,
    )
}
