//
//  TelegramClient.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation
#if os(Linux) || os(Windows)
import FoundationNetworking
#endif
import RegexBuilder

import SerializationTools
import SimpleLogging



private let keyDecodingStrategy = JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase
private let keyEncodingStrategy = JSONEncoder.KeyEncodingStrategy.convertToSnakeCase



/// Routes every conversation our process has with Telegram's Bot API through
/// one place.
///
/// The actor encapsulates two pieces of mutable state — the update offset and
/// the bot's identity — and centralizes URL composition, JSON
/// encoding/decoding, and error normalization for every outbound call. The
/// shape is deliberately less ambitious than the Ollama side: there are only
/// a handful of methods this bot uses, and the overhead of a per-endpoint
/// architecture wouldn't earn its keep here. If the surface grows, the
/// helpers are sized to be split out into endpoint files without rewriting
/// the methods that use them.
actor TelegramClient {
    
    /// Base URL for Bot API calls — every method composes its full URL by
    /// appending the method name. The token is baked in.
    private let base: String
    
    /// Base URL for file downloads, which uses a different prefix than Bot API
    /// calls and a path suffix from `TGFile.filePath`. Stored separately rather
    /// than computed because both prefixes share the token but otherwise look
    /// nothing alike.
    private let fileBase: String
    
    /// Cursor into Telegram's update stream. After each `getUpdates` call, the
    /// highest `updateId` seen is acknowledged by passing `offset = highest + 1`
    /// on the next call; lower values would replay updates already handled.
    private var offset: Int = 0
    
    
    init(token: TelegramBotToken) {
        let raw = token.withoutTypeSafety()
        let base = "https://api.telegram.org/bot\(raw)"
        let fileBase = "https://api.telegram.org/file/bot\(raw)"
        
        self.base = base
        self.fileBase = fileBase
    }
}



// MARK: - API

extension TelegramClient {
    
    /// Retrieves the Telegram user account that the bot is operating within.
    ///
    /// This should always work as long as our token is correct. If this fails, that means we are unable to connect to Telegram's servers or the token is invalid.
    func getMe() async throws -> TGUser {
        try await self.get("getMe")
    }
    
    
    /// Receives the next batch of updates from Telegram's long-polling stream.
    ///
    /// Internally advances the update cursor as a side effect of a successful
    /// call. A failure leaves the cursor unchanged, so the same batch will be
    /// re-delivered on retry — which is the desired behavior, since updates
    /// stay buffered server-side for up to 24 hours.
    ///
    /// - Returns: Zero or more updates, oldest first.
    func getUpdates() async throws -> [TGUpdate] {
        let updates: [TGUpdate] = try await get(
            "getUpdates",
            queryItems: [
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "timeout", value: "\(Int(Limits.maxTimeToWaitForNewTelegramMessages.timeInterval))"),
                URLQueryItem(name: "allowed_updates", value: #"["message"]"#),
            ]
        )
        
        if let last = updates.last {
            offset = last.updateId + 1
        }
        return updates
    }
    
    
    /// Sends a text message to a chat, optionally as a reply to another message.
    ///
    /// Suppresses the send entirely when `text` is empty or matches the
    /// "no-response" regex — the LLM's signal that it has nothing to say. The
    /// silent return is intentional: callers should be able to forward whatever
    /// the model produced without filtering for these cases at every call site.
    ///
    /// - Parameters:
    ///   - chatId:    Identifier for the destination chat.
    ///   - text:      Message text, up to 4096 characters.
    ///   - inReplyTo: Identifier of the message being replied to. Nil for a
    ///                fresh top-level send.
    func sendMessage(chatId: Int64, text: String, inReplyTo: Int? = nil) async throws {
        guard text.isNotEmpty
              || (text.matches(noResponseRegex))
        else {
            log(info: "🙊 (chose to say nothing)")
            return
        }
        
        log(info: "🗣️\(nil == inReplyTo ? "🤖" : "👩🏽‍💻"): \(text)")
        
        let _: TGMessage = try await post(
            "sendMessage",
            TGSendMessageBody(
                chatId: chatId,
                text: text,
                replyToMessageId: inReplyTo,
                parseMode: .markdown
            )
        )
    }
    
    
    /// Fetches metadata for a file the bot has access to, including the path
    /// component needed to download it.
    ///
    /// The returned `filePath` is time-limited — Telegram's documentation
    /// guarantees at least 1 hour of validity. After that, re-issue `getFile`
    /// to refresh. For the common case of "I want the bytes right now",
    /// ``downloadFile(_:)-(TGFile)`` and ``downloadFile(_:)-(String)`` do both
    /// steps in one call.
    ///
    /// Source: https://core.telegram.org/bots/api#getfile
    ///
    /// - Parameter fileId: The `fileId` from a `TGPhotoSize`, document, etc.
    ///
    /// - Returns: A `TGFile` carrying the path needed for download, plus
    ///            available metadata.
    func getFile(fileId: String) async throws -> TGFile {
        struct Body: Encodable {
            let fileId: String
        }
        
        return try await post("getFile", Body(fileId: fileId))
    }
    
    
    /// Downloads the bytes of a file the bot has already resolved via `getFile`.
    ///
    /// Separate from `getFile` because the two requests hit different URL
    /// prefixes, return different content types (JSON envelope vs. raw bytes),
    /// and have meaningfully different failure modes — keeping them split lets
    /// each one stay simple. The convenience overload below combines them when
    /// callers don't care about the intermediate file metadata.
    ///
    /// - Parameter file: A `TGFile` previously returned by `getFile`. Must have
    ///                   a non-nil `filePath`; otherwise the file isn't
    ///                   currently retrievable.
    ///
    /// - Returns: The raw file bytes, suitable to hand off to a vision model
    ///            or write to disk.
    func downloadFile(_ file: TGFile) async throws -> Data {
        guard let filePath = file.filePath else {
            throw TelegramHttpError.downloadFailed(
                fileId: file.fileId,
                reason: "Telegram returned no filePath for this file."
            )
        }
        
        let url = URL(string: "\(fileBase)/\(filePath)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse,
           false == (200..<300).contains(httpResponse.statusCode)
        {
            throw TelegramHttpError.downloadFailed(
                fileId: file.fileId,
                reason: "HTTP \(httpResponse.statusCode)"
            )
        }
        
        return data
    }
    
    
    /// Fetches a file's metadata and downloads its bytes in one step.
    ///
    /// Convenience for the common case where the caller has a `fileId` and
    /// wants the bytes. Use the two-step form (``getFile(fileId:)`` plus
    /// ``downloadFile(_:)-(TGFile)``) when you need to inspect or cache the
    /// metadata between calls.
    ///
    /// - Parameter fileId: The `fileId` from a `TGPhotoSize`, document, etc.
    ///
    /// - Returns: The raw file bytes.
    func downloadFile(fileId: String) async throws -> Data {
        let file = try await getFile(fileId: fileId)
        return try await downloadFile(file)
    }
}



// MARK: - HTTP helpers

private extension TelegramClient {
    
    /// Issues a GET to the named Bot API method, decodes the standard envelope,
    /// and returns the unwrapped result.
    ///
    /// Use this for methods whose parameters fit naturally into a query string —
    /// `getUpdates`, methods with a handful of simple scalars. Methods with
    /// structured bodies should use ``post(_:_:)`` instead.
    ///
    /// - Parameters:
    ///   - endpoint:     The Bot API method name (e.g. `"getUpdates"`).
    ///   - queryItems: Parameters as query string entries. Default empty.
    ///
    /// - Returns: The result payload unwrapped from Telegram's `{ok, result}`
    ///            envelope. Throws if the envelope's `ok` is false or the
    ///            payload can't be decoded.
    func get<Response: Decodable & Sendable>(
        _ endpoint: String,
        queryItems: [URLQueryItem] = [],
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        var comps = URLComponents(string: "\(base)/\(endpoint)")!
        if false == queryItems.isEmpty {
            comps.queryItems = queryItems
        }
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try unwrap(data)
    }
    
    
    /// Issues a POST to the named Bot API method with a JSON body, decodes the
    /// standard envelope, and returns the unwrapped result.
    ///
    /// Use this for methods with structured request bodies — `sendMessage`,
    /// `getFile`, anything taking more than a couple of simple parameters.
    /// Methods with no body or only simple query parameters should use
    /// ``get(_:queryItems:receiving:)`` instead.
    ///
    /// - Parameters:
    ///   - endpoint: The Bot API endpoint name (e.g. `"sendMessage"`).
    ///   - body:     The request body, JSON-encoded with snake-case keys.
    ///
    /// - Returns: The result payload unwrapped from Telegram's `{ok, result}`
    ///            envelope. Throws if the envelope's `ok` is false or the
    ///            payload can't be decoded.
    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ endpoint: String,
        _ body: Body,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try unwrap(envelope: try await URL(string: "\(base)/\(endpoint)")!
            .post(
                body,
                timeout: .seconds(5), // Telegram is fast
                keyEncodingStrategy: .convertToSnakeCase,
                keyDecodingStrategy: .convertFromSnakeCase,
            )
        )
    }
    
    
    /// Decodes Telegram's `{ok, result}` envelope and returns the result, or
    /// throws a structured error if the envelope reports failure or won't
    /// parse at all.
    ///
    /// Shared between ``get(_:queryItems:receiving:)`` and ``post(_:_:receiving:)``
    /// so error handling stays in one place — every method gets the same
    /// thrown-error semantics regardless of HTTP verb.
    func unwrap<Response: Decodable & Sendable>(_ data: Data) throws -> Response {
        let envelope: TGResponse<Response>
        do {
            envelope = try TGResponse<Response>(jsonData: data, keyDecodingStrategy: keyDecodingStrategy)
        }
        catch {
            throw TelegramHttpError.responseDecodingFailed(data: data, underlying: error)
        }
        
        return try unwrap(envelope: envelope)
    }
    
    
    func unwrap<Response: Decodable & Sendable>(envelope: TGResponse<Response>) throws -> Response {
        guard envelope.ok, let result = envelope.result else {
            throw TelegramHttpError.apiError(
                code: envelope.errorCode,
                description: envelope.description
            )
        }
        return result
    }
}



// MARK: - Errors

/// What can go wrong when talking to Telegram.
///
/// Distinguishes between "we couldn't make sense of what Telegram sent us"
/// (`responseDecodingFailed`), "Telegram understood us but rejected the call"
/// (`apiError`), and "the file download itself didn't work" (`downloadFailed`).
/// Each carries enough context to be useful in logs without callers needing to
/// dig further.
enum TelegramHttpError: LocalizedError {
    
    /// Telegram returned bytes that didn't fit the expected JSON envelope. The
    /// raw data is preserved so logging can surface what actually came back —
    /// usually an HTML error page from an upstream proxy, or a Telegram API
    /// version mismatch.
    case responseDecodingFailed(data: Data, underlying: Error)
    
    /// Telegram returned a well-formed envelope with `ok: false`. The code and
    /// description are exactly what Telegram provided.
    case apiError(code: Int?, description: String?)
    
    /// A file download (from `api.telegram.org/file/...`) failed, either
    /// because `getFile` didn't provide a path or the HTTP fetch itself
    /// rejected.
    case downloadFailed(fileId: String, reason: String)
    
    
    var errorDescription: String? {
        switch self {
        case .responseDecodingFailed(let data, let underlying):
            let raw = String(data: data, encoding: .utf8) ?? "<not UTF-8>"
            return "Couldn't decode Telegram response: \(underlying). Raw: \(raw)"
            
        case .apiError(let code, let description):
            let codeText = code.map(String.init) ?? "?"
            return "Telegram API error \(codeText): \(description ?? "<no description>")"
            
        case .downloadFailed(let fileId, let reason):
            return "Couldn't download Telegram file \(fileId): \(reason)"
        }
    }
}



//unsafe: Unsure if there's a better way to do this. Pretty sure `Regex` is safe to be nonisolated anyway.
@safe
nonisolated(unsafe)
private let noResponseRegex = Regex {
        Anchor.startOfSubject
        ChoiceOf {
            bracketed("[", noResponseGeneratedString, "]")
            bracketed("{", noResponseGeneratedString, "}")
            bracketed("(", noResponseGeneratedString, ")")
        }
        ZeroOrMore(.whitespace)
        Optionally {
            "."
        }
        ZeroOrMore(.whitespace)
        Anchor.endOfSubject
    }
    .ignoresCase()



private func bracketed(_ opening: Character, _ body: String, _ closing: Character) -> Regex<(Substring, Substring)> {
    Regex {
        Capture {
            ChoiceOf {
                opening
                "\\\(opening)"
            }
            ZeroOrMore(.whitespace)
            body
            ZeroOrMore(.whitespace)
            ChoiceOf {
                closing
                "\\\(closing)"
            }
        }
    }
}
