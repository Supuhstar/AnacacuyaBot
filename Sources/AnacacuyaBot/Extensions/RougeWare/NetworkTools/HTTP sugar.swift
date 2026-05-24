//
//  HTTP sugar.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-14.
//

import Foundation
#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

import SerializationTools
import SimpleLogging



// MARK: - GET

public extension Decodable {
    
    /// GETs an instance of this object from the given URL as JSON and returns the received result
    ///  
    /// - Parameters:
    ///   - url:                 The URL from which to get the JSON form of this object
    ///   - timeout:             How long to wait for a response before giving up
    ///   - keyDecodingStrategy: How to decode the JSON keys the server returns
    ///
    /// - Returns: An instance of this type, decoded from the received JSON response
    static func get(
        from url: URL,
        timeout: Duration,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
    ) async throws -> Self {
        try Self.init(
            jsonData: try await url.httpRequest(
                method: "GET",
                body: nil,
                timeout: timeout,
            ),
            keyDecodingStrategy: keyDecodingStrategy,
        )
    }
}



public extension URL {
    
    /// GETs an JSON-parsed object from this URL and returns the received result, as a `Response` type you choose
    ///
    /// - Parameters:
    ///   - url:                 The URL from which to get the JSON form of this object
    ///   - timeout:             How long to wait for a response before giving up
    ///   - keyDecodingStrategy: How to decode the JSON keys the server returns
    ///
    /// - Returns: An instance of `Response`, decoded from the received JSON response
    func get<Response: Decodable>(
        timeout: Duration,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try await .get(
            from: self,
            timeout: timeout,
            keyDecodingStrategy: keyDecodingStrategy,
        )
    }
}



// MARK: - POST

public extension Encodable {
    
    /// POSTs this object to the given URL as JSON and returns the received result, parsed as a `Response` object you choose
    ///
    /// - Parameters:
    ///   - url:                 The URL to which to post the JSON form of this object
    ///   - timeout:             How long to wait for a response before giving up
    ///   - keyEncodingStrategy: How to encode the JSON keys before sending the request to the server
    ///   - keyDecodingStrategy: How to decode the JSON keys the server returns
    ///
    /// - Returns: A decoded version of the received JSON response
    func post<Response: Decodable>(
        to url: URL,
        timeout: Duration,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try Response(
            jsonData: await post(
                to: url,
                timeout: timeout,
                keyEncodingStrategy: keyEncodingStrategy,
            ),
            keyDecodingStrategy: keyDecodingStrategy,
        )
    }
    
    
    /// POSTs this object to the given URL as JSON, and optionally returns the received result
    ///
    /// - Parameters:
    ///   - url:                 The URL to which to post the JSON form of this object
    ///   - timeout:             How long to wait for a response before giving up
    ///   - keyEncodingStrategy: How to encode the JSON keys before sending the request to the server
    ///
    /// - Returns: The raw received JSON response
    @discardableResult
    func post(
        to url: URL,
        timeout: Duration,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy,
    ) async throws -> Data {
        try await url.httpRequest(
            method: "POST",
            body: try jsonData(
                keyEncodingStrategy: keyEncodingStrategy,
            ),
            timeout: timeout,
        )
    }
}



public extension URL {
    
    /// POSTs the given object to this URL as JSON and returns the received result, parsed as a `Response` object you choose
    ///
    /// - Parameters:
    ///   - body:                The object to post in JSON form
    ///   - timeout:             How long to wait for a response before giving up
    ///   - keyEncodingStrategy: How to encode the JSON keys before sending the request to the server
    ///   - keyDecodingStrategy: How to decode the JSON keys the server returns
    ///
    /// - Returns: A decoded version of the received JSON response
    func post<Body: Encodable, Response: Decodable>(
        _ body: Body,
        timeout: Duration,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try await body.post(
            to: self,
            timeout: timeout,
            keyEncodingStrategy: keyEncodingStrategy,
            keyDecodingStrategy: keyDecodingStrategy,
            receiving: Response.self,
        )
    }
    
    
    /// POSTs the given object to this URL as JSON, and optionally returns the received result
    ///
    /// - Parameters:
    ///   - body:                The object to post in JSON form
    ///   - timeout:             How long to wait for a response before giving up
    ///   - keyEncodingStrategy: How to encode the JSON keys before sending the request to the server
    ///
    /// - Returns: The raw received JSON response
    @discardableResult
    func post<Body: Encodable>(
        _ body: Body,
        timeout: Duration,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy,
    ) async throws -> Data {
        try await body.post(
            to: self,
            timeout: timeout,
            keyEncodingStrategy: keyEncodingStrategy,
        )
    }
}



// MARK: - DEL

public extension Encodable {
    
    /// DELETEs the remote resource from the given URL, as directed by this JSON-codable object
    ///
    /// - Parameters:
    ///   - url:                 The URL from which to delete the resource
    ///   - timeout:             How long to wait for a response before giving up
    ///   - keyEncodingStrategy: How to encode the JSON keys before sending the request to the server
    func delete(
        from url: URL,
        timeout: Duration,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy,
    ) async throws {
        _ = try await url.httpRequest(
            method: "DELETE",
            body: try jsonData(
                keyEncodingStrategy: keyEncodingStrategy,
            ),
            timeout: timeout,
        )
    }
}



public extension URL {
    
    /// DELETEs the remote resource from this URL, as directed by the given instance of a JSON-codable object
    ///
    /// - Parameters:
    ///   - body:                The body of the delete request, which will be sent as JSON
    ///   - timeout:             _optional_ - How long to wait for a response before giving up
    ///   - keyEncodingStrategy: How to encode the JSON keys before sending the request to the server
    func delete<Body: Encodable>(
        _ body: Body,
        timeout: Duration,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy,
    ) async throws {
        try await body.delete(
            from: self,
            timeout: timeout,
            keyEncodingStrategy: keyEncodingStrategy,
        )
    }
}



// MARK: - Generic

public extension URL {
    
    /// Makes a URL request to this URL
    ///
    /// - Parameters:
    ///   - method:  The HTTP method to use (GET, POST, DELETE, etc.)
    ///   - body:    The body of the request, if any
    ///   - timeout: How long to wait for a response before giving up
    ///
    /// - Returns: The server's response to the request
    func httpRequest(
        method: String,
        body: Data?,
        timeout: Duration,
    ) async throws -> Data {
        var req = URLRequest(url: self)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout.timeInterval
        req.httpBody = body
        log(debug: """
            \(method)ing to \(self):
            \((try? (body?.jsonString(dataEncodingStrategy: .base64, keyEncodingStrategy: .convertToSnakeCase) ?? "(null)")) ?? "(not JSON)")
            """)
        let (data, urlResponse) = try await URLSession.shared.data(for: req)
        
        if let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode,
           false == (200...200).contains(statusCode)
        {
            let message = String(data: data, encoding: .utf8)
            log(error: "⚠️ Error \(statusCode): \(message ?? "(could not decode response)")")
            throw HttpError(statusCode: UInt16(statusCode), message: message)
        }
        
        return data
    }
    
    
    /// Makes a URL request to this URL
    ///
    /// - Parameters:
    ///   - method: The HTTP method to use (GET, POST, DELETE, etc.)
    ///   - body:   The body of the request, if any
    ///   - timeout: How long to wait for a response before giving up
    ///   - keyDecodingStrategy: How to decode the JSON keys the server returns
    ///
    /// - Returns: The server's response to the request, parsed as a specific type
    func httpRequest<Response: Decodable>(
        method: String,
        body: Data?,
        timeout: Duration,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try Response(
            jsonData: await httpRequest(
                method: method,
                body: body,
                timeout: timeout,
            ),
            keyDecodingStrategy: keyDecodingStrategy,
        )
    }
}



// MARK: - Errors

/// An error returned from an HTTP request
public struct HttpError: Error, CustomStringConvertible {
    
    /// The HTTP status code returned in the server's response
    let statusCode: UInt16
    
    /// If the server returned a message as well, this is it
    let message: String?
    
    
    public var description: String {
        if let message {
            "HTTP \(statusCode): \(message)"
        }
        else {
            "HTTP \(statusCode)"
        }
    }
}
