// /*
//  * This file contains all of the converters. These are primarily used as a bridging mechanism
//  * between the layers so that implementation details are not exposed upstream.
//  *
//  * Copyright (c) Kiad Studios, LLC. All rights reserved.
//  * Licensed under the MIT License. See License in the project root for license information.
//  */

// import JSONLib

// extension RequestId {
//     init(_ jsvalue: JSValue) throws {
//         if let stringValue = jsvalue.string {
//             self = .string(stringValue)
//         }
//         else if let numberValue = jsvalue.number {
//             self = .number(Int(numberValue))
//         }
//         else {
//             throw "A request ID must have a value and be a number or a string."
//         }
//     }
// }

// extension InitializeParams {
//     init(_ jsvalue: JSValue) throws {
//         guard let _ = jsvalue.object else { throw "The params value must be a dictionary." }
//         self.processId = jsvalue["processId"].integer ?? nil
//         self.rootPath = jsvalue["rootPath"].string ?? nil
//         self.rootUri = jsvalue["rootUri"].string ?? nil
//         self.initializationOptions = jsvalue["intializationOptions"] as AnyObject
//         self.capabilities = try ClientCapabilities(jsvalue["capabilities"])
//         self.trace = try TraceSetting.from(jsvalue["trace"])
//     }
// }

// extension ClientCapabilities {
//     init(_ jsvalue: JSValue) throws {
//         // TODO(owensd): Support this.
//         self.workspace = nil
//         self.textDocument = nil
//         self.experimental = nil
//     }
// }

// extension TraceSetting {
//     static func from(_ jsvalue: JSValue) throws -> TraceSetting {
//         if jsvalue.hasValue {
//             guard let value = jsvalue.string else { throw "expected a string value" }
//             switch value {
//             case "off": return .off
//             case "messages": return .messages
//             case "verbose": return .verbose
//             default: throw "'\(value)' is an unsupported value"
//             }
//         }

//         return .off
//     }
// }

// extension JSValue {
//     var integer: Int? { 
//         if let number = self.number {
//             return Int(number)
//         }
//         return nil
//      }

//      init(_ message: ResponseMessage) {
//         var dict: [String:JSValue] = ["jsonrpc": JSValue(message.jsonrpc)]
//         if let requestId = message.id {
//             switch requestId {
//             case let .number(value): dict["id"] = JSValue(Double(value))
//             case let .string(value): dict["id"] = JSValue(value)
//             }
//         }

//         switch message.result {
//         case let .result(object): dict["result"] = JSValue("object")
//         case let .error(code, message, data): dict["error"] = JSValue("\(code)::\(message)::\(data ?? "nothing" as! AnyObject)")
//         }

//         self.init(dict)
//      }
//  }
