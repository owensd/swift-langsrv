/*
 * Welcome to the Swift Language Server.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import Foundation
import JSONLib

#if os(macOS)
import os.log
#endif

@available(macOS 10.12, *)
fileprivate let log = OSLog(subsystem: "com.kiadstudios.swiftlangsrv", category: "SwiftLanguageServer")

public final class SwiftLanguageServer {
    private var initialized = false

    // Whew! Look at the value of this!
    public init() {}

    /// Runs the language server. This waits for input via `stdin`, parses it, and then triggers
    /// the appropriately registered handler. If no handler is found, then `unhandled` is triggered
    /// with the contents of the message.
    public func run(source: MessageSource, transport: MessageProtocol) -> Never {
        if #available(macOS 10.12, *) {
            os_log("Starting the language server.", log: log, type: .default)
        }

        source.run() { buffer in
            if #available(macOS 10.12, *) {
                os_log("message received: size=%d", log: log, type: .default, buffer.count)
                os_log("message contents:\n%{public}@", log: log, type: .default, String(bytes: buffer, encoding: .utf8) ?? "<cannot convert>")
            }
            do {
                let message = try transport.translate(data: buffer)
                if #available(macOS 10.12, *) {
                    os_log("message received: %{public}@", log: log, type: .default, message.debugDescription)
                }
                if let response = try process(command: message) {
                    print("\(response.toJson())")
                }
            }
            catch {
                if #available(macOS 10.12, *) {
                    os_log("unable to convert message into a command: %{public}@", log: log, type: .default, String(describing: error))
                }
            }
        }
    }

    private func process(command: LanguageServerCommand) throws -> ResponseMessage? {
        switch command {
        case let .initialize(requestId, params):
            guard let requestId = requestId else { throw "method `initialize` requires a request ID" }
            return doInitialize(requestId, params)
        }
    }

    private func doInitialize(_ requestId: RequestId, _ params: InitializeParams) -> ResponseMessage {
        let capabilities = ServerCapabilities()
        return ResponseMessage(id: requestId, result: .result(InitializeResult(capabilities: capabilities)))
    }
}

extension LanguageServerCommand: CustomDebugStringConvertible {
   public var debugDescription: String {
       switch self {
       case let .initialize(requestId, params): return "request id: \(requestId!), params: \(params)"
       }
    }
}

