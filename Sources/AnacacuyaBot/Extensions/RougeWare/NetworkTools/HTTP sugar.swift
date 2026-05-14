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



extension Encodable {
    
    /// POSTs this object to the given URL as JSON and returns the received result, parsed as a `Response` object you choose
    ///
    /// - Parameters:
    ///   - url:     The URL to which to post the JSON form of this object
    ///   - timeout: _optional_ - How long to wait for a response before giving up
    ///
    /// - Returns: A decoded version of the received JSON response
    func post<Response: Decodable>(
        to url: URL,
        timeout: Duration = Limits.maxTimeToWaitForModelResponse,
        receiving _: Response.Type = Response.self,
    ) async throws -> Response {
        try Response(jsonData: await post(to: url, timeout: timeout))
    }
    
    
    /// POSTs this object to the given URL as JSON and returns the received result
    ///
    /// - Parameters:
    ///   - url:     The URL to which to post the JSON form of this object
    ///   - timeout: _optional_ - How long to wait for a response before giving up
    ///
    /// - Returns: The raw received JSON response
    func post(
        to url: URL,
        timeout: Duration = Limits.maxTimeToWaitForModelResponse,
    ) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout.timeInterval
        req.httpBody = try jsonData()
        let (data, urlResponse) = try await URLSession.shared.data(for: req)
        
        if let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode,
           statusCode != 200 {
            print("⚠️ Error \(statusCode) response:", String(data: data, encoding: .utf8) ?? "(could not decode response)")
        }
        
        return data
    }
    
    
    /// POSTs this object to the given URL as JSON
    ///
    /// - Parameters:
    ///   - url:     The URL to which to post the JSON form of this object
    ///   - timeout: _optional_ - How long to wait for a response before giving up
    func post(
        to url: URL,
        timeout: Duration = Limits.maxTimeToWaitForModelResponse,
    ) async throws {
        let _: Data = try await post(to: url, timeout: timeout)
    }
}
