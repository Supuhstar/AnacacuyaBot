//
//  Ollama + chat.swift
//  AnacacuyaBot
//
//  Created by Ky directing Claude 4.7 Opus on 2026-05-16.
//

import Foundation

import AsyncAlgorithms



public extension Ollama {
    
    /// Sends a multi-turn conversation to a model and waits for the model's next turn.
    ///
    /// Prefer this over ``generate(model:prompt:suffix:images:systemPrompt:think:raw:keepAlive:options:logProbabilities:top_logProbabilities:)``
    /// when the work has natural conversational shape — replies in a chat, tool use,
    /// anything where role separation (`system` / `user` / `assistant`) carries
    /// semantic weight. Small models in particular tend to behave better with chat
    /// shaping than with hand-rolled prompts shoved through `generate`.
    ///
    /// Tools live alongside messages because they're a property of the conversation
    /// being conducted, not of the model. A tool-capable model asked without tools
    /// will simply not propose any; an incapable model asked with tools will ignore
    /// them. The capability check, if you care to make it, belongs at the call site.
    ///
    /// - Parameters:
    ///   - model:                The model to run.
    ///   - messages:             The conversation so far, oldest to newest. This will act as the context for the model's inferrence.
    ///   - tools:                _optional_ - Functions the model is permitted to call.
    ///   - options:              _optional_ - Per-call model parameter overrides.
    ///   - think:                _optional_ - Reasoning budget, for reasoning-capable models.
    ///                           Specifying this to a model that doesn't declare the `thinking` capability will likely be silently ignored.
    ///   - keepAlive:            _optional_ - How long the model should remain loaded after this request.
    ///                           `nil` defers to Ollama's default (~5 minutes).
    ///   - logProbabilities:     _optional_ - Pass `true` to receive per-token log probabilities in the response.
    ///   - top_logProbabilities: _optional_ - Number of top alternative tokens to report log probabilities for, alongside the chosen token.
    ///
    /// - Returns: The model's reply plus performance telemetry.
    func chat(
        model: OllamaModel,
        messages: [OllamaMessage],
        tools: [OllamaTool]? = nil,
        options: OllamaModelOptions? = nil,
        think: OllamaThinking? = nil,
        keepAlive: Duration? = nil,
        logProbabilities: Bool? = nil,
        top_logProbabilities: Int? = nil,
    ) async throws -> OllamaChatResponse {
        try await post(to: "chat",
            OllamaChatRequest(
                model: model.name,
                messages: messages,
                tools: tools,
                options: options,
                think: think,
                keepAlive: keepAlive.map { "\($0.seconds)" },
                logprobs: logProbabilities,
                topLogprobs: top_logProbabilities,
            )
        )
    }
}



/// Request body for `/api/chat`.
///
/// `stream` is hardcoded to `false` because this current Swift code assumes a single response object per request.
///
/// `logprobs` and `topLogprobs` use those spellings rather than `logProbabilities`
/// to match Ollama's wire format precisely. The `convertToSnakeCase` strategy
/// transforms `topLogprobs` to `top_logprobs`, which is exactly what Ollama
/// expects; the longer Swift-idiomatic spellings would have produced
/// `log_probabilities` and `top_log_probabilities`, neither of which Ollama
/// recognizes.
private struct OllamaChatRequest: OllamaRequest {
    
    /// Model name
    let model: ModelName
    
    /// Chat history as an array of message objects
    let messages: [OllamaMessage]
    
    /// Optional list of function tools the model may call during the chat
    let tools: [OllamaTool]?
    
    /// Runtime options that control text generation
    let options: OllamaModelOptions?
    
    let stream = false
    
    /// When true, returns separate thinking output in addition to content
    let think: OllamaThinking?
    
    /// Model keep-alive duration (for example `"5m"`, or `"0"` to unload immediately)
    let keepAlive: String?
    
    /// Whether to return log probabilities of the output tokens
    let logprobs: Bool?
    
    /// Number of most-likely tokens to return at each token position when `logprobs` are enabled
    let topLogprobs: Int?
}



// MARK: - Deduped

public extension Ollama {
    
    /// Convenience over ``chat(model:messages:tools:options:think:keepAlive:logProbabilities:top_logProbabilities:)``
    /// that takes our `ChatMessage` type directly and returns just the assistant's
    /// reply text.
    ///
    /// The conversion to `OllamaMessage` happens here so call sites stay terse — the
    /// bot deals in `ChatMessage` throughout its history pipeline, and forcing every
    /// LLM call to map manually would be noisy. Where you want the full response
    /// telemetry, reach for the primary chat method instead.
    func chat(
        with model: OllamaModel,
        context: [ChatMessage],
        tools: [OllamaTool]?,
        settings: OllamaModelOptions?,
    ) async throws -> String {
        try await chat(
            with: model,
            context: await context.async.map(OllamaMessage.init).collect(),
            tools: tools,
            settings: settings,
        )
    }
    
    
    /// Convenience that handles the LLM call and pulls just the reply text out.
    func chat(
        with model: OllamaModel,
        context: [OllamaMessage],
        tools: [OllamaTool]?,
        settings: OllamaModelOptions?,
    ) async throws -> String {
        try await self.chat(
            model: model,
            messages: context,
            tools: tools,
            options: settings,
        )
        .message
        .content
    }
}



/// What `/api/chat` returns when `stream: false` — the complete reply in one
/// response. Fields after `message` are performance telemetry whose presence
/// depends on what Ollama elected to report; nullable across the board.
public struct OllamaChatResponse: OllamaResponse {
    
    /// Model name used to generate this message
    let model: String
    
    /// Timestamp of response creation
    let createdAt: Date
    
    let message: OllamaMessage
    
    /// Indicates whether the chat response has finished
    let done: Bool?
    
    /// Reason the response finished
    let doneReason: String?
    
    /// Total time spent generating
    let totalDuration: Duration?
    
    /// Time spent loading the model
    let loadDuration: Duration?
    
    /// Number of tokens in the prompt
    let promptEvalCount: Int?
    
    /// Time spent evaluating the prompt
    let promptEvalDuration: Duration?
    
    /// Number of tokens generated in the response
    let evalCount: Int?
    
    /// Time spent generating tokens
    let evalDuration: Duration?
    
    /// Log probability information for the generated tokens when `logprobs` are enabled
    let logProbabilities: [OllamaLogProbability]?
}



extension OllamaChatResponse {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model     = try container.decode(String.self, forKey: .model)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.message   = try container.decode(OllamaMessage.self, forKey: .message)
        
        self.done =               try container.decodeIfPresent(Bool.self, forKey: .done)
        self.doneReason =         try container.decodeIfPresent(String.self, forKey: .doneReason)
        self.totalDuration =      try container.decodeIfPresent(Int.self, forKey: .totalDuration).map{.nanoseconds($0)}
        self.loadDuration =       try container.decodeIfPresent(Int.self, forKey: .loadDuration).map{.nanoseconds($0)}
        self.promptEvalCount =    try container.decodeIfPresent(Int.self, forKey: .promptEvalCount)
        self.promptEvalDuration = try container.decodeIfPresent(Int.self, forKey: .promptEvalDuration).map{.nanoseconds($0)}
        self.evalCount =          try container.decodeIfPresent(Int.self, forKey: .evalCount)
        self.evalDuration =       try container.decodeIfPresent(Int.self, forKey: .evalDuration).map{.nanoseconds($0)}
        self.logProbabilities =   try container.decodeIfPresent([OllamaLogProbability].self, forKey: .logProbabilities)
    }
    
    
    
    enum CodingKeys: String, CodingKey {
        case model
        case createdAt
        case message
        case done
        case doneReason
        case totalDuration
        case loadDuration
        case promptEvalCount
        case promptEvalDuration
        case evalCount
        case evalDuration
        case logProbabilities
    }
}
