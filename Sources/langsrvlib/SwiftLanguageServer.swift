/*
 * Welcome to the Swift Language Server.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib
import Foundation
import LanguageServerProtocol
import sourcekitd

#if os(macOS)
import os.log
#endif

@available(macOS 10.12, *)
fileprivate let log = OSLog(subsystem: "com.kiadstudios.swiftlangsrv", category: "SwiftLanguageServer")

public final class SwiftLanguageServer<TransportType: MessageProtocol> {
    private var initialized = false
    private var canExit = false
    private var transport: TransportType

    // cached goodness... maybe abstract this.
    private var openDocuments: [DocumentUri:String] = [:]
    private var moduleName: String!
    private var projectPath: String!

    /// Initializes a new instance of a `SwiftLanguageServer`.
    public init(transport: TransportType) {
        self.transport = transport
    }

    /// Runs the language server. This waits for input via `source`, parses it, and then triggers
    /// the appropriately registered handler.
    public func run(source: InputOutputBuffer) {
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

                guard let response = try self.process(command: command, transport: self.transport) else { return nil }
                return try self.transport.translate(response: response)
            }
            catch {
                if #available(macOS 10.12, *) {
                    os_log("unable to convert message into a command: %{public}@", log: log, type: .default, String(describing: error))
                }
            }

            return nil
        }

        RunLoop.main.run()
    }

    private func process(command: LanguageServerCommand, transport: TransportType) throws -> LanguageServerResponse? {
        var response: LanguageServerResponse? = nil

        switch command {
        case .initialize(let requestId, let params): response = try doInitialize(requestId, params)
        case .initialized: response = try doInitialized()
        case .shutdown(let requestId): return try doShutdown(requestId)
        case .exit: doExit()
        
        case .workspaceDidChangeConfiguration(let params): try doWorkspaceDidChangeConfiguration(params)

        case .textDocumentDidOpen(let params): try doDocumentDidOpen(params)
        case .textDocumentDidChange(let params): try doDocumentDidChange(params)
        case .textDocumentCompletion(let requestId, let params): return try doCompletion(requestId, params)

        default: throw "command is not supported: \(command)"
        }

        return response
    }

    private func doInitialize(_ requestId: RequestId, _ params: InitializeParams) throws -> LanguageServerResponse {
        sourcekitd_initialize()

        // TODO(owensd): Need to actually get the version of Swift that the workspace is using based on the OS.
        projectPath = params.rootPath!
        let includePath = "/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/pm"
        let packagePath = "\(projectPath!)/Package.swift"
        let swiftPath = "/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift"
        let output = shell(
            tool: swiftPath,
            arguments: ["-I", includePath, "-L", includePath, "-lPackageDescription", packagePath, "-fileno", "1"],
            currentDirectory: projectPath)

        if #available(macOS 10.12, *) {
            os_log("successfully read %{public}@: %{public}@", log: log, type: .default, packagePath, output)
        }

        let packageJson = try JSValue.parse(output)

        if #available(macOS 10.12, *) {
            os_log("successfully parsed Package.swift.", log: log, type: .default)
        }

        moduleName = packageJson["package"]["name"].string!

        if #available(macOS 10.12, *) {
            os_log("module name parsed from Package.swift: %{public}@", log: log, type: .default, moduleName)
        }

        var capabilities = ServerCapabilities()
        capabilities.textDocumentSync = .kind(.full)
        // capabilities.textDocumentSync = TextDocumentSyncOptions(
        //     openClose: true,
        //     change: .full,
        //     willSave: true)


        // capabilities.hoverProvider = true
        capabilities.completionProvider = CompletionOptions(resolveProvider: nil, triggerCharacters: [".", "a"])
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

        return .initialize(requestId: requestId, result: InitializeResult(capabilities: capabilities))
    }

    private func doInitialized() throws -> LanguageServerResponse? {
        // TODO(owensd): get this party started.
        return nil
    }

    private func doWorkspaceDidChangeConfiguration(_ params: DidChangeConfigurationParams) throws {
    }

    private func doDocumentDidOpen(_ params: DidOpenTextDocumentParams) throws {
        if #available(macOS 10.12, *) {
            os_log("command: documentDidOpen - %{public}@", log: log, type: .default, params.textDocument.uri)
        }
        openDocuments[params.textDocument.uri] = params.textDocument.text

    }

    private func doDocumentDidChange(_ params: DidChangeTextDocumentParams) throws {
        if #available(macOS 10.12, *) {
            os_log("command: documentDidChange - %{public}@", log: log, type: .default, params.textDocument.uri)
        }
        openDocuments[params.textDocument.uri] = params.contentChanges.reduce("") { $0 + $1.text }
    }

    private func doCompletion(_ requestId: RequestId, _ params: TextDocumentPositionParams) throws -> LanguageServerResponse {
        let uri = params.textDocument.uri

        func calculateOffset(in content: String, line: Int, character: Int) -> Int64 {
            var lineCounter = 0
            var characterCounter = 0

            for (idx, c) in content.characters.enumerated() {
                if lineCounter == line && characterCounter == character { return Int64(idx) }
                if c == "\n" || c == "\r\n" {
                    lineCounter += 1
                    characterCounter = 0
                }
                else {
                    characterCounter += 1
                }
            }

            return 0
        }

        guard let content = openDocuments[uri] else {
            throw "attempting to do completion on an unopened document? \(uri)"
        }
        let offset = calculateOffset(in: content, line: params.position.line, character: params.position.character)

        if #available(macOS 10.12, *) {
            os_log("content:\n%{public}@", log: log, type: .default, content)
            os_log("calculated offset: %d, line: %d, character: %d", log: log, type: .default, offset, params.position.line, params.position.character)
        }

        // var yaml = "key.request: source.request.codecomplete\n"
        // yaml += "key.sourcetext: |\n    " + content.replacingOccurrences(of: "\n", with: "\n    ") + "\n"
        // yaml += "key.offset: \(offset)"

        let request: JSValue = [
            "key.request": "source.request.codecomplete",
            "key.offset": JSValue(Double(offset)),
            "key.sourcetext": JSValue(content),
        ]

        let yaml = request.stringify(nil)

        if #available(macOS 10.12, *) {
            os_log("sourcekitd: creating request:\n%{public}@", log: log, type: .default, yaml)
        }

        var error: UnsafeMutablePointer<Int8>?
        let req: sourcekitd_object_t = sourcekitd_request_create_from_yaml(yaml, &error)
        if let error = error {
            let message = String(cString: error)
            if #available(macOS 10.12, *) {
                os_log("sourcekitd: failed creating the request: %{public}@", log: log, type: .default, message)
            }            
        }

        if #available(macOS 10.12, *) {
            os_log("sourcekitd: request created", log: log, type: .default)
        }

        let res: sourcekitd_object_t = sourcekitd_send_request_sync(req)

        if #available(macOS 10.12, *) {
            os_log("sourcekitd: response received", log: log, type: .default)
        }

        let failed = sourcekitd_response_is_error(res)
        if failed {
            if #available(macOS 10.12, *) {
                os_log("sourcekitd: response failed", log: log, type: .default)
            }

            throw "sourcekitd: failed getting response"
        }
        else {
            let cstr = sourcekitd_response_description_copy(res)
            let message = String(cString: cstr!)
            if #available(macOS 10.12, *) {
                os_log("sourcekitd: response received\n%{public}@", log: log, type: .default, message)
            }
        }

        sourcekitd_response_dispose(res)

        // let completionItems = CodeCompletionItem.parse(response:
        //     Request.codeCompletionRequest(file: uri, contents: "", offset: offset,
        //         arguments: ["-c", uri, "-sdk", sdkPath(), "--spm-module", "tabletop"]).send())

        // let completionList = CompletionList(
        //     isIncomplete: false,
        //     items: completionItems.map {
        //         CompletionItem(
        //             label: $0.name ?? "<no name>",
        //             kind: .function,
        //             detail: $0.typeName)
        //     }
        // )

        let completionList = CompletionList(
            isIncomplete: false,
            items: []
        )

        return .textDocumentCompletion(requestId: requestId, result: .completionList(completionList))

    // public let kind: String
    // public let context: String
    // public let name: String?
    // public let descriptionKey: String?
    // public let sourcetext: String?
    // public let typeName: String?
    // public let moduleName: String?
    // public let docBrief: String?
    // public let associatedUSRs: String?
    // public let numBytesToErase: NumBytesInt?

        // let file = "\(NSUUID().uuidString).swift"
        //         let completionItems = CodeCompletionItem.parse(response:
        //             Request.codeCompletionRequest(file: file, contents: "0.", offset: 2,
        //                 arguments: ["-c", file, "-sdk", sdkPath()]).send())
        //     #if swift(>=4.0)
        //         compareJSONString(withFixtureNamed: "SimpleCodeCompletion.swift4",
        //             jsonString: completionItems)
        //     #else
        //         compareJSONString(withFixtureNamed: "SimpleCodeCompletion",
        //                         jsonString: completionItems)
        //     #endif

        // 

        // {"jsonrpc":"2.0","id":13,"method":"textDocument/completion","params":{"textDocument":{"uri":"file:///Users/owensd/Projects/tabletop/Sources/App/main.swift"},"position":{"line":22,"character":5}}}
    }

    private func doShutdown(_ requestId: RequestId) throws -> LanguageServerResponse {
        sourcekitd_shutdown()
        canExit = true
        return .shutdown(requestId: requestId)
    }

    private func doExit() {
        exit(canExit ? 0 : 1)
    }
}

