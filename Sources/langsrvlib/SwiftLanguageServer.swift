/*
 * Welcome to the Swift Language Server. This is an implementation of the Language Server
 * Protocol. This is a protocol that aims to be a common interface for developer tools.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

 import Foundation
 import JSONLib

// final class SwiftLanguageServer<T: MessageProtocol>: LanguageServer {
//     private var messages: T

//     init(_ messageProtocol: T) {
//         self.messages = messageProtocol
//     }

//     /// Runs the language server. This waits for input via `stdin`, parses it, and then triggers
//     /// the appropriately registered handler. If no handler is found, then `unhandled` is triggered
//     /// with the contents of the message.
//     func run() -> Never {
//         // Sample message:
//         // ----------------
//         // Content-Length: ...
//         // Content-Type: application/vscode-jsonrpc; charset=utf-8
//         //
//         // {
//         //   "jsonprc": "2.0",
//         //   "id": 1,
//         //   "method": "textDocument/didOpen",
//         //   "params": {
//         //     ...
//         //   }
//         // }
//         //
//         // Newlines are always: \r\n.
//         // Content-Type is optional.

//         messages.start()
//         fatalError()
//     }
// }
