//
//  OllamaLogProbability.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//

import Foundation



public struct OllamaLogProbability: OllamaResponse {
    let token: String
    let logProbability: Double
    let bytes: Data
    let topLogProbabilities: [OllamaTopLogProbability]
}



public struct OllamaTopLogProbability: OllamaResponse {
    let token: String
    let logProbability: Double
    let bytes: Data
}
