//
//  MultipartFormData.swift
//  AnacacuyaBot
//
//  Created by Ky directing Claude 4.7 Opus on 2026-05-26.
//

import Foundation



/// Builds a `multipart/form-data` request body — the encoding used to send
/// binary files alongside ordinary text fields in a single HTTP request.
///
/// JSON can't carry raw bytes without base64-inflating them, so Telegram's
/// upload endpoints (`sendPhoto`, `sendDocument`, …) expect this format
/// instead. The body is a sequence of *parts* separated by a delimiter
/// string — the `boundary` — each part carrying its own headers and then a
/// raw value. A closing `--boundary--` marks the end.
///
/// Construct one, append fields and files in the order you want them sent,
/// then hand `contentType` to the request header and `encoded()` to the body.
struct MultipartFormData {
    
    /// The delimiter separating parts. Chosen to be long and random so it
    /// cannot collide with any byte sequence inside the actual content —
    /// a collision would corrupt the body.
    private let boundary = "AnacacuyaBoundary-\(UUID().uuidString)"
    
    /// The accumulated body. Each `add…` call appends one complete part.
    private var body = Data()
    
    
    /// The value for the request's `Content-Type` header. Carries the
    /// boundary so the server knows what delimiter to split on.
    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }
    
    
    /// Appends a plain text field — the multipart equivalent of one
    /// key/value pair in a JSON body.
    ///
    /// - Parameters:
    ///   - name:  The field name Telegram expects, e.g. `"chat_id"`.
    ///   - value: The field's value. Numbers are passed as their string form.
    mutating func addField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }
    
    
    /// Appends a file part — a named field whose value is raw bytes.
    ///
    /// - Parameters:
    ///   - name:        The field name Telegram expects, e.g. `"photo"`.
    ///   - filename:    The filename shown to Telegram. Telegram inspects the
    ///                  actual bytes to determine the real type, so this is
    ///                  mostly cosmetic, but the extension should still match.
    ///   - contentType: The MIME type of the bytes, e.g. `"image/jpeg"`.
    ///   - data:        The raw file bytes.
    mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }
    
    
    /// Finalizes the body by appending the closing boundary and returns it.
    /// Call exactly once, after all fields and files have been added.
    func encoded() -> Data {
        var finished = body
        finished.append(Data("--\(boundary)--\r\n".utf8))
        return finished
    }
    
    
    /// Appends a string to the body as UTF-8.
    ///
    /// Every line in a multipart body must end with `\r\n` — a bare `\n`
    /// is the single most common cause of a multipart body a server
    /// silently rejects. Callers are responsible for including it.
    private mutating func append(_ string: String) {
        body.append(Data(string.utf8))
    }
}
