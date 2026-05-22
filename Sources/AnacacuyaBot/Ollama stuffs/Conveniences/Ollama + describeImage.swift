//
//  Ollama + describeImage.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-19.
//

import Foundation



public extension Ollama {
    
    /// Asks the given machine-vision model to describe the given image
    ///
    /// - Parameters:
    ///   - rawImageData: The image's raw bytes
    ///   - model:        A machine-vision model. If you pass a model which doesn't explicitly declare it supports machine-vision, this function throws an error and doesn't attempt to describe the image.
    ///
    /// - Returns: Whatever the model says about the image.
    func describe(image rawImageData: Data, using model: OllamaModel) async throws -> String {
        guard true == model.capabilities?.contains(.vision) else {
            throw ImageDescriptionError.modelCannotSeeImages
        }
        
        return try await chat(model: model, messages: [
            OllamaMessage(role: .system, content: """
            You are an image description service. You are given an image, and all you do is describe what you see in that image.
            """),
            
            OllamaMessage(role: .user, content: "Please describe this image:", images: [rawImageData])
        ])
        .message
        .content
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    
    
    enum ImageDescriptionError: Error {
        case modelCannotSeeImages
    }
}
