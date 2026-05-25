//
//  ModelNameTests.swift
//  AnacacuyaBotTests
//
//  Created by Ky on 2026-05-24.
//

import Foundation
import Testing
import AnacacuyaBot



@Suite("ModelName")
struct ModelNameTests { }



// MARK: - Parsing

extension ModelNameTests {
    
    /// Tests for `init?(_ string:)` — verifying every valid form, lowercasing behavior, and
    /// the invalid inputs that should produce `nil`.
    @Suite("Parsing")
    struct Parsing {
        
        // MARK: Valid forms
        
        @Test("Name only")
        func nameOnly() throws {
            let model = try #require(ModelName("quak" as String))
            #expect(nil  == model.namespace)
            #expect("quak" == model.name)
            #expect(nil  == model.tag)
        }
        
        @Test("Name and tag")
        func nameAndTag() throws {
            let model = try #require(ModelName("quak:3b" as String))
            #expect(nil   == model.namespace)
            #expect("quak" == model.name)
            #expect("3b"   == model.tag)
        }
        
        @Test("Namespace and name")
        func namespaceAndName() throws {
            let model = try #require(ModelName("virtual/alpaca" as String))
            #expect("virtual" == model.namespace)
            #expect("alpaca"  == model.name)
            #expect(nil       == model.tag)
        }
        
        @Test("All three components")
        func allThreeComponents() throws {
            let model = try #require(ModelName("starshot/kiki-k2.5:1t" as String))
            #expect("starshot"   == model.namespace)
            #expect("kiki-k2.5" == model.name)
            #expect("1t"         == model.tag)
        }
        
        @Test("Complex tag (e.g. quantization suffix)")
        func complexTag() throws {
            let model = try #require(ModelName("public/foss-lm:70b-instruct-q2_k" as String))
            #expect("public"              == model.namespace)
            #expect("foss-lm"            == model.name)
            #expect("70b-instruct-q2_k" == model.tag)
            
            let model2 = try #require(ModelName("hf.co/ggml-org/SmolLM3-3B-GGUF:Q4_K_M" as String))
            #expect("hf.co/ggml-org"  == model2.namespace)
            #expect("smollm3-3b-gguf" == model2.name)
            #expect("q4_k_m"          == model2.tag)
        }
        
        // MARK: Lowercasing
        
        @Test("Input is lowercased on parse")
        func lowercasedOnParse() throws {
            let model = try #require(ModelName("Virtual/ALPACA:Latest" as String))
            #expect("virtual" == model.namespace)
            #expect("alpaca"  == model.name)
            #expect("latest"  == model.tag)
        }
        
        // MARK: Invalid inputs → nil
        
        @Test("Empty string returns nil")
        func emptyString() {
            #expect(nil == ModelName("" as String))
        }
        
        @Test("Bare colon returns nil")
        func bareColon() {
            #expect(nil == ModelName(":" as String))
        }
        
        @Test("Trailing colon (missing tag) returns nil")
        func trailingColon() {
            // A trailing colon implies a tag that isn't there.
            #expect(nil == ModelName("quak:" as String))
        }
        
        @Test("Leading slash (missing namespace) returns nil")
        func leadingSlash() {
            #expect(nil == ModelName("/alpaca" as String))
        }
        
        @Test("Trailing slash (missing name) returns nil")
        func trailingSlash() {
            #expect(nil == ModelName("virtual/" as String))
        }
        
        @Test("Multiple colons return nil")
        func multipleColons() {
            // Only one colon (name:tag) is valid; a second one has nowhere to go.
            #expect(nil == ModelName("quak:3b:extra" as String))
        }
    }
}



// MARK: - Equatable

extension ModelNameTests {
    
    /// Tests for `==` — verifying the four-quadrant optional-field logic.
    ///
    /// The contract:
    /// - Both namespaced  + both tagged   → namespace, name, AND tag must match
    /// - Both namespaced  + one/both bare → namespace and name must match (tag ignored)
    /// - One/both bare    + both tagged   → name and tag must match (namespace ignored)
    /// - One/both bare    + one/both bare → name only must match
    @Suite("Equatable")
    struct Equatable {
        
        // MARK: Scenario 1: both namespaced, both tagged → all three compared
        
        @Test("Fully qualified identical names match")
        func fullyQualifiedMatch() {
            let a: ModelName = "virtual/alpaca:latest"
            let b: ModelName = "virtual/alpaca:latest"
            #expect(a == b)
        }
        
        @Test("Fully qualified: namespace mismatch")
        func fullyQualifiedNamespaceMismatch() {
            let a: ModelName = "virtual/alpaca:latest"
            let b: ModelName = "public/alpaca:latest"
            #expect(a != b)
        }
        
        @Test("Fully qualified: tag mismatch")
        func fullyQualifiedTagMismatch() {
            let a: ModelName = "virtual/alpaca:latest"
            let b: ModelName = "virtual/alpaca:70b"
            #expect(a != b)
        }
        
        @Test("Fully qualified: name mismatch")
        func fullyQualifiedNameMismatch() {
            let a: ModelName = "virtual/alpaca:latest"
            let b: ModelName = "virtual/llama:latest"
            #expect(a != b)
        }
        
        // MARK: Scenario 2: both namespaced, one/both untagged → namespace + name compared
        
        @Test("Both namespaced, one untagged: tag is ignored")
        func bothNamespacedOneUntagged() {
            let tagged:   ModelName = "virtual/alpaca:latest"
            let untagged: ModelName = "virtual/alpaca"
            // The untagged side means we can't compare tags, so they should match.
            #expect(tagged == untagged)
        }
        
        @Test("Both namespaced, both untagged: match")
        func bothNamespacedBothUntagged() {
            let a: ModelName = "virtual/alpaca"
            let b: ModelName = "virtual/alpaca"
            #expect(a == b)
        }
        
        @Test("Both namespaced, both untagged: namespace mismatch")
        func bothNamespacedNamespaceMismatch() {
            let a: ModelName = "virtual/alpaca"
            let b: ModelName = "public/alpaca"
            #expect(a != b)
        }
        
        // MARK: Scenario 3: one/both namespaceless, both tagged → name + tag compared
        
        @Test("One namespaceless, both tagged: namespace is ignored")
        func oneNamespacelessBothTagged() {
            let withNamespace:    ModelName = "virtual/alpaca:latest"
            let withoutNamespace: ModelName = "alpaca:latest"
            #expect(withNamespace == withoutNamespace)
        }
        
        @Test("Both namespaceless, both tagged: tag mismatch")
        func bothNamespacelessTagMismatch() {
            let a: ModelName = "alpaca:latest"
            let b: ModelName = "alpaca:70b"
            #expect(a != b)
        }
        
        @Test("Both namespaceless, both tagged: name mismatch")
        func bothNamespacelessNameMismatch() {
            let a: ModelName = "alpaca:latest"
            let b: ModelName = "llama:latest"
            #expect(a != b)
        }
        
        // MARK: Scenario 4: one/both namespaceless, one/both untagged → name only compared
        
        @Test("Bare name matches fully-qualified name")
        func bareNameMatchesFullyQualified() {
            let bare:  ModelName = "alpaca"
            let fully: ModelName = "virtual/alpaca:latest"
            // No namespace or tag on the left side, so only the name is compared.
            #expect(bare == fully)
        }
        
        @Test("Name-only: different names don't match")
        func nameOnlyMismatch() {
            let a: ModelName = "alpaca"
            let b: ModelName = "llama"
            #expect(a != b)
        }
        
        // MARK: Consistency
        
        @Test("Equality is symmetric")
        func symmetry() {
            let bare:  ModelName = "alpaca"
            let fully: ModelName = "virtual/alpaca:latest"
            #expect(bare == fully)
            #expect(fully == bare)
        }
    }
}



// MARK: - String? equality overloads

extension ModelNameTests {
    
    /// Tests for `== (String?, ModelName)` and `== (ModelName, String?)`.
    ///
    /// These parse the `String?` into a `ModelName` and then apply the same
    /// four-quadrant optional-field equality logic as the native `==`.
    @Suite("String? equality overloads")
    struct StringEquality {
        
        @Test("String? == ModelName: matching strings")
        func optionalStringMatchesModel() {
            let model:  ModelName = "alpaca:latest"
            let string: String?   = "alpaca:latest"
            #expect(string == model)
        }
        
        @Test("String? == ModelName: name mismatch")
        func optionalStringNameMismatch() {
            let model:  ModelName = "alpaca:latest"
            let string: String?   = "llama:latest"
            #expect(false == (string == model))
        }
        
        @Test("nil == ModelName: always false")
        func nilLeftIsAlwaysFalse() {
            let model:  ModelName = "alpaca"
            let string: String?   = nil
            #expect(false == (string == model))
        }
        
        @Test("ModelName == String?: matching strings")
        func modelMatchesOptionalString() {
            let model:  ModelName = "alpaca:latest"
            let string: String?   = "alpaca:latest"
            #expect(model == string)
        }
        
        @Test("ModelName == nil: always false")
        func modelEqualsNilIsAlwaysFalse() {
            let model:  ModelName = "alpaca"
            let string: String?   = nil
            #expect(false == (model == string))
        }
        
        @Test("String? equality still respects optional-field rules")
        func optionalFieldRulesApplyThroughString() {
            // The string "alpaca" has no namespace or tag, so only the name is
            // compared — it should match a fully qualified ModelName.
            let model:  ModelName = "virtual/alpaca:latest"
            let string: String?   = "alpaca"
            #expect(string == model)
        }
        
        @Test("Malformed String? does not match any ModelName")
        func malformedStringDoesNotMatch() {
            let model:  ModelName = "alpaca"
            let string: String?   = ":::"
            #expect(false == (string == model))
        }
    }
}



// MARK: - CustomStringConvertible

extension ModelNameTests {
    
    /// Tests for `description` — verifying all four output shapes and that a
    /// parse → describe → re-parse round-trip is lossless.
    @Suite("CustomStringConvertible")
    struct Description {
        
        @Test("All three components: namespace/name:tag")
        func allThreeComponents() {
            let model: ModelName = "virtual/alpaca:latest"
            #expect("virtual/alpaca:latest" == model.description)
        }
        
        @Test("Namespace and name only: namespace/name")
        func namespaceAndName() {
            let model: ModelName = "virtual/alpaca"
            #expect("virtual/alpaca" == model.description)
        }
        
        @Test("Name and tag only: name:tag")
        func nameAndTag() {
            let model: ModelName = "alpaca:latest"
            #expect("alpaca:latest" == model.description)
        }
        
        @Test("Name only: name")
        func nameOnly() {
            let model: ModelName = "alpaca"
            #expect("alpaca" == model.description)
        }
        
        @Test("Round-trips through description without loss")
        func roundTrip() throws {
            let original: ModelName = "virtual/alpaca:latest"
            let reparsed = try #require(ModelName(original.description))
            // Both description and field values should survive the round-trip.
            #expect(original.description == reparsed.description)
            #expect(original.namespace   == reparsed.namespace)
            #expect(original.name        == reparsed.name)
            #expect(original.tag         == reparsed.tag)
        }
    }
}



// MARK: - Codable

extension ModelNameTests {
    
    /// Tests for `Encodable` and `Decodable` — verifying that `ModelName` encodes
    /// to its string representation and decodes symmetrically.
    @Suite("Codable")
    struct Codable {
        
        @Test("Encodes to its string representation")
        func encodes() throws {
            let model: ModelName = "virtual/alpaca:latest"
            let encoded = try JSONEncoder().encode(model)
            // It should decode back as a plain JSON string.
            let string = try JSONDecoder().decode(String.self, from: encoded)
            #expect("virtual/alpaca:latest" == string)
        }
        
        @Test("Decodes from a valid string")
        func decodes() throws {
            let json  = Data(#""virtual/alpaca:latest""#.utf8)
            let model = try JSONDecoder().decode(ModelName.self, from: json)
            #expect("virtual" == model.namespace)
            #expect("alpaca"  == model.name)
            #expect("latest"  == model.tag)
        }
        
        @Test("Decoding a malformed string throws")
        func decodeMalformedThrows() {
            let json = Data(#"":::""#.utf8)
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(ModelName.self, from: json)
            }
        }
        
        @Test("Full encode → decode round-trip is lossless")
        func roundTrip() throws {
            let original: ModelName = "virtual/alpaca:latest"
            let encoded  = try JSONEncoder().encode(original)
            let decoded  = try JSONDecoder().decode(ModelName.self, from: encoded)
            #expect(original.description == decoded.description)
        }
    }
}



// MARK: - ExpressibleByStringLiteral

extension ModelNameTests {
    
    /// Tests for `init(stringLiteral:)`.
    ///
    /// Only the success path is testable here — an invalid literal hits `fatalError`,
    /// which would terminate the test process rather than produce a catchable failure.
    @Suite("ExpressibleByStringLiteral")
    struct StringLiteral {
        
        @Test("Valid literal with all components initializes correctly")
        func allComponents() {
            let model: ModelName = "virtual/alpaca:latest"
            #expect("virtual" == model.namespace)
            #expect("alpaca"  == model.name)
            #expect("latest"  == model.tag)
        }
        
        @Test("Bare name literal initializes correctly")
        func bareNameLiteral() {
            let model: ModelName = "alpaca"
            #expect(nil      == model.namespace)
            #expect("alpaca" == model.name)
            #expect(nil      == model.tag)
        }
    }
}
