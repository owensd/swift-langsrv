/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib

// final class JsonRpcProtocol: MessageProtocol {
//     /// The raw message content of the message coming into the system. This is the fully unverified,
//     /// not parsed, and unmodified content.
//     typealias RawMessage = String

//     /// The fully parsed, but not necessarily validated, message that will be plumbed through to the
//     /// various message handlers.
//     typealias ParsedMessage = JSValue

//     private var invalidMessageHandler: InvalidMessageHandler? = nil
//     private var messageHandler: MessageHandler? = nil
//     private var source: MessageSource

//     /// Creates a new `JsonRpcProtocol` and associates the message source used to receive messages.
//     init(_ source: MessageSource) {
//         self.source = source
//     }

//     /// Registers the handler that will trigger when a valid message comes in.
//     /// SwiftBug(SR-2688) - cannot use the proper `MessageHandler` typealias here.
//     func register(_ handler: @escaping (ParsedMessage) -> ()) {
//         messageHandler = handler
//     }

//     /// Registers the handler that will trigger when an invalid message comes in.
//     /// SwiftBug(SR-2688) - cannot use the proper `InvalidMessageHandler` typealias here.
//     func register(invalid handler: @escaping (RawMessage) -> ()) {
//         invalidMessageHandler = handler
//     }

//     /// Starts listening for new messages to come in.
//     func start() {
//         source.start() { buffer in
//             var copy = buffer
//             let raw = String(cString: &copy)
//             if raw.characters.count > 0 {
//                 guard let message = parse(message: raw) else {
//                     fatalError("the message is invalid")
//                 }

//                 guard let json = JSValue.parse(message.data).value else {
//                     print("unable to parse the incoming message")
//                     invalidMessageHandler?(raw)
//                     return
//                 }
                
//                 if json["jsonrpc"] != "2.0" { fatalError("The only 'jsonrpc' value supported is '2.0'.") }
//                 messageHandler?(json)
//             }
//         }
//     }

//     /// Stops listening for new messages to come in.
//     func stop() {
//         source.stop()
//     }
// }

// /// All valid messages coming in will have a header that is a prefix to the content of the
// /// incoming message data. A valid header will have all of this data, though some may be
// /// defaulted. In addition, fields like `contentType` and `charset` must be specific values
// /// to be supported by this system.



// struct MessageHeader {
//     /// The number of bytes that the data region of the message occupies.
//     var contentLength: Int

//     /// The mechanism that describes how the data region is structured.
//     /// This defaults to `.jsonrpc`.
//     var contentType: ContentType

//     /// The way the data in the region is encoded. This defaults to `.utf8`.
//     var encodingType: EncodingType

//     /// The supported data region encoding types.
//     enum ContentType: String {
//         case jsonrpc = "application/vscode-jsonrpc"
//     }

//     /// The supported data encoding format.
//     enum EncodingType: String {
//         case utf8 = "utf-8"
//     }
// }

// extension MessageHeader {
//     init(length: Int = 0, type: ContentType = .jsonrpc, encodingType: EncodingType = .utf8) {
//         self.contentLength = length
//         self.contentType = type
//         self.encodingType = encodingType
//     }
// }

// extension MessageHeader.ContentType {
//     static func from(string: String?) -> MessageHeader.ContentType? {
//         if let value = string?.lowercased() {
//             return value == MessageHeader.ContentType.jsonrpc.rawValue ? .jsonrpc : nil
//         }

//         return nil
//     }
// }

// extension MessageHeader.EncodingType {
//     static func from(string: String?) -> MessageHeader.EncodingType? {
//         // Note(owensd): For backwards compatibility, "utf8" is also supported.
//         switch string?.lowercased() {
//             case MessageHeader.EncodingType.utf8.rawValue?: return .utf8
//             case "utf8"?: return .utf8
//             default: return nil
//         }
//     }
// }

// struct RawMessage {
//     var header: MessageHeader
//     var data: String
// }

// class Message {
//     var jsonrpc: String

//     init() {
//         jsonrpc = "2.0"
//     }
// }

// class RequestMessage: Message {
//     var id: Int
//     var method: String
//     var params: [String:AnyObject]

//     init(id: Int, method: String, params: [String:AnyObject] = [:]) {
//         self.id = id
//         self.method = method
//         self.params = params
//     }
// }

// class ResponseMessage: Message {
//     var id: Int?
//     var result: AnyObject?
//     var error: ResponseError?

//     init(id: Int? = nil, result: AnyObject? = nil, error: ResponseError? = nil) {
//         self.id = id
//         self.result = result
//         self.error = error
//     }
// }

// class ResponseError {
//     var code: Int
//     var message: String
//     var data: AnyObject?

//     init(code: Int, message: String, data: AnyObject? = nil) {
//         self.code = code
//         self.message = message
//         self.data = data
//     }
// }

// enum ErrorCodes: Int {
// 	// Defined by JSON RPC
// 	case parseError = -32700
// 	case invalidRequest = -32600
// 	case methodNotFound = -32601
// 	case invalidParams = -32602
// 	case internalError = -32603
// 	case serverErrorStart = -32099
// 	case serverErrorEnd = -32000
// 	case serverNotInitialized = -32002
// 	case unknownErrorCode = -32001

// 	// Defined by the protocol.
// 	case requestCancelled = -32800
// }

// class NotificationMessage: Message {
//     var method: String
//     var params: [String:AnyObject]

//     init(method: String, params: [String:AnyObject]) {
//         self.method = method
//         self.params = params
//     }
// }



// func parse(message data: String) -> RawMessage? {
//     enum ParserState {
//         case header
//         case body
//     }
//     var header = ""
//     var body = ""
//     var state = ParserState.header

//     var newLineCount = 0
//     for c in data.characters {
//         if (c == "\r" || c == "\n") {
//             if c == "\n" { newLineCount += 1 }
//             if newLineCount == 2 {
//                 state = .body
//             }
//         }

//         switch state {
//             case .header: header += "\(c)"
//             case .body: body += "\(c)"
//         }
//     }

//     if state != .body {
//         print("message is not properly separated by '\\r\\n\\r\\n' or '\\n\\n'")
//         return nil
//     }

//     guard let parsedHeader = parse(header: header) else {
//         print("unable to parse the header")
//         return nil
//     }
//     guard let parsedData = parse(body: body) else {
//         print("unable to parse the body")
//         return nil
//     }
//     return RawMessage(header: parsedHeader, data: parsedData)
// }

// func parse(header content: String) -> MessageHeader? {
//     enum ParserState {
//         case name
//         case value
//     }

//     var values: [String:String] = [:]
//     var name = ""
//     var value = ""
//     var state = ParserState.name
//     for c in content.characters {
//         if c == ":" {
//             state = .value
//         }
//         else if c == "\r" || c == "\n" {
//             if c == "\n" {
//                 state = .name
//                 values[name.trimmingCharacters(in: .whitespaces)] = value.trimmingCharacters(in: .whitespaces)
//                 name = ""
//                 value = ""
//             }
//         }
//         else {
//             switch state {
//                 case .name: name += "\(c)"
//                 case .value: value += "\(c)"
//             }
//         }
//     }

//     if values.count == 0 {
//         print("header is formatted incorrectly")
//         return nil
//     }

//     guard let length = Int(values["Content-Length"] ?? "0") else {
//         print("Unable to retrieve the content length")
//         return nil
//     }

//     if length <= 0 {
//         print("Invalid content length")
//         return nil
//     }

//     var header = MessageHeader(length: length)

//     if let contentType = MessageHeader.ContentType.from(string: values["Content-Type"]) {
//         header.contentType = contentType
//     }

//     return header
// }

// func parse(body: String) -> String? { 
//     return body
// }
