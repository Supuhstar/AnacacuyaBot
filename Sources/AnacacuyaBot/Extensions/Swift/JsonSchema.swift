//
//  JsonSchema.swift
//  AnacacuyaBot
//
//  Created by Ky directing Claude 4.7 Opus on 2026-05-16.
//


/// Models a JSON Schema document for transmission to services that consume
/// them as response shape declarations — primarily LLM structured-output
/// endpoints and OpenAPI 3.1 tooling.
///
/// Compose schemas through the static factory methods, which default all
/// optional constraints sensibly and keep call sites readable:
/// ```swift
/// let schema = JsonSchema.object(
///     properties: [
///         "name":   .string(description: "Full legal name"),
///         "age":    .integer(minimum: 0, maximum: 150),
///         "scores": .array(items: .number(), minItems: 1)
///     ],
///     required: ["name", "age"]
/// )
/// ```
///
/// `description` lives on the outer struct rather than threaded through
/// each `Shape` case because it is orthogonal to structure — every variant
/// can carry one, and adding future cross-cutting fields (`title`, `default`,
/// `examples`) should cost one line here, not a diff across every case.
public struct JsonSchema: Sendable {
    
    /// The structural variant of this schema. Determines which JSON Schema
    /// keywords appear on the wire.
    public var shape: Shape
    
    /// Human-readable annotation surfaced to the consuming service. For LLM
    /// endpoints this is semantically load-bearing: the model reads it and
    /// output quality reflects it. Treat it with the same care as the prompt.
    public var description: String?
    
    public init(shape: Shape, description: String? = nil) {
        self.shape = shape
        self.description = description
    }
    
    /// The structural vocabulary of JSON Schema, stripped of cross-cutting
    /// concerns so each case carries only the fields meaningful to it.
    ///
    /// Marked `indirect` because `.array` embeds a `JsonSchema` value
    /// directly as an associated value. Without indirection the compiler
    /// cannot determine a finite size for the type. The heap allocation is
    /// per-schema-node, which is negligible for the document sizes typical
    /// of this use case.
    public indirect enum Shape: Sendable {
        
        /// Use for free-form string values. Pass `enumeration` to constrain
        /// to a closed set — the JSON Schema equivalent of a `String` raw-value
        /// enum, and the right tool for asking a model to choose between named
        /// options without risk of hallucinated values.
        case string(enumeration: [String]? = nil)
        static var string: Self { .string() }
        
        /// Use for whole-number values. `minimum` and `maximum` are inclusive
        /// bounds; omit either to leave that end unbounded.
        case integer(minimum: Int? = nil, maximum: Int? = nil)
        static var integer: Self { .integer() }
        
        /// Use for fractional values. Prefer `.integer` when fractions must
        /// be rejected at the schema level rather than by downstream validation.
        case number(minimum: Double? = nil, maximum: Double? = nil)
        static var number: Self { .number() }
        
        /// Use for `true`/`false` values.
        case boolean
        
        /// Use when a field must be JSON `null`. Most useful as one branch
        /// of a `.anyOf` or `.oneOf` to model nullable fields explicitly.
        case null
        
        /// Use for homogeneous arrays. `minItems`/`maxItems` are inclusive
        /// bounds useful for keeping token budgets bounded on LLM responses.
        case array(items: JsonSchema, minItems: Int? = nil, maxItems: Int? = nil)
        
        /// Use for objects with known key sets.
        ///
        /// - Parameters:
        ///   - properties: All the properties of this schema object
        ///   - required:   the keys that must be present; unlisted keys are optional
        ///   - additionalProperties: defaults to `false` rather than the JSON Schema spec default of `true` because the dominant consumer of this type — OpenAI's strict structured-output mode — rejects schemas that permit extra keys. Override explicitly when targeting a permissive endpoint or a validator rather than a model.
        case object(
            properties: [String: JsonSchema],
            required: [String] = [],
            additionalProperties: Bool = false
        )
        
        /// Use when the value must satisfy at least one of the given schemas.
        /// Prefer `.oneOf` when the schemas are mutually exclusive; use
        /// `.anyOf` when overlap is valid or irrelevant.
        case anyOf([JsonSchema])
        
        /// Use when the value must satisfy exactly one of the given schemas.
        /// The stronger constraint aids model compliance on LLM endpoints that
        /// reason about schema semantics.
        case oneOf([JsonSchema])
    }
}



// MARK: - Encoding

extension JsonSchema: Encodable {
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(description, forKey: .description)
        
        switch shape {
            
        case .string(let enumeration):
            try container.encode("string", forKey: .type)
            try container.encodeIfPresent(enumeration, forKey: .enumeration)
            
        case .integer(let minimum, let maximum):
            try container.encode("integer", forKey: .type)
            try container.encodeIfPresent(minimum, forKey: .minimum)
            try container.encodeIfPresent(maximum, forKey: .maximum)
            
        case .number(let minimum, let maximum):
            try container.encode("number", forKey: .type)
            try container.encodeIfPresent(minimum, forKey: .minimum)
            try container.encodeIfPresent(maximum, forKey: .maximum)
            
        case .boolean:
            try container.encode("boolean", forKey: .type)
            
        case .null:
            try container.encode("null", forKey: .type)
            
        case .array(let items, let minItems, let maxItems):
            try container.encode("array", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encodeIfPresent(minItems, forKey: .minItems)
            try container.encodeIfPresent(maxItems, forKey: .maxItems)
            
        case .object(let properties, let required, let additionalProperties):
            try container.encode("object", forKey: .type)
            try container.encode(properties, forKey: .properties)
            if false == required.isEmpty {
                try container.encode(required, forKey: .required)
            }
            try container.encode(additionalProperties, forKey: .additionalProperties)
            
        case .anyOf(let schemas):
            try container.encode(schemas, forKey: .anyOf)
            
        case .oneOf(let schemas):
            try container.encode(schemas, forKey: .oneOf)
        }
    }
    
    /// Centralised key mapping. `enumeration` is renamed to satisfy the JSON
    /// Schema wire format while keeping the Swift identifier out of keyword
    /// territory. All other names are intentionally kept literal to make
    /// schema output auditable by reading this enum.
    fileprivate enum CodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case required
        case additionalProperties
        case items
        case minItems
        case maxItems
        case enumeration        = "enum"
        case anyOf
        case oneOf
        case minimum
        case maximum
    }
}



// MARK: - Decoding

extension JsonSchema: Decodable {
    
    /// Reconstructs a schema from its wire form. Tolerates spec-permitted
    /// shapes our encoder would not itself emit — absent `additionalProperties`
    /// is treated as `true` per JSON Schema's own default, and absent
    /// `required` is treated as the empty array. Keywords outside our modeled
    /// vocabulary are silently discarded; if faithful round-tripping becomes
    /// a requirement, that decision will need revisiting.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // Union keywords take precedence over `type` because a schema may
        // carry `oneOf`/`anyOf` without a `type` field, and the spec treats
        // them as the primary discriminator when present.
        if let schemas = try container.decodeIfPresent([JsonSchema].self, forKey: .oneOf) {
            self.init(shape: .oneOf(schemas), description: description)
            return
        }
        if let schemas = try container.decodeIfPresent([JsonSchema].self, forKey: .anyOf) {
            self.init(shape: .anyOf(schemas), description: description)
            return
        }
        
        let type = try container.decode(String.self, forKey: .type)
        let shape = try Shape(decodingTypeKeyword: type, from: container)
        self.init(shape: shape, description: description)
    }
}



extension JsonSchema.Shape {
    
    /// Decodes the appropriate variant given an already-extracted `type`
    /// keyword. Lifted into its own initializer so the dispatch logic for
    /// `type`-discriminated shapes lives in one place, separate from the
    /// `anyOf`/`oneOf` handling that precedes it. A future addition of
    /// further `type` values touches only this method.
    fileprivate init(
        decodingTypeKeyword type: String,
        from container: KeyedDecodingContainer<JsonSchema.CodingKeys>
    ) throws {
        switch type {
            
        case "string":
            let enumeration = try container.decodeIfPresent([String].self, forKey: .enumeration)
            self = .string(enumeration: enumeration)
            
        case "integer":
            let minimum = try container.decodeIfPresent(Int.self, forKey: .minimum)
            let maximum = try container.decodeIfPresent(Int.self, forKey: .maximum)
            self = .integer(minimum: minimum, maximum: maximum)
            
        case "number":
            let minimum = try container.decodeIfPresent(Double.self, forKey: .minimum)
            let maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
            self = .number(minimum: minimum, maximum: maximum)
            
        case "boolean":
            self = .boolean
            
        case "null":
            self = .null
            
        case "array":
            let items = try container.decode(JsonSchema.self, forKey: .items)
            let minItems = try container.decodeIfPresent(Int.self, forKey: .minItems)
            let maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems)
            self = .array(items: items, minItems: minItems, maxItems: maxItems)
            
        case "object":
            // The spec defaults to `true` when the keyword is absent. Honoring
            // that default on decode — rather than mirroring our encoder's
            // `false` default — keeps us interoperable with permissive producers.
            let properties = try container.decodeIfPresent(
                [String: JsonSchema].self, forKey: .properties
            ) ?? [:]
            let required = try container.decodeIfPresent(
                [String].self, forKey: .required
            ) ?? []
            let additionalProperties = try container.decodeIfPresent(
                Bool.self, forKey: .additionalProperties
            ) ?? true
            self = .object(
                properties: properties,
                required: required,
                additionalProperties: additionalProperties
            )
            
        default:
            // An unknown `type` is a genuine decoding failure — unlike unknown
            // keywords on a known type, which we silently tolerate, an unknown
            // type leaves us no variant to inhabit.
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unrecognized JSON Schema type keyword: '\(type)'"
            )
        }
    }
}



// MARK: - Sugar

public extension JsonSchema {
    
    /// Use at call sites that compose nested schemas. Reads naturally as
    /// `.string(description: "…")` without requiring the `shape:` label.
    static func string(
        enumeration: [String]? = nil,
        description: String? = nil
    ) -> JsonSchema {
        .init(shape: .string(enumeration: enumeration), description: description)
    }
    static var string: Self { .string() }
    
    
    /// Use when the field represents a whole number, optionally bounded.
    static func integer(
        minimum: Int? = nil,
        maximum: Int? = nil,
        description: String? = nil
    ) -> JsonSchema {
        .init(shape: .integer(minimum: minimum, maximum: maximum), description: description)
    }
    static var integer: Self { .integer() }
    
    /// Use when the field represents a fractional value, optionally bounded.
    static func number(
        minimum: Double? = nil,
        maximum: Double? = nil,
        description: String? = nil
    ) -> JsonSchema {
        .init(shape: .number(minimum: minimum, maximum: maximum), description: description)
    }
    static var number: Self { .number() }
    
    /// Use for boolean fields.
    static func boolean(description: String? = nil) -> JsonSchema {
        .init(shape: .boolean, description: description)
    }
    
    /// Use for homogeneous arrays, with optional cardinality bounds.
    static func array(
        items: JsonSchema,
        minItems: Int? = nil,
        maxItems: Int? = nil,
        description: String? = nil
    ) -> JsonSchema {
        .init(
            shape: .array(items: items, minItems: minItems, maxItems: maxItems),
            description: description
        )
    }
    
    /// Use for objects with a known property set.
    ///
    /// `additionalProperties` defaults to `false` — see ``Shape/object`` for
    /// the rationale. Pass `true` explicitly when targeting a permissive
    /// endpoint or a standalone JSON Schema validator.
    static func object(
        properties: [String: JsonSchema],
        required: [String] = [],
        additionalProperties: Bool = false,
        description: String? = nil
    ) -> JsonSchema {
        .init(
            shape: .object(
                properties: properties,
                required: required,
                additionalProperties: additionalProperties
            ),
            description: description
        )
    }
    
    /// Use when the value may satisfy any of the given schemas. Prefer
    /// `.oneOf` when the schemas are mutually exclusive.
    static func anyOf(
        _ schemas: [JsonSchema],
        description: String? = nil
    ) -> JsonSchema {
        .init(shape: .anyOf(schemas), description: description)
    }
    
    /// Use when the value must satisfy exactly one of the given schemas —
    /// the stronger constraint relative to `.anyOf`.
    static func oneOf(
        _ schemas: [JsonSchema],
        description: String? = nil
    ) -> JsonSchema {
        .init(shape: .oneOf(schemas), description: description)
    }
    
    /// A schema matching only JSON `null`. Exposed as a constant rather than
    /// a factory because it carries no parameters — callers use it most often
    /// as one branch of a `.anyOf` to model a nullable field.
    static let null = JsonSchema(shape: .null)
}
