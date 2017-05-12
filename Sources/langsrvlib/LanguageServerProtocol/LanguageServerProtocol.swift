/*
 * This implements the necessary components for implementing the v3.0 'Language Server Protocol'
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

#if os(macOS)
import os.log
#endif

@available(macOS 10.12, *)
fileprivate let log = OSLog(subsystem: "com.kiadstudios.swiftlangsrv", category: "LanguageServerProtocol")



/// This provides the complete implementation necessary to translate an incoming message to a
/// `LanguageServiceCommand`.
public final class LanguageServerProtocol: MessageProtocol {
    /// The registration table for all of the commands that can be handled via this protocol.
    public var protocols: [String:(JSValue) throws -> LanguageServerCommand] = [:]

    /// Creates a new instance of the `LanguageServerProtocol`.
    public init() {
        protocols["initialize"] = parse(initialize:)
        protocols["shutdown"] = parse(shutdown:)
        protocols["exit"] = parse(exit:)
    }

    /// This is used to convert the raw incoming message to a `LanguageServerCommand`. The internals
    /// handle the JSON-RPC mechanism, but that doesn't need to be exposed.
    public func translate(message: Message) throws-> LanguageServerCommand {
        guard let json = JSValue.parse(message.content).value else {
            throw "unable to parse the incoming message"
        }
            
        if json["jsonrpc"] != "2.0" {
            throw "The only 'jsonrpc' value supported is '2.0'."
        }

        guard let method = json["method"].string else {
            throw "A message is required to have a `method` parameter."
        }

        if let parser = protocols[method] {
            return try parser(json)
        }
        else {
            throw "unhandled method `\(method)`"
        }
    }

    private func parse(initialize json: JSValue) throws -> LanguageServerCommand {
        return .initialize(
            requestId: try RequestId.from(json: json["id"]),
            params: try InitializeParams.from(json: json["params"]))
    }

    private func parse(shutdown json: JSValue) throws -> LanguageServerCommand {
        return .shutdown(requestId: try RequestId.from(json: json["id"]))
    }

    private func parse(exit json: JSValue) throws -> LanguageServerCommand {
        return .exit
    }
}
