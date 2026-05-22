//
//  OLLAMA_VISION_MODEL.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



extension UnixEnvironmentKey where Value == ModelName, Backup == Never {
    
    /// The name of the separate vision model that the bot uses, like `"moondream"`
    static let visionModelName: Self = "OLLAMA_VISION_MODEL"
}
