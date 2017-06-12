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

public enum LanguageServerError: Error {
    case toolchainNotFound(path: String)
    case swiftToolNotFound(path: String)
}

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

    private var packagePath: String!
    private var includePath: String!
    private var swiftPath: String!


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
            catch LanguageServerError.toolchainNotFound(let path) {                
                let params = ShowMessageParams(type: MessageType.error, message: "Unable to find the toolchain at: \(path)")
                let response = LanguageServerResponse.windowShowMessage(params: params)

                do {
                    return try self.transport.translate(response: response)
                }
                catch {
                    log("unable to convert error message: %{public}@", category: languageServerLogCategory, String(describing: error))
                }
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

        case .workspaceDidChangeWatchedFiles(let params):
            try doWorkspaceDidChangeWatchedFiles(params)

        case .textDocumentDidOpen(let params):
            try doDocumentDidOpen(params)

        case .textDocumentDidChange(let params):
            try doDocumentDidChange(params)
        
        case .textDocumentCompletion(let requestId, let params):
            return try doCompletion(requestId, params)

        case .textDocumentHover(let requestId, let params):
            return try doHover(requestId, params)

        case .textDocumentDefinition(let requestId, let params):
            return try doDefinition(requestId, params)

        case .textDocumentSignatureHelp(let requestId, let params):
            return try doSignatureHelp(requestId, params)

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
        capabilities.definitionProvider = true
        // capabilities.signatureHelpProvider = SignatureHelpOptions(triggerCharacters: ["("])
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
        let settings = (params.settings as! JSValue)[languageServerSettingsKey] ?? [:]

        self.toolchainPath = getToolchainPath(settings)
        log("configuration: toolchainPath set to %{public}@", category: languageServerLogCategory, toolchainPath)

        if !FileManager.default.fileExists(atPath: self.toolchainPath) {
            throw LanguageServerError.toolchainNotFound(path: self.toolchainPath)
        }

        self.packagePath = "\(projectPath!)/Package.swift"
        self.includePath = "\(toolchainPath!)/usr/lib/swift/pm"
        self.swiftPath = "\(toolchainPath!)/usr/bin/swift"

        if !FileManager.default.fileExists(atPath: self.swiftPath) {
            throw LanguageServerError.swiftToolNotFound(path: self.swiftPath)
        }

        // Force the generation of the `debug.yaml` file... need a better way.
        let _ = shell(
            tool: swiftPath,
            arguments: ["build"],
            currentDirectory: projectPath)

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

    private func doWorkspaceDidChangeWatchedFiles(_ params: DidChangeWatchedFilesParams) {
        // NOTE(owensd): This is not being fired and I don't know why...

        // Force the generation of the `debug.yaml` file... need a better way.
        let _ = shell(
            tool: swiftPath,
            arguments: ["build"],
            currentDirectory: projectPath)
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

    private func doDefinition(_ requestId: RequestId, _ params: TextDocumentPositionParams) throws -> LanguageServerResponse {
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

        guard
            let path = json["key.filepath"].string,
            let definitionOffset = json["key.offset"].integer,
            let length = json["key.length"].integer else {
                throw "unable to retrieve the file or offset in the file."
            }
        
        let fileContent = try String(contentsOfFile: path)
        let start = calculatePosition(in: fileContent, offset: definitionOffset)
        let end = Position(line: start.line, character: start.character + length)
        let range = Range(start: start, end: end)
        return .textDocumentDefinition(requestId: requestId, result: [Location(uri: "file://\(path)", range: range)])
    }

    private func doSignatureHelp(_ requestId: RequestId, _ params: TextDocumentPositionParams) throws -> LanguageServerResponse {
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

        if let decl = json["key.annotated_decl"].string {
            throw decl
        }

        throw "nyi"
    }

    func calculatePosition(in content: String, offset: Int) -> Position {
        var lineCounter = 0
        var characterCounter = 0

        for (idx, c) in content.characters.enumerated() {
            if idx == offset { break }
            if c == "\n" || c == "\r\n" {
                lineCounter += 1
                characterCounter = 0
            }
            else {
                characterCounter += 1
            }
        }

        return Position(line: lineCounter, character: characterCounter)
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

    private func getToolchainPath(_ settings: JSValue) -> String {
        if let toolchainPath = settings["toolchainPath"].string {
            return toolchainPath
        }

        let path = shell(tool: "/usr/bin/xcrun", arguments: ["-f", "swift"])
        return path
            .replacingOccurrences(of: "/usr/bin/swift", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

