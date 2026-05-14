//
//  Environment.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-14.
//

import Foundation

@unsafe @preconcurrency import SpecialString



/// The environment in which this bot is running
enum UnixEnvironment {}



extension UnixEnvironment {
    
    /// Read the value of an environment variable
    static subscript<Value>(_ pair: UnixEnvironmentKey<Value, Never>) -> Value? {
        get {
            guard let raw = ProcessInfo.processInfo.environment[pair.rawValue],
                  let parsed = pair.parse(raw)
            else {
                return nil
            }
            
            return parsed
        }
    }
    
    
    /// Read the value of an environment variable
    static subscript<Value>(_ pair: UnixEnvironmentKey<Value?, Value>) -> Value {
        get {
            guard let raw = ProcessInfo.processInfo.environment[pair.rawValue],
                  let parsed = pair.parse(raw)
            else {
                return pair.backup()
            }
            
            return parsed ?? pair.backup()
        }
    }
}



/// A key to an environment value that this bot reads as needed
struct UnixEnvironmentKey<Value: Sendable, Backup: Sendable>: Sendable {
    
    fileprivate let rawValue: String
    
    fileprivate let parse: ParseFunction
    
    fileprivate let backup: BackupGeneratorFunction
    
    
    init(_ key: String,
         parse: @escaping ParseFunction,
         backup: @autoclosure @escaping BackupGeneratorFunction)
    {
        self.rawValue = key
        self.parse = parse
        self.backup = backup
    }
    
    
    
    typealias ParseFunction = @Sendable (_ raw: String) -> Value?
    typealias BackupGeneratorFunction = @Sendable () -> Backup
}



extension UnixEnvironmentKey where Backup == Never {
    init (_ key: String, parse: @escaping ParseFunction) {
        self.rawValue = key
        self.parse = parse
        self.backup = { fatalError("No backup value provided for \(key)") }
    }
}



extension UnixEnvironmentKey where Value: LosslessStringConvertible {
    
    init(_ key: String) where Backup == Never {
        self.init(
            key,
            parse: { Value($0) })
    }
    
    
    init(_ key: String, backup: @autoclosure @escaping BackupGeneratorFunction) {
        self.init(
            key,
            parse: { Value($0) },
            backup: backup())
    }
}



extension UnixEnvironmentKey: ExpressibleByUnicodeScalarLiteral,
                              ExpressibleByExtendedGraphemeClusterLiteral,
                              ExpressibleByStringLiteral
where Value: LosslessStringConvertible,
      Backup == Never
{
    init(stringLiteral value: String) {
        self.init(value)
    }
}



extension UnixEnvironmentKey
where Value == TelegramBotToken,
      Backup == Never
{
    
    /// The bot's login token from Telegram.
    ///
    /// You obtain this from [@BotFather](https://t.me/BotFather) on Telegram
    static let telegramBotToken: Self = "TELEGRAM_BOT_TOKEN"
}



extension UnixEnvironmentKey where Value == String?, Backup == String {
    
    init(_ key: String, backup: @autoclosure @escaping BackupGeneratorFunction) {
        self.init(
            key,
            parse: { $0.isEmpty ? nil : $0 },
            backup: backup(),
        )
    }
    
    
    /// The name of the LLM model that the bot uses, like `"smollm2"`
    static let llmName = Self("OLLAMA_MODEL", backup: "smollm2")
}



extension UnixEnvironmentKey where Value == String, Backup == Never {
    
    /// Your Telegram username, so the bot knows whether it's talking to its creator, like `"KyNorthstar"`
    static let creatorUsername: Self = "CREATOR_USERNAME"
}



// MARK: - URLs

private let defaultOllamaBaseUrl = URL(string: "http://localhost:11434")!



extension UnixEnvironmentKey where Value == URL?, Backup == URL {
    
    init(_ key: String, backup: @autoclosure @escaping BackupGeneratorFunction) {
        self.init(key, parse: URL.init(string:), backup: backup())
    }
    
    
    /// The base URL for the Ollama API, like `"http://localhost:11434"`
    static let ollamaBaseUrl = Self(
        "OLLAMA_BASE_URL",
        parse: URL.init(string:),
        backup: defaultOllamaBaseUrl,
    )
}
