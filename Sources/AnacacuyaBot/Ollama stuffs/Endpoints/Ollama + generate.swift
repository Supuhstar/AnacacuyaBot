//
//  Ollama + generate.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public extension Ollama {
    
    /// Sends a single prompt to a model and waits for a single completion.
    ///
    /// Pick this when you need text-in/text-out without conversation context — OCR
    /// extraction from an image, one-shot classification, prompt-engineered question
    /// answering. For multi-turn dialogue, reach for
    /// ``chat(model:messages:tools:options:think:keepAlive:logProbabilities:top_logProbabilities:)``
    /// instead; it gives the model proper role separation that small models in
    /// particular tend to handle better.
    ///
    /// Images are passed as raw `Data` and JSON-encoded as base64 strings on the way
    /// out — `JSONEncoder`'s default `dataEncodingStrategy`. Models without the
    /// `vision` capability will accept the request and silently ignore the images,
    /// which is a quiet failure mode worth guarding against at the call site by
    /// checking `model.capabilities` first.
    ///
    /// - Parameters:
    ///   - model:                The model to run.
    ///   - prompt:               The user-facing prompt.
    ///   - suffix:               _optional_ - Text to append after the model's completion.
    ///                           Useful for fill-in-the-middle workflows; most callers leave it `nil`.
    ///   - images:               _optional_ - Images to attach. Each entry is the raw bytes of an image file.
    ///                           Only meaningful for models with the `vision` capability.
    ///   - systemPrompt:         _optional_ -  Override for the model's baked-in system prompt.
    ///   - think:                _optional_ - Reasoning budget, for reasoning-capable models.
    ///                           Specifying this to a model that doesn't declare the `thinking` capability will likely be silently ignored.
    ///   - raw:                  _optional_ - Pass `true` to disable Ollama's template wrapping (the prompt goes to the model verbatim).
    ///                           Useful when you are formatting the prompt yourself to match a model's expected chat template.
    ///   - keepAlive:            _optional_ - How long the model should remain loaded after this request.
    ///                           `nil` defers to Ollama's default (~5 minutes).
    ///   - options:              _optional_ - Per-call model parameter overrides.
    ///   - logProbabilities:     _optional_ - Pass `true` to receive per-token log probabilities in the response.
    ///   - top_logProbabilities: _optional_ - Number of top alternative tokens to report log probabilities for, alongside the chosen token.
    ///
    /// - Returns: The model's completion, plus performance telemetry and (if requested)
    ///            log probabilities.
    func generate(
        model: OllamaModel,
        prompt: String,
        suffix: String? = nil,
        images: [Data]? = nil,
        systemPrompt: String? = nil,
        think: OllamaThinking? = nil,
        raw: Bool? = nil,
        keepAlive: Duration? = nil,
        options: OllamaModelOptions? = nil,
        logProbabilities: Bool? = nil,
        top_logProbabilities: Int? = nil,
    ) async throws -> OllamaGenerateResponse {
        try await post(to: "generate",
            OllamaGenerateRequest(
                model: model.name,
                prompt: prompt,
                suffix: suffix,
                images: images,
                system: systemPrompt,
                think: think,
                raw: raw,
                keepAlive: keepAlive.map { "\($0.seconds)" },
                options: options,
                logprobs: logProbabilities,
                topLogprobs: top_logProbabilities,
            )
        )
    }
}



/// Request body for `/api/generate`.
///
/// `stream` is hardcoded to `false` because this current Swift code assumes a single response object per request.
///
/// `logprobs` and `topLogprobs` use those spellings rather than the more
/// Swift-idiomatic `logProbabilities` to match Ollama's wire format precisely.
/// See the note in `Ollama + chat.swift` for the rationale.
private struct OllamaGenerateRequest: OllamaRequest {
    
    /// Model name
    let model: ModelName
    
    /// Text for the model to generate a response from
    let prompt: String
    
    /// Used for fill-in-the-middle models, text that appears after the user prompt and before the model response
    let suffix: String?
    
    /// Images for models that support image input
    let images: [Data]?
    
    /// System prompt for th emodel to generate a response from
    let system: String?
    
    /// When true, returns a stream of partial responses
    let stream = false
    
    /// When non-nil and not `.off`, returns separate thinking output in addition to context
    let think: OllamaThinking?
    
    /// When `true`, returns the raw response from the model without any prompt templating
    let raw: Bool?
    
    /// Model keep-alive duration (for example `"5m"`, or `"0"` to unload immediately)
    let keepAlive: String?
    
    /// Runtime options that control text generation
    let options: OllamaModelOptions?
    
    /// Whether to return log probabilities of the output tokens
    let logprobs: Bool?
    
    /// Number of most-likely tokens to return at each token position when `logprobs` are enabled
    let topLogprobs: Int?
}



/// What `/api/generate` returns when `stream: false`. See the Ollama documentation
/// for field-level semantics; the structure here is a faithful mirror that surfaces
/// all of it as typed Swift values.
public struct OllamaGenerateResponse: OllamaResponse {
    
    /// Model name
    let model: String
    
    /// Timestamp of response creation
    let createdAt: Date
    
    /// The model's generated text response
    let response: String
    
    /// The model's generated thinking output
    let thinking: String?
    
    /// Indicates whether generation has finished
    let done: Bool
    
    /// Reason the generation stopped
    let doneReason: String?
    
    /// Time spent generating the response in nanoseconds
    let totalDuration: Duration?
    
    /// Time spent loading the model
    let loadDuration: Duration?
    
    /// Number of output tokens generated in the response
    let promptEvalCount: Int?
    
    /// Time spent generating tokens
    let promptEvalDuration: Duration?
    
    /// Number of output tokens generated in the response
    let evalCount: Int?
    
    /// Time spent generating tokens in nanoseconds
    let evalDuration: Duration?
    
    /// Log probability information for the generated tokens when `logprobs` are enabled
    let logprobs: [OllamaLogProbability]?
}
