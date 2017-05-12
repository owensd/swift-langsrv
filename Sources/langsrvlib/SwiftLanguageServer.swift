/*
 * Welcome to the Swift Language Server.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib
import Foundation

#if os(macOS)
import os.log
#endif

@available(macOS 10.12, *)
fileprivate let log = OSLog(subsystem: "com.kiadstudios.swiftlangsrv", category: "SwiftLanguageServer")

public final class SwiftLanguageServer<TransportType: MessageProtocol> {
    private var initialized = false
    private var canExit = false
    private var transport: TransportType

    /// Initializes a new instance of a `SwiftLanguageServer`.
    public init(transport: TransportType) {
        self.transport = transport
    }

    /// Runs the language server. This waits for input via `source`, parses it, and then triggers
    /// the appropriately registered handler.
    public func run(source: InputBuffer) {
        if #available(macOS 10.12, *) {
            os_log("Starting the language server.", log: log, type: .default)
        }

        source.run() { message in
            if #available(macOS 10.12, *) {
                os_log("message received:\n%{public}@", log: log, type: .default, message.description)
            }
            do {
                let command = try self.transport.translate(message: message)
                if #available(macOS 10.12, *) {
                    os_log("message translated to command: %{public}@", log: log, type: .default, String(describing: command))
                }
                if let response = try self.process(command: command) {
                    let json = response.toJson().stringify(nil)                        
                    let contentLength = json.characters.count
                    let header = "Content-Length: \(contentLength)\r\nContent-Type: application/vscode-jsonrpc; charset=utf8\r\n\r\n"
                    let message = "\(header)\(json)"

                    if #available(macOS 10.12, *) {
                        os_log("response sent:\n%{public}@", log: log, type: .default, message)
                    }
                    FileHandle.standardOutput.write(message.data(using: .utf8)!)
                }
            }
            catch {
                if #available(macOS 10.12, *) {
                    os_log("unable to convert message into a command: %{public}@", log: log, type: .default, String(describing: error))
                }
            }
        }

        RunLoop.main.run()
    }

    private func process(command: LanguageServerCommand) throws -> ResponseMessage? {
        switch command {
        case let .initialize(requestId, params):
            guard let requestId = requestId else { throw "method `initialize` requires a request ID" }
            return doInitialize(requestId, params)

        case let .shutdown(requestId):
            guard let requestId = requestId else { throw "method `shutdown` requires a request ID" }
            return doShutdown(requestId)

        case .exit: doExit(); return nil
        }
    }

    private func doInitialize(_ requestId: RequestId, _ params: InitializeParams) -> ResponseMessage {
        var capabilities = ServerCapabilities()
        capabilities.textDocumentSync = TextDocumentSyncOptions(
            openClose: true,
            change: .full,
            willSave: true,
            willSaveWaitUntil: nil,
            save: nil
        )
        // capabilities.hoverProvider = true
        // capabilities.completionProvider = CompletionOptions(resolveProvider: nil, triggerCharacters: ["."])
        // capabilities.signatureHelpProvider = SignatureHelpOptions(triggerCharacters: ["."])
        // capabilities.definitionProvider = true
        // capabilities.referencesProvider = true
        // capabilities.documentHighlightProvider = true
        // capabilities.documentSymbolProvider = true
        // capabilities.workspaceSymbolProvider = true
        // capabilities.codeActionProvider = true
        // capabilities.codeLensProvider = CodeLensOptions(resolveProvider: false)
        // capabilities.documentFormattingProvider = true
        // capabilities.documentRangeFormattingProvider = true
        // capabilities.documentOnTypeFormattingProvider = DocumentOnTypeFormattingOptions(firstTriggerCharacter: "{", moreTriggerCharacter: nil)
        // capabilities.renameProvider = true
        // capabilities.documentLinkProvider = DocumentLinkOptions(resolveProvider: false)

        return ResponseMessage(id: requestId, result: .result(InitializeResult(capabilities: capabilities)))
    }

    private func doShutdown(_ requestId: RequestId) -> ResponseMessage {
        canExit = true
        return ResponseMessage(id: requestId, result: .result(nil))
    }

    private func doExit() {
        exit(canExit ? 0 : 1)
    }
}

