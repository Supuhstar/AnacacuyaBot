//
//  JsonValue.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



/// An arbitrary JSON value. Useful for when you expect a server to return something arbitrary but still valid JSON
public indirect enum JsonValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JsonValue])
    case array([JsonValue])
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self)             { self = .bool(v); return }
        if let v = try? container.decode(Int.self)              { self = .int(v); return }
        if let v = try? container.decode(Double.self)           { self = .double(v); return }
        if let v = try? container.decode(String.self)           { self = .string(v); return }
        if let v = try? container.decode([String: JsonValue].self) { self = .object(v); return }
        if let v = try? container.decode([JsonValue].self)      { self = .array(v); return }
        if container.decodeNil()                                { self = .null; return }
        throw DecodingError.dataCorruptedError(
            in: container, debugDescription: "Unknown JSON type"
        )
    }
    
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v):  try container.encode(v)
        case .null:          try container.encodeNil()
        }
    }
}
