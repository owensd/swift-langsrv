/*
 * This file implements all of the necessary components for implementing the 'Language Server Protocol'
 * as defined here: https://github.com/Microsoft/language-server-protocol/. 
 *
 * This is a common, JSON-RPC based protocol used to define interactions between a client endpoint,
 * such as a code editor, and a language server instance that is running. The transport mechanism
 * is not defined, nor is the language the server is running against.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib

/// This provides the complete implementation necessary to translate an incoming message to
/// a `LanguageServiceCommand`.
public final class LanguageServerProtocol: MessageProtocol {
    /// The raw message content of the message coming into the system. This is the fully unverified,
    /// not parsed, and unmodified content.
    public typealias RawMessage = String

    /// The fully parsed, but not necessarily validated, message that will be plumbed through to the
    /// various message handlers.
    public typealias ParsedMessage = JSValue

    /// Whew! Look at the value of this!
    public init() {}

    /// This is used to convert the raw incoming message to a `LanguageServerCommand`. The internals
    /// handle the JSON-RPC mechanism, but that doesn't need to be exposed.
    public func translate(data: MessageData) throws-> LanguageServerCommand {
        var buffer = data
        let raw = String(cString: &buffer)
        if raw.characters.count > 0 {
            guard let message = try? parse(message: raw) else {
                throw "the message is invalid"
            }

            guard let json = JSValue.parse(message.data).value else {
                throw "unable to parse the incoming message"
            }
            
            if json["jsonrpc"] != "2.0" {
                throw "The only 'jsonrpc' value supported is '2.0'."
            }
            
            // TODO(owensd): Convert this into a proper LanguageServerCommand
            throw "nyi"
        }

        throw "invalid message length"
    }
}

/// All valid messages coming in will have a header that is a prefix to the content of the
/// incoming message data. A valid header will have all of this data, though some may be
/// defaulted. In addition, fields like `contentType` and `charset` must be specific values
/// to be supported by this system.

public struct MessageHeader {
    /// The number of bytes that the data region of the message occupies.
    public var contentLength: Int

    /// The mechanism that describes how the data region is structured.
    /// This defaults to `.jsonrpc`.
    public var contentType: ContentType

    /// The way the data in the region is encoded. This defaults to `.utf8`.
    public var encodingType: EncodingType

    /// The supported data region encoding types.
    public enum ContentType: String {
        case jsonrpc = "application/vscode-jsonrpc"
    }

    /// The supported data encoding format.
    public enum EncodingType: String {
        case utf8 = "utf-8"
    }
}

public extension MessageHeader {
    init(length: Int = 0, type: ContentType = .jsonrpc, encodingType: EncodingType = .utf8) {
        self.contentLength = length
        self.contentType = type
        self.encodingType = encodingType
    }
}

public extension MessageHeader.ContentType {
    static func from(string: String?) -> MessageHeader.ContentType? {
        if let value = string?.lowercased() {
            return value == MessageHeader.ContentType.jsonrpc.rawValue ? .jsonrpc : nil
        }

        return nil
    }
}

public extension MessageHeader.EncodingType {
    static func from(string: String?) -> MessageHeader.EncodingType? {
        // Note(owensd): For backwards compatibility, "utf8" is also supported.
        switch string?.lowercased() {
            case MessageHeader.EncodingType.utf8.rawValue?: return .utf8
            case "utf8"?: return .utf8
            default: return nil
        }
    }
}

public struct RawMessage {
    var header: MessageHeader
    var data: String
}

public class Message {
    var jsonrpc: String

    init() {
        jsonrpc = "2.0"
    }
}

public class RequestMessage: Message {
    public var id: Int
    public var method: String
    public var params: [String:AnyObject]

    public init(id: Int, method: String, params: [String:AnyObject] = [:]) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public class ResponseMessage: Message {
    public var id: Int?
    public var result: AnyObject?
    public var error: ResponseError?

    public init(id: Int? = nil, result: AnyObject? = nil, error: ResponseError? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }
}

public class ResponseError {
    public var code: Int
    public var message: String
    public var data: AnyObject?

    public init(code: Int, message: String, data: AnyObject? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public enum ErrorCodes: Int {
	// Defined by JSON RPC
	case parseError = -32700
	case invalidRequest = -32600
	case methodNotFound = -32601
	case invalidParams = -32602
	case internalError = -32603
	case serverErrorStart = -32099
	case serverErrorEnd = -32000
	case serverNotInitialized = -32002
	case unknownErrorCode = -32001

	// Defined by the protocol.
	case requestCancelled = -32800
}

public class NotificationMessage: Message {
    var method: String
    var params: [String:AnyObject]

    init(method: String, params: [String:AnyObject]) {
        self.method = method
        self.params = params
    }
}



func parse(message data: String) throws -> RawMessage {
    enum ParserState {
        case header
        case body
    }
    var header = ""
    var body = ""
    var state = ParserState.header

    var newLineCount = 0
    for c in data.characters {
        if (c == "\r" || c == "\n") {
            if c == "\n" { newLineCount += 1 }
            if newLineCount == 2 {
                state = .body
            }
        }

        switch state {
            case .header: header += "\(c)"
            case .body: body += "\(c)"
        }
    }

    if state != .body {
        throw "message is not properly separated by '\\r\\n\\r\\n' or '\\n\\n'"
    }

    guard let parsedHeader = try? parse(header: header) else {
        throw "unable to parse the header"
    }
    guard let parsedData = parse(body: body) else {
        throw "unable to parse the body"
    }

    return RawMessage(header: parsedHeader, data: parsedData)
}

func parse(header content: String) throws -> MessageHeader {
    enum ParserState {
        case name
        case value
        case separator
    }

    var values: [String:String] = [:]
    var name = ""
    var value = ""
    var state = ParserState.name
    var lastIndex = 0
    for (n, c) in content.characters.enumerated() {
        if c == ":" {
            state = .separator
        }
        else if c == "\r\n" || c == "\r" || c == "\n" {
            // We should be finished now that two consecutive newline constructs exist
            if name == "" && value == "" {
                lastIndex = n
                break
            }

            state = .name
            values[name.trimmingCharacters(in: .whitespaces)] = value.trimmingCharacters(in: .whitespaces)
            name = ""
            value = ""
        }
        else {
            switch state {
                case .name:
                    if c == "\n" || c == "\r" || c == "\r\n" || c == "\t" || c == " " {
                        throw "there can be no whitespace in the name of a header variable"
                    }
                    name += "\(c)"
                case .value: value += "\(c)"
                case .separator:
                    if c == " " {
                        state = .value
                    }
            }
        }
    }

    if lastIndex != content.characters.count - 1 {
        throw "header must end with two consecutive newline constructs"
    }

    if values.count == 0 {
        throw "no values were parsed from the header"
    }

    guard let length = Int(values["Content-Length"] ?? "0") else {
        throw "missing the `Content-Length` parameter"
    }

    if length <= 0 {
        throw "the `Content-Length` must be greater than 0."
    }

    var header = MessageHeader(length: length)

    if let contentType = MessageHeader.ContentType.from(string: values["Content-Type"]) {
        header.contentType = contentType
    }

    return header
}

func parse(body: String) -> String? { 
    return body
}
