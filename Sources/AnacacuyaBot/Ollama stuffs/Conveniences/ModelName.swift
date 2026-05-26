//
//  ModelName.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-18.
//

import Foundation

import SimpleLogging



/// A structured form of a qualified Ollama model name.
///
/// When checking for equality, the namespace and tag fields are optional. If they're included in both, then they're included in the equality check, but otherwise they're excluded. That is to say, less-qualified names match more-qualified names, but if both are more-qualified then both must match exactly.
public struct ModelName: Sendable {
    
    /// The namespace within which the model resides. For example, in `virtual/alpaca:latest`, this is `"virtual"`.
    public let namespace: String?
    
    /// The name of the model itself. For example, in `public/foss-lm:28b`, this is `"foss-lm"`.
    public let name: String
    
    /// The tag that specifies a variant of the model. For example, in `starshot/kiki-k2.5:1t`, this is `"1t"`.
    public let tag: String?
    
    
    /// A structured form of a qualified Ollama model name
    ///
    /// - Parameters:
    ///   - namespace: _optional_ - The namespace within which the model resides. For example, in `virtual/alpaca:latest`, this is `"virtual"`.
    ///   - name:      The name of the model itself. For example, in `public/foss-lm:28b`, this is `"foss-lm"`.
    ///   - tag:       _optional_ - The tag that specifies a variant of the model. For example, in `starshot/kiki-k2.5:1t`, this is `"1t"`. This is rather freeform, like `"latest"`, `"fp16"`, or `"70b-instruct-q2_K"`.
    init(in namespace: String?, named name: String, tag: String?) {
        self.namespace = namespace
        self.name = name
        self.tag = tag
    }
}



// MARK: - parsing

//unsafe: I'm pretty dang sure there's nothing unsafe about this regex
private nonisolated(unsafe) let regex = /^(?:(?<namespace>.+)\/)?(?<name>[^\/:]+)(?::(?<tag>[^:]+))?$/
// more ideal regex which causes 100% CPU for 2 minutes on my macOS 26.5 M4 Pro: /^(?:(?<namespace>[^\/:]+(?:\/[^\/:]+)*)+\/)?(?<name>[^\/:]+?)(?::(?<tag>[^\/:]+))?$/



extension ModelName: LosslessStringConvertible {
    
    /// Attempts to parse the given string as a qualified model name.
    ///
    /// It must be in the form `[namespace/]name[:tag]` (namespace and tag are both optional, but if included, are delimited by a slash and a colon, respectively)
    ///
    /// - Parameter string: The raw form of the qualified model name. For example, `"quak:3b"`
    public init?<S: StringProtocol>(_ string: S) {
        guard let match = try? unsafe regex.firstMatch(in: String(string)) else {
            return nil
        }
        
        self.namespace = match.output.namespace?.nonEmptyOrNil?.lowercased()
        self.name      = match.output.name.lowercased()
        self.tag       = match.output.tag?.nonEmptyOrNil?.lowercased()
    }
}



// MARK: - Equatable

extension ModelName: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if let lhs_namespace = lhs.namespace,
           let rhs_namespace = rhs.namespace {
            if let lhs_tag = lhs.tag,
               let rhs_tag = rhs.tag {
                // All components are specified in both
                
                lhs_namespace == rhs_namespace
                && lhs.name == rhs.name
                && lhs_tag == rhs_tag
            }
            else {
                // One/both tagless
                // Both namespaced
                
                lhs_namespace == rhs_namespace
                && lhs.name == rhs.name
            }
        }
        else {
            // One/both namespaceless
            
            if let lhs_tag = lhs.tag,
               let rhs_tag = rhs.tag {
                // One/both namespaceless
                // Both tagged
                
                lhs.name == rhs.name
                && lhs_tag == rhs_tag
            }
            else {
                // One/both tagless AND namespaceless
                lhs.name == rhs.name
            }
        }
    }
    
    
    public static func == (lhs: String?, rhs: Self) -> Bool {
        if let lhs {
            ModelName(lhs) == rhs
        }
        else {
            false
        }
    }
    
    
    public static func == (lhs: Self, rhs: String?) -> Bool {
        rhs == lhs
    }
    
    
    public static func ===(lhs: Self, rhs: Self) -> Bool {
        lhs.namespace == rhs.namespace
            && lhs.name == rhs.name
            && lhs.tag == rhs.tag
    }
}



// MARK: - CustomStringConvertible

extension ModelName: CustomStringConvertible {
    
    /// Assembles a qualified model name string (`[namespace/]name[:tag]`)
    public var description: String {
        if let namespace {
            if let tag {
                "\(namespace)/\(name):\(tag)"
            }
            else {
                "\(namespace)/\(name)"
            }
        }
        else if let tag {
            "\(name):\(tag)"
        }
        else {
            name
        }
    }
}



// MARK: - Encodable

extension ModelName: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}



// MARK: - Decodable

extension ModelName: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        if let candidate = Self.init(string) {
            self = candidate
        }
        else {
            throw DecodeError.malformed
        }
    }
    
    
    
    /// An error which might occur while decoding a qualified model name
    public enum DecodeError: Error {
        
        /// The raw string form was malformed (e.g. ends with a colon)
        case malformed
    }
}



// MARK: - ExpressibleByStringLiteral

extension ModelName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        if let candidate = Self.init(value) {
            self = candidate
        }
        else {
            let message = "Developer error: invalid model name as string literal: \(value)"
            log(fatal: message)
            fatalError(message)
        }
    }
}
