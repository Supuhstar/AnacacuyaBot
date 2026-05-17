//
//  Ollama.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation
#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

import SemVer



/// Encapsulates our interactions with the Ollama
public final actor Ollama {
    private let baseUrl: URL
    private let serverCommunicationSerialQueue = Mutex()
    
    
    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }
}



// MARK: - "Private" utilities

internal extension Ollama {
    
    /// The URL for the given-named endpoint
    ///
    /// - Parameter name: The name of the endpoint.
    ///                   For example, `https://localhost:11434/api/chat` has the endpoint name `"chat"`
    private func endpoint(_ name: String) -> URL {
        self.baseUrl.appending(path: "api/\(name)")
    }
    
    
    /// POSTs the given body to the given Ollama API endpoint
    ///
    /// - Parameters:
    ///   - endpointName: The name of the endpoint.
    ///                   For example, `https://localhost:11434/api/chat` has the endpoint name `"chat"`
    ///   - body:         The object to POST in JSON form
    ///
    /// - Returns: The parsed JSON response from the server
    func post<Body: OllamaRequest, Response: OllamaResponse>(
        to endpointName: String,
        _ body: Body,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try await serverCommunicationSerialQueue.run {
            try await endpoint(endpointName)
                .post(
                    body,
                    timeout: Limits.maxTimeToWaitForModelResponse,
                    keyEncodingStrategy: .convertToSnakeCase,
                    keyDecodingStrategy: .convertFromSnakeCase,
                    receiving: Response.self,
                )
        }
    }
}



// MARK: - IO protocols

public typealias OllamaTranceivable = Codable & Sendable

public typealias OllamaRequest = Encodable & Sendable

public typealias OllamaResponse = Decodable & Sendable
