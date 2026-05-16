//
//  ModelSettings.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-14.
//

import Foundation



public struct ModelSettings {
    
    /// Random seed used for reproducible outputs
    let seed: Int?
    
    /// Controls randomness in generation (higher = more random)
    let temperature: Float?
    
    /// Limits next token selection to the K most likely
    let top_k: Int?
    
    /// Cumulative probability threshold for nucleus sampling
    let top_p: Float?
    
    /// Minimum probability threshold for token selection
    let min_p: Float?
    
    /// Stop sequences that will halt generation
    let stop: String?
    
    /// Context length size (number of tokens)
    let num_ctx: Int?
    
    /// Maximum number of tokens to generate
    let num_predict: Int?
    
    
    init(
        seed: Int? = nil,
        temperature: Float? = nil,
        top_k: Int? = nil,
        top_p: Float? = nil,
        min_p: Float? = nil,
        stop: String? = nil,
        num_ctx: Int? = nil,
        num_predict: Int? = nil,
    ) {
        self.seed = seed
        self.temperature = temperature
        self.top_k = top_k
        self.top_p = top_p
        self.min_p = min_p
        self.stop = stop
        self.num_ctx = num_ctx
        self.num_predict = num_predict
    }
}



// MARK: - Conformances

extension ModelSettings: Codable {}
extension ModelSettings: Equatable {}
extension ModelSettings: Sendable {}
