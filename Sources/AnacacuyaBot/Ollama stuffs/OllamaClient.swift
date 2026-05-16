//
//  OllamaClient.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation
#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

import SemVer



extension OllamaClient {
//    private let chatUrl: URL
//    private let mutex = Mutex()
//    let model: String
//    
//    
//    init(baseURL: URL, model: String) {
//        self.model = model
//        self.chatUrl = baseURL.appending(path: "api/chat") //URL(string: "\(baseURL)/api/chat")!
//    }
    
    
    nonisolated func chat(context: [ChatMessage], settings: ModelSettings?) async throws -> String {
        try await chat(context: context.map(OllamaMessage.init),
                       settings: settings)
    }
    
    
    nonisolated func chat(
        with model: OllamaModel,
        context: [OllamaMessage],
        settings: ModelSettings?,
    ) async throws -> String {
        try await mutex.run {
            struct Body: Encodable {
                let model: String
                let messages: [OllamaMessage]
                let options: ModelSettings?
                let stream: Bool
            }
            
            
            
            struct Response: Decodable {
                let message: Body
                
                
                
                struct Body: Decodable {
                    let content: String
                }
            }
            
            
            
            async let context = context
                .reversed()
                .withoutDuplicates(equatingBy: { lhs, rhs in
                    lhs.content == rhs.content
                })
                .reversed()
            
            
            return try await self.chat(
                model: model,
                messages: Array(await context),
                options: settings,
            )
            .messages
            .first?
            .content
            ?? ""
        }
    }
}



//struct OllamaMessage: Codable, Sendable, Equatable {
//    let role: ChatMessage.Role
//    let content: String
//}



extension OllamaMessage {
    init(_ chatMessage: ChatMessage) {
        self.init(role: chatMessage.role, content: chatMessage.contentForLlm)
    }
}


actor OllamaClient {
    private let baseUrl: URL
    private let mutex = Mutex()
    
    
    func generate(
        model: OllamaModel,
        prompt: String,
        suffix: String? = nil,
        images: [Data]? = nil,
        format: OllamaFormat? = nil,
        systemPrompt: String? = nil,
        think: OllamaThinking? = nil,
        raw: Bool? = nil,
        keepAlive: Duration? = nil,
        option: ModelSettings? = nil,
        logProbabilities: Bool? = nil,
        top_logProbabilities: Int? = nil,
    ) async throws -> OllamaGenerateResponse {
        // ...
    }
    
    
    func chat(
        model: OllamaModel,
        messages: [OllamaMessage],
        tools: [OllamaTool]? = nil,
        options: ModelSettings? = nil,
        think: OllamaThinking? = nil,
        keepAlive: Duration? = nil,
        logProbabilities: Bool? = nil,
        top_logProbabilities: Int? = nil,
    ) async throws -> OllamaChatResponse {
        // ...
    }
    
    
    func embed(
        model: OllamaModel,
        input: [String],
        truncate: Bool? = nil,
        dimensions: Int? = nil,
        keepAlive: Duration? = nil,
        options: ModelSettings? = nil,
    ) async throws -> OllamaEmbedResponse {
        // ...
    }
    
    
    func listModels(
        _ modelCollection: OllamaModelCollection,
    ) async throws -> OllamaListModelsResponse {
        // ...
    }
    
    
    func modelDetails(
        modelName: String,
        verbose: Bool? = nil,
    ) async throws -> OllamaModelDetailsResponse {
        // ...
    }
    
    
    func createModel(
        named model: String,
        from existingModel: String? = nil,
        templatePrompt: String? = nil,
        license: [String]? = nil,
        systemPrompt: String? = nil,
        parameters: [String : Codable]? = nil,
        messages: [OllamaMessage]? = nil,
        quantize: String? = nil,
    ) async throws -> OllamaStatusOnlyResponse {
        // ...
    }
    
    
    func copyModel(
        source: OllamaModel,
        destinationName: String,
    ) async throws {
        // ...
    }
    
    
    func pullModel(
        named model: String,
    ) async throws -> OllamaStatusOnlyResponse {
        try await post(to: "pull",
            ["model": model],
        )
    }
    
    
    func pushModel(
        _ model: OllamaModel,
    ) async throws -> OllamaStatusOnlyResponse {
        // ...
    }
    
    
    func deleteModel(
        _ model: OllamaModel,
    ) async throws {
        // ...
    }
    
    
    var version: SemVer {
        get async throws {
            // ...
        }
    }
}

private extension OllamaClient {
    func endpoint(_ name: String) -> URL {
        self.baseUrl.appending(path: "api/\(name)")
    }
    
    
    func post<Body: Encodable, Response: Decodable>(
        to endpointName: String,
        _ body: Body,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
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



struct OllamaModel {
    let name: String
    let capabilities: [ModelCapability]
}

enum OllamaFormat {
    case json
    case jsonSchema(JsonSchema)
}

enum OllamaThinking {
    case off
    case auto
    case low
    case medium
    case high
}

extension OllamaThinking: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: BooleanLiteralType) {
        switch value {
        case true:
            self = .auto
        case false:
            self = .off
        }
    }
}

struct OllamaTool {
    let type: Kind
    let function: Function
}

extension OllamaTool {
    enum Kind {
        case function
    }
    
    struct Function {
        let name: String
        let parameters: [JsonSchema]
        let description: String
    }
}

enum OllamaModelCollection {
    case all
    case currentlyRunning
}



struct OllamaGenerateResponse: Decodable, Sendable {
    let model: String
    let createdAt: Date
    let response: String
    let thinking: String?
    let done: Bool
    let doneReason: String?
    let totalDuration: Duration?
    let loadDuration: Duration?
    let promptEvalCount: Int?
    let promptEvalDuration: Duration?
    let evalCount: Int?
    let evalDuration: Duration?
    let logProbabilities: [OllamaLogProbability]?
}

struct OllamaLogProbability {
    let token: String
    let logProbability: Double
    let bytes: Data
    let topLogProbabilities: [OllamaTopLogProbability]
}

struct OllamaTopLogProbability {
    let token: String
    let logProbability: Double
    let bytes: Data
}

struct OllamaChatResponse {
    let model: String
    let createdAt: Date
    let messages: [OllamaMessage]
    let done: Bool
    let doneReason: String?
    let totalDuration: Duration?
    let loadDuration: Duration?
    let promptEvalCount: Int?
    let promptEvalDuration: Duration?
    let evalCount: Int?
    let evalDuration: Duration?
    let logProbabilities: [OllamaLogProbability]?
}

struct OllamaMessage: Sendable {
    let role: ChatMessage.Role
    let content: String
    let thinking: String?
    let toolCalls: [OllamaToolCall]?
    let images: [Data]?
}

struct OllamaToolCall {
    let function: Function
}

extension OllamaToolCall {
    struct Function {
        let name: String
        let description: String?
        let arguments: [String : Codable]
    }
}

struct OllamaEmbedResponse {
    let model: String?
    let embeddings: [[Double]]?
    let totalDuration: Duration?
    let loadDuration: Duration?
    let promptEvalCount: Int?
}

struct OllamaListModelsResponse {
    let models: [Model]?
}

extension OllamaListModelsResponse {
    struct Model {
        let name: String?
        let model: String?
        let remoteModel: String?
        let remoteHost: String?
        let modifiedAt: Date?
        let size: Int?
        let digest: String?
        let details: Details?
        let expiresAt: Date?
        let sizeVram: Int?
        let contextLength: Int?
    }
}

extension OllamaListModelsResponse.Model {
    struct Details {
        let parentModel: String?
        let format: String?
        let family: String?
        let families: [String]?
        let parameterSize: String?
        let quantizationLevels: String?
    }
}

struct OllamaModelDetailsResponse {
    let parameters: String?
    let license: String?
    let modifiedAt: Date??
    let details: OllamaListModelsResponse.Model.Details?
    let template: String?
    let capabilities: [ModelCapability]?
    let modelInfo: [String : Codable]?
}

enum ModelCapability {
    case completion
    case thinking
    case vision
    case other(String)
}

struct OllamaStatusOnlyResponse: Decodable {
    let status: String?
}
