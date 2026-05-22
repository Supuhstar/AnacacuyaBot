//
//  OllamaStatusOnlyResponse.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



/// A response from requests which only return status updates
public struct OllamaStatusOnlyResponse: OllamaResponse {
    
    /// Current status message
    let status: String?
}
