/*
 * Welcome to the Swift Language Server.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib

#if os(macOS)
import os.log
#endif

@available(macOS 10.12, *)
fileprivate let log = OSLog(subsystem: "com.kiadstudios.swiftlangsrv", category: "SwiftLanguageServer")

public final class SwiftLanguageServer {
    private var initialized = false
    private var canExit = false

    // Whew! Look at the value of this!
    public init() {}

    /// Runs the language server. This waits for input via `stdin`, parses it, and then triggers
    /// the appropriately registered handler. If no handler is found, then `unhandled` is triggered
    /// with the contents of the message.
    public func run(source: MessageSource, transport: MessageProtocol) -> Never {
        if #available(macOS 10.12, *) {
            os_log("Starting the language server.", log: log, type: .default)
        }

        setbuf(stdout, nil)

        source.run() { buffer in
            if #available(macOS 10.12, *) {
                os_log("message received: size=%d", log: log, type: .default, buffer.count)
                os_log("message contents:\n%{public}@", log: log, type: .default, String(bytes: buffer, encoding: .utf8) ?? "<cannot convert>")
            }
            do {
                let message = try transport.translate(data: buffer)
                if #available(macOS 10.12, *) {
                    os_log("message received: %{public}@", log: log, type: .default, buffer)
                }
                if let response = try process(command: message) {
                    let json = response.toJson().stringify(nil)                        
                    let contentLength = json.characters.count
                    let header = "Content-Length: \(contentLength)\r\nContent-Type: application/vscode-jsonrpc; charset=utf8\r\n\r\n"
                    let message = "\(header)\(json)"

                    if #available(macOS 10.12, *) {
                        os_log("response sent:\n%{public}@", log: log, type: .default, message)
                    }
                    print(message, terminator: "")
                    // fflush(stdout)
                    //FileHandle.standardOutput.write(message.data(using: .utf8)!)
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

