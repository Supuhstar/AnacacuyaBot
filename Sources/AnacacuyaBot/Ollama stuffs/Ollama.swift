//
//  Ollama.swift
//  AnacacuyaBot
//
//  Made by Ky 2026-05-07.
//  Minor assistance provided by Claude 4.7 Opus.
//

import Foundation
#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

import SemVer


/// Encapsulates our interactions with the Ollama server.
///
/// This ensures that requests are serialized (no stepping on toes)
///
/// Claude had this to say about the two concerns which motivated my choice to make this:
///
/// 1. Operational: a single loaded model can field only one inference at a time before quality degrades or the runtime juggles weights out of VRAM. Concurrent calls don't fail loudly — they degrade quietly. The serial queue inside this type makes that constraint a property of the system rather than a discipline every call site must remember.
/// 2. Architectural: keeping the HTTP plumbing — URL composition, encoding strategy, timeouts, error surfacing — in one file means tuning any of those is a localized change. The endpoint files in `Endpoints/` know only about their own request and response shapes; nothing about transport leaks into them.
public final actor Ollama {
    
    /// Root URL of the Ollama server, like `http://localhost:11434
    private let baseUrl: URL
    
    /// Serializes outbound HTTP work to Ollama.
    ///
    /// Ollama itself queues requests internally when a model is loaded. Here we choose to guarantee that queuing so we can know _why_ we're waiting (Is it just the queue? Or is the server stalled? etc.).
    ///
    /// This also guarantees the order of requests, which matters for endpoints whose responses describe state mutations (e.g. `create`, `delete`, `copy`).
    private let serverCommunicationSerialQueue = Mutex()
    
    
    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }
}



// MARK: - "Private" utilities

internal extension Ollama {
    
    /// Composes the URL for a named API endpoint relative to the configured base URL.
    /// 
    /// - Parameter name: Just the endpoint name.
    ///                   For example, if you want to send a request to `http://localhost:11434/api/chat`, just pass `"chat"`.
    private func endpoint(_ name: String) -> URL {
        self.baseUrl.appending(path: "api/\(name)")
    }
    
    
    /// POSTs the given body to the named Ollama endpoint and decodes the JSON response.
    /// 
    /// For side-effecting endpoints whose success is signaled by HTTP status alone (no body in response), use the void-returning overload instead.
    /// 
    /// - Parameters:
    ///   - endpointName: Just the endpoint name.
    ///                   For example, if you want to send a request to `http://localhost:11434/api/chat`, just pass `"chat"`.
    ///   - body:         The object to POST in JSON form.
    ///   - timeout:      _optional_ - Only specify this when making a requst which you _know_ can take a notably longer time than the global timeout limit, such as pulling a new model. This overrides that, even if this is shorter.
    /// 
    /// - Returns: The parsed JSON response from the server.
    func post<Body: OllamaRequest, Response: OllamaResponse>(
        to endpointName: String,
        _ body: Body,
        timeout: Duration? = nil,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try await serverCommunicationSerialQueue.run {
            try await endpoint(endpointName)
                .post(
                    body,
                    timeout: timeout ?? Limits.maxTimeToWaitForModelResponse,
                    keyEncodingStrategy: .convertToSnakeCase,
                    keyDecodingStrategy: .convertFromSnakeCase,
                    receiving: Response.self,
                )
        }
    }
    
    
    /// POSTs the given body to the named Ollama endpoint, discarding whatever the server returns.
    ///
    /// This is for endpoints (e.g. `copy` or `delete`) which succeed silently with an empty response body.
    ///
    /// This doesn't attempt to parse a response body, so a 200 OK with empty body resolves correctly and returns silently, but a 404 (for example) still throws an error.
    ///
    /// - Parameters:
    ///   - endpointName: Just the endpoint name.
    ///                   For example, if you want to send a request to `http://localhost:11434/api/chat`, just pass `"chat"`.
    ///   - body:         The object to POST in JSON form.
    func post<Body: OllamaRequest>(
        to endpointName: String,
        _ body: Body,
    ) async throws {
        try await serverCommunicationSerialQueue.run {
            try await endpoint(endpointName).post(
                body,
                timeout: Limits.maxTimeToWaitForModelResponse,
                keyEncodingStrategy: .convertToSnakeCase,
            )
        }
    }
    
    
    /// GETs and JSON-decodes a response from the named Ollama endpoint.
    ///
    /// Ollama uses GET only for bodyless requests about server-wide state, like listing models and reporting its version.
    ///
    /// Anything that touches a specific model is POST, even when conceptually a "read", because the request has to carry the model name in its body, and Ollama doesn't currently use URL query parameters.
    ///
    /// - Parameters:
    ///   - endpointName: Just the endpoint name.
    ///                   For example, if you want to send a request to `http://localhost:11434/api/version`, just pass `"version"`.
    func get<Response: OllamaResponse>(
        from endpointName: String,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try await serverCommunicationSerialQueue.run {
            try await endpoint(endpointName).get(
                timeout: Limits.maxTimeToWaitForModelResponse,
                keyDecodingStrategy: .convertFromSnakeCase,
                receiving: Response.self,
            )
        }
    }
    
    
    /// Sends a DELETE request with a JSON body to the named Ollama endpoint.
    ///
    /// - Parameters:
    ///   - endpointName: Just the endpoint name.
    ///                   For example, if you want to send a request to `http://localhost:11434/api/delete`, just pass `"delete"`.
    ///   - body:         The object to DELETE in JSON form.
    func delete<Body: OllamaRequest>(
        from endpointName: String,
        _ body: Body,
    ) async throws {
        try await serverCommunicationSerialQueue.run {
            try await endpoint(endpointName).delete(
                body,
                timeout: Limits.maxTimeToWaitForModelResponse,
                keyEncodingStrategy: .convertToSnakeCase,
            )
        }
    }
}



// MARK: - IO protocols

/// Appears in either direction of an Ollama exchange: both encoded into requests and decoded from responses.
///
/// Used for payloads that are symmetric, like `OllamaMessage`, which travels into chat requests and back out as the assistant's reply.
public typealias OllamaTranceivable = Codable & Sendable & Equatable

/// Appears only in requests we send to Ollama.
///
/// Used for payloads that are one-way sent to Ollama, like ``OllamaModelOptions``, which are sent but never received.
public typealias OllamaRequest = Encodable & Sendable & Equatable

/// Appears only in responses we receive from Ollama.
///
/// Used for payloads that are one-way received from Ollama, like ``OllamaChatresponse``, which are received but never sent.
public typealias OllamaResponse = Decodable & Sendable & Equatable
