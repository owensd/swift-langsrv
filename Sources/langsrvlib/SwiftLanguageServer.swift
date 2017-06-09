/*
 * Welcome to the Swift Language Server.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib
import Foundation
import LanguageServerProtocol
import sourcekit

let languageServerLogCategory = "SwiftLanguageServer"
let languageServerSettingsKey = "swift"

public final class SwiftLanguageServer<TransportType: MessageProtocol> {
    private var initialized = false
    private var canExit = false
    private var transport: TransportType

    // cached goodness... maybe abstract this.
    private var openDocuments: [DocumentUri:String] = [:]
    private var projectPath: String!
    private var buildPath: String!

    // Settings that are not updated until a workspaceDidChangeConfiguration request comes in.
    private var toolchainPath: String!
    private var packageName: String!


    /// Initializes a new instance of a `SwiftLanguageServer`.
    public init(transport: TransportType) {
        self.transport = transport
    }

    /// Runs the language server. This waits for input via `source`, parses it, and then triggers
    /// the appropriately registered handler.
    public func run(source: InputOutputBuffer) {
        log("Starting the language server.", category: languageServerLogCategory)
        source.run() { message in
            log("message received:\n%{public}@", category: languageServerLogCategory, message.description)
            do {
                let command = try self.transport.translate(message: message)
                log("message translated to command: %{public}@", category: languageServerLogCategory, String(describing: command))

                guard let response = try self.process(command: command) else { return nil }
                return try self.transport.translate(response: response)
            }
            catch {
                log("unable to convert message into a command: %{public}@", category: languageServerLogCategory, String(describing: error))
            }

            return nil
        }

        RunLoop.main.run()
    }

    private func process(command: LanguageServerCommand) throws -> LanguageServerResponse? {
        switch command {
        case .initialize(let requestId, let params):
            return try doInitialize(requestId, params)
        
        case .initialized: 
            return try doInitialized()

        case .shutdown(let requestId):
            return try doShutdown(requestId)
        
        case .exit:
            doExit()
        
        case .workspaceDidChangeConfiguration(let params):
            try doWorkspaceDidChangeConfiguration(params)

        case .textDocumentDidOpen(let params):
            try doDocumentDidOpen(params)

        case .textDocumentDidChange(let params):
            try doDocumentDidChange(params)
        
        case .textDocumentCompletion(let requestId, let params):
            return try doCompletion(requestId, params)

        case .textDocumentHover(let requestId, let params):
            return try doHover(requestId, params)

        default: throw "command is not supported: \(command)"
        }

        return nil
    }

    private func doInitialize(_ requestId: RequestId, _ params: InitializeParams) throws -> LanguageServerResponse {
        projectPath = params.rootPath!
        buildPath = "\(projectPath!)/.build"

        sourcekit(initialize: true)
        
        var capabilities = ServerCapabilities()
        capabilities.textDocumentSync = .kind(.full)
        capabilities.hoverProvider = true
        capabilities.completionProvider = CompletionOptions(resolveProvider: nil, triggerCharacters: ["."])
        capabilities.signatureHelpProvider = SignatureHelpOptions(triggerCharacters: ["."])
        capabilities.definitionProvider = true
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
        let settings = (params.settings as! JSValue)[languageServerSettingsKey]

        guard let toolchainPath = settings["toolchainPath"].string else {
            throw "The path to the Toolchain must be set."
        }
        self.toolchainPath = toolchainPath
        log("configuration: toolchainPath set to %{public}@", category: languageServerLogCategory, toolchainPath)

        let packagePath = "\(projectPath!)/Package.swift"
        let includePath = "\(toolchainPath)/usr/lib/swift/pm"
        let swiftPath = "\(toolchainPath)/usr/bin/swift"

        let output = shell(
            tool: swiftPath,
            arguments: ["-I", includePath, "-L", includePath, "-lPackageDescription", packagePath, "-fileno", "1"],
            currentDirectory: projectPath)
        log("successfully read %{public}@: %{public}@", category: languageServerLogCategory, packagePath, output)
        
        let packageJson = try JSValue.parse(output)
        log("successfully parsed Package.swift.", category: languageServerLogCategory)

        packageName = packageJson["package"]["name"].string!
        log("package name parsed from Package.swift: %{public}@", category: languageServerLogCategory, packageName)

        // TODO(owensd): handle targets...
    }

    private func doShutdown(_ requestId: RequestId) throws -> LanguageServerResponse {
        canExit = true
        sourcekit(initialize: false)
        return .shutdown(requestId: requestId)
    }

    private func doExit() {
        exit(canExit ? 0 : 1)
    }

    private func doDocumentDidOpen(_ params: DidOpenTextDocumentParams) throws {
        log("command: documentDidOpen - %{public}@", category: languageServerLogCategory, params.textDocument.uri)
        openDocuments[params.textDocument.uri] = params.textDocument.text
    }

    private func doDocumentDidChange(_ params: DidChangeTextDocumentParams) throws {
        log("command: documentDidChange - %{public}@", category: languageServerLogCategory, params.textDocument.uri)
        openDocuments[params.textDocument.uri] = params.contentChanges.reduce("") { $0 + $1.text }
    }

    private func doCompletion(_ requestId: RequestId, _ params: TextDocumentPositionParams) throws -> LanguageServerResponse {
        let uri = params.textDocument.uri

        guard let content = openDocuments[uri] else {
            throw "attempting to do completion on an unopened document? \(uri)"
        }
        let offset = calculateOffset(in: content, line: params.position.line, character: params.position.character)
        log("content:\n%{public}@", category: languageServerLogCategory, content)
        log("calculated %{public}@", category: languageServerLogCategory, "offset: \(offset), line: \(params.position.line), character: \(params.position.character)")

        let result = try sourcekit(completion: content, offset: offset, packageName: packageName, projectPath: projectPath, filePath: URL(string: uri)!.path)
        log("sourcekit response:\n%{public}@", category: languageServerLogCategory, result)

        guard let json = try? JSValue.parse(result) else {
            throw "unable to parse the sourcekit(completion:offset:path:) response"
        }
        let completionList = CompletionList(
            isIncomplete: false,
            items: json["key.results"].array?.map {
                CompletionItem(
                    label: $0["key.description"].string ?? "",
                    kind: kind($0["key.kind"].string),
                    documentation: $0["key.doc.brief"].string ?? ""
                )
            } ?? []
        )

        return .textDocumentCompletion(requestId: requestId, result: .completionList(completionList))
    }

    private func doHover(_ requestId: RequestId, _ params: TextDocumentPositionParams) throws -> LanguageServerResponse {
        let uri = params.textDocument.uri

        guard let content = openDocuments[uri] else {
            throw "attempting to do completion on an unopened document? \(uri)"
        }
        let offset = calculateOffset(in: content, line: params.position.line, character: params.position.character)
        log("content:\n%{public}@", category: languageServerLogCategory, content)
        log("calculated %{public}@", category: languageServerLogCategory, "offset: \(offset), line: \(params.position.line), character: \(params.position.character)")

        let result = try sourcekit(cursorInfo: content, offset: offset, packageName: packageName, projectPath: projectPath, filePath: URL(string: uri)!.path)
        log("sourcekit response:\n%{public}@", category: languageServerLogCategory, result)

        guard let json = try? JSValue.parse(result) else {
            throw "unable to parse the sourcekit(cursorInfo:offset:path:) response"
        }

        func strip(_ content: String) -> String {
            var newString = ""
            var inTag = false
            for c in content.characters {
                if inTag && c == ">" {
                    inTag = false
                }
                else if c == "<" {
                    inTag = true
                }
                else if !inTag {
                    newString += "\(c)"
                }
            }

            return newString
        }

        func sanitize(_ content: String) -> String {
            return strip(content)
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
        }

        // cheap XML parsing here...
        func parse(_ body: String, start: String, end: String) -> String? {
            if let startIndex = body.range(of: start) {
                if let endIndex = body.range(of: end, range: startIndex.upperBound..<body.endIndex) {
                    return sanitize(body
                            .substring(with:startIndex.upperBound ..< endIndex.lowerBound)
                            .replacingOccurrences(of: "<![CDATA[", with: "")
                            .replacingOccurrences(of: "]]>", with: ""))
                }
            }

            return nil
        }


        var strings: [MarkedString] = []

        if let kind = json["key.kind"].string {
            if kind.hasPrefix("source.lang.swift.ref.function") {
                if let doc = json["key.doc.full_as_xml"].string {
                    if let decl = parse(doc, start: "<Declaration>", end: "</Declaration>") {
                        strings.append(MarkedString.code(language: "swift", value: decl))
                    }
                    if let help = parse(doc, start: "<Abstract><Para>", end: "</Para></Abstract>") {
                        strings.append(MarkedString.string(help))
                    }
                }
                else if let decl = json["key.annotated_decl"].string {
                    strings.append(MarkedString.code(language: "swift", value: sanitize(decl)))
                }
            }
            else if kind.hasPrefix("source.lang.swift.ref.var") {
                if let decl = json["key.annotated_decl"].string {
                    strings.append(MarkedString.code(language: "swift", value: sanitize(decl)))
                }
            }
            else if kind.hasPrefix("source.lang.swift.decl.var") {
                if let decl = json["key.annotated_decl"].string {
                    strings.append(MarkedString.code(language: "swift", value: sanitize(decl)))
                }
            }
            else if kind.hasPrefix("source.lang.swift.ref.enumelement") {
                if let container = json["key.typename"].string {
                    if let index = container.range(of: "-> ") {
                        let type = container.substring(with: index.upperBound..<container.endIndex)
                        if let name = json["key.annotated_decl"].string {
                            let label = sanitize(name).replacingOccurrences(of: "case ", with: "")
                            strings.append(MarkedString.string("case \(type).\(label)"))
                        }
                    }
                }
            }
            else if kind.hasPrefix("source.lang.swift.ref") {
                if let decl = json["key.annotated_decl"].string {
                    strings.append(MarkedString.code(language: "swift", value: sanitize(decl)))
                }
            }
            else if kind.hasPrefix("source.lang.swift.decl") {
                if let decl = json["key.annotated_decl"].string {
                    strings.append(MarkedString.code(language: "swift", value: sanitize(decl)))
                }
            }
        }

        let hover = Hover(contents: strings)
        return .textDocumentHover(requestId: requestId, result: hover)
    }

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
        
        return Int64(content.characters.count)
    }

    func kind(_ value: String?) -> CompletionItemKind {
        switch value ?? "" {
        case "source.lang.swift.decl.function.free": return .function
        case "source.lang.swift.decl.function.method.instance": return .method
        case "source.lang.swift.decl.function.method.static": return .method
        case "source.lang.swift.decl.function.constructor": return .constructor
        case "source.lang.swift.decl.function.destructor": return .constructor
        case "source.lang.swift.decl.function.operator": return .function
        case "source.lang.swift.decl.function.subscript": return .property
        case "source.lang.swift.decl.function.accessor.getter": return .property
        case "source.lang.swift.decl.function.accessor.setter": return .property
        case "source.lang.swift.decl.class": return .`class`
        case "source.lang.swift.decl.struct": return .`class`
        case "source.lang.swift.decl.enum": return .`enum`
        case "source.lang.swift.decl.enumelement": return .property
        case "source.lang.swift.decl.protocol": return .interface
        case "source.lang.swift.decl.typealias": return .reference
        case "source.lang.swift.decl.var.global": return .variable
        case "source.lang.swift.decl.var.instance": return .variable
        case "source.lang.swift.decl.var.static": return .variable
        case "source.lang.swift.decl.var.local": return .variable

        case "source.lang.swift.ref.function.free": return .function
        case "source.lang.swift.ref.function.method.instance": return .method
        case "source.lang.swift.ref.function.method.static": return .method
        case "source.lang.swift.ref.function.constructor": return .constructor
        case "source.lang.swift.ref.function.destructor": return .constructor
        case "source.lang.swift.ref.function.operator": return .function
        case "source.lang.swift.ref.function.subscript": return .property
        case "source.lang.swift.ref.function.accessor.getter": return .property
        case "source.lang.swift.ref.function.accessor.setter": return .property
        case "source.lang.swift.ref.class": return .`class`
        case "source.lang.swift.ref.struct": return .`class`
        case "source.lang.swift.ref.enum": return .`enum`
        case "source.lang.swift.ref.enumelement": return .property
        case "source.lang.swift.ref.protocol": return .interface
        case "source.lang.swift.ref.typealias": return .reference
        case "source.lang.swift.ref.var.global": return .variable
        case "source.lang.swift.ref.var.instance": return .variable
        case "source.lang.swift.ref.var.static": return .variable
        case "source.lang.swift.ref.var.local": return .variable

        case "source.lang.swift.decl.extension.struct": return .`class`
        case "source.lang.swift.decl.extension.class": return .`class`
        case "source.lang.swift.decl.extension.enum": return .`enum`
        default: return .text
        }
    }
}

