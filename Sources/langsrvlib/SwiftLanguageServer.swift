/*
 * Welcome to the Swift Language Server.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib
import Foundation
import LanguageServerProtocol

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
    private var projectPath: String!

    // Settings that are not updated until a workspaceDidChangeConfiguration request comes in.
    private var sourcekittenPath: String!
    private var toolchainPath: String!
    private var packageName: String!


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
        case let .shutdown(requestId): return try doShutdown(requestId)
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
        projectPath = params.rootPath!

        var capabilities = ServerCapabilities()
        capabilities.textDocumentSync = .kind(.full)
        capabilities.hoverProvider = true
        capabilities.completionProvider = CompletionOptions(resolveProvider: nil, triggerCharacters: ["."])
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
        let settings = params.settings["swift-langsrv"]

        guard let toolchainPath = settings["toolchainPath"].string else {
            throw "The path to the Toolchain must be set."
        }
        self.toolchainPath = toolchainPath

        let packagePath = "\(projectPath!)/Package.swift"
        let includePath = "\(toolchainPath)/usr/lib/swift/pm"
        let swiftPath = "\(toolchainPath)/usr/bin/swift"
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
 	  
        packageName = packageJson["package"]["name"].string!
        if #available(macOS 10.12, *) {
            os_log("package name parsed from Package.swift: %{public}@", log: log, type: .default, packageName)
        }

        guard let sourcekittenPath = settings["sourcekittenPath"].string else {
            throw "The path to SourceKitten must be set."
        }
        self.sourcekittenPath = sourcekittenPath

        // TODO(owensd): handle targets...

        if #available(macOS 10.12, *) {
            os_log("configuration: sourcekittenPath set to %{public}@", log: log, type: .default, sourcekittenPath)
            os_log("configuration: toolchainPath set to %{public}@", log: log, type: .default, toolchainPath)
        }
    }

    private func doShutdown(_ requestId: RequestId) throws -> LanguageServerResponse {
        canExit = true
        return .shutdown(requestId: requestId)
    }

    private func doExit() {
        exit(canExit ? 0 : 1)
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

        let result = try sourcekitten(completion: content, offset: offset, uri: URL(string: uri)!.path)
        if #available(macOS 10.12, *) {
            os_log("sourcekitten response:\n%{public}@", log: log, type: .default, result.stringify())
        }
        
        let completionList = CompletionList(
            isIncomplete: false,
            items: result.array!.map {
                CompletionItem(
                    label: $0["descriptionKey"].string ?? "",
                    kind: .function,
                    documentation: $0["docBrief"].string ?? ""
                )
            }
        )

        return .textDocumentCompletion(requestId: requestId, result: .completionList(completionList))
    }

    private func sourcekitten(completion content: String, offset: Int64, uri: DocumentUri) throws -> JSValue {
        let components = uri.components(separatedBy: "/")
        let index = components.index(of: "Sources")!
        let module: String = components[index + 1].hasSuffix(".swift") ? packageName : components[index + 1]

        let arguments =  ["complete", "--file", URL(string: uri)!.path, "--offset", "\(offset)", "--spm-module", module]
        if #available(macOS 10.12, *) {
            os_log("arguments to pass to sourcekitten:\n%{public}@", log: log, type: .default, arguments.joined(separator: " "))
        }

        let output = shell(
            tool: sourcekittenPath,
            arguments: arguments,
            currentDirectory: projectPath)

        if #available(macOS 10.12, *) {
            os_log("response from sourcekitten:\n%{public}@", log: log, type: .default, output)
        }

        return try JSValue.parse(output)
    }
}

