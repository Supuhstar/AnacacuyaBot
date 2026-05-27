//
//  ExampleTool.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-22.
//

import Foundation

import SimpleLogging



public extension BotTool {
    
    /// An image generator that an LLM can call
    static var imageGenerator: Self {
        Self.init(
            definition: .init(
                name: "stablediffusion",
                description: "Generate an image using Stable Diffusion",
                parameters: .object(
                    properties: [
                        "prompt": .string(/*description: "A comma-separated list of image tags"*/),
                    ],
                    required: ["prompt"]
                )
            ),
            
            
            botDidUse: { arguments throws(BotToolError) in
                return .image(Data(base64Encoded: #"iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAQMAAAAlPW0iAAAABlBMVEXm5ubuOkm4L7csAAAAEElEQVQI12NABvwfsCMkAAC77Af5MImbTgAAAABJRU5ErkJggg=="#)!)
            },
        )
    }
}



private extension String {
    var fakeTemperature: Int {
        self.lazy
            .flatMap(\.unicodeScalars)
            .map(\.value)
            .map(Int.init)
            .reduce(into: 0, +=)
    }
    
    
    var fakeTemperature_formatted: String {
        (CGFloat(fakeTemperature) / 30).native.formatted(.number.precision(.fractionLength(1)))
    }
}
