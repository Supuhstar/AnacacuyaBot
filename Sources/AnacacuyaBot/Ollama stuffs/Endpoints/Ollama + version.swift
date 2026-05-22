//
//  Ollama + version.swift
//  AnacacuyaBot
//
//  Created by Ky directing Claude 4.7 Opus on 2026-05-16.
//

import Foundation
import SemVer



public extension Ollama {
    
    /// The version of the Ollama server we're connected to, parsed as a `SemVer`.
    ///
    /// The version comes back as a string from the server (`{"version": "0.5.1"}`) and is parsed into a ``SemVer``.
    ///
    /// A malformed version string causes an error to be thrown; there's no graceful degradation for "we can't tell what we're talking to."
    var version: SemVer {
        get async throws(VersionError) {
            let response: OllamaVersionResponse
            do {
                response = try await get(from: "version")
            }
            catch {
                throw .networkError(error)
            }
            
            guard let semVer = SemVer(response.version) else {
                throw .malformedVersionString(response.version)
            }
            
            return semVer
        }
    }
    
    
    
    /// Thrown when there's an error attempting to get the Ollama version
    enum VersionError: LocalizedError {
        
        /// An error occurred while trying to get the version at all
        case networkError(Error)
        
        /// We got the version but it wasn't a valid SemVer
        case malformedVersionString(String)
    }
}



/// Response body for `/api/version`
private struct OllamaVersionResponse: OllamaResponse {
    
    /// Version of Ollama
    let version: String
}
