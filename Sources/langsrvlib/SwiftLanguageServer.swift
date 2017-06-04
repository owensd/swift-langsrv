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

                guard let response = try self.process(command: command, transport: self.transport) else { return nil }
                return try self.transport.translate(response: response)
            }
            catch {
                log("unable to convert message into a command: %{public}@", category: languageServerLogCategory, String(describing: error))
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
        buildPath = "\(projectPath!)/.build"

        sourcekitd_initialize()

        var capabilities = ServerCapabilities()
        capabilities.textDocumentSync = .kind(.full)
        //capabilities.hoverProvider = true
        capabilities.completionProvider = CompletionOptions(resolveProvider: nil, triggerCharacters: ["."])
        //capabilities.signatureHelpProvider = SignatureHelpOptions(triggerCharacters: ["."])
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
        sourcekitd_shutdown()
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

        guard let content = openDocuments[uri] else {
            throw "attempting to do completion on an unopened document? \(uri)"
        }
        let offset = calculateOffset(in: content, line: params.position.line, character: params.position.character)
        log("content:\n%{public}@", category: languageServerLogCategory, content)
        log("calculated %{public}@", category: languageServerLogCategory, "offset: \(offset), line: \(params.position.line), character: \(params.position.character)")

        let result = try sourcekit(completion: content, offset: offset, uri: URL(string: uri)!.path)
        log("sourcekit response:\n%{public}@", category: languageServerLogCategory, result.stringify())

        let completionList = CompletionList(
            isIncomplete: false,
            items: result["key.results"].array?.map {
                CompletionItem(
                    label: $0["key.description"].string ?? "",
                    kind: kind($0["key.kind"].string),
                    documentation: $0["key.doc.brief"].string ?? ""
                )
            } ?? []
        )

        return .textDocumentCompletion(requestId: requestId, result: .completionList(completionList))
    }

    private func inputsFor(module: String) throws -> [String] {
        let yaml = try String(contentsOfFile: "\(buildPath!)/debug.yaml")
        guard let moduleIndex = yaml.range(of: "<\(module).module>") else {
            throw "Unable to find the module in the debug.yaml file."
        }

        // This is some super hacky and fragile "yaml" parsing code... it's good enough for now.
        func value(key: String) throws -> [String] {
            let label = "\(key): ["
            guard let startIndex = yaml.range(of: label, range: moduleIndex.lowerBound..<yaml.endIndex) else {
                throw "Unable to find the key '\(label)' in the \(module) module description."
            }
            guard let endIndex = yaml.range(of: "]\n", range: startIndex.upperBound..<yaml.endIndex) else {
                throw "Error parsing the value for key '\(label)'."
            }

            return yaml
                .substring(with: startIndex.upperBound..<endIndex.lowerBound)
                .replacingOccurrences(of: "\"", with: "")
                .components(separatedBy: ",")
        }

        return
            (try value(key: "sources")) +
            ["-module-name", module] +
            (try value(key: "other-args")) +
            ["-I"] + (try value(key: "import-paths"))
    }

    private func sourcekit(completion content: String, offset: Int64, uri: DocumentUri) throws -> JSValue {
        let components = uri.components(separatedBy: "/")
        let index = components.index(of: "Sources")!
        let module: String = components[index + 1].hasSuffix(".swift") ? packageName : components[index + 1]

        let inputs = try inputsFor(module: module)
        log("sourcekitd: parsed compiler args: %{public}@", category: languageServerLogCategory, inputs)

        let file = URL(string: uri)!.path
        var compilerargs = inputs.map({ sourcekitd_request_string_create($0) })
        let dict = [
            sourcekitd_uid_get_from_cstr("key.request"): sourcekitd_request_uid_create(sourcekitd_uid_get_from_cstr("source.request.codecomplete")),
            sourcekitd_uid_get_from_cstr("key.name"): sourcekitd_request_string_create(file),
            sourcekitd_uid_get_from_cstr("key.sourcefile"): sourcekitd_request_string_create(file),
            sourcekitd_uid_get_from_cstr("key.sourcetext"): sourcekitd_request_string_create(content),
            sourcekitd_uid_get_from_cstr("key.offset"): sourcekitd_request_int64_create(offset),
            sourcekitd_uid_get_from_cstr("key.compilerargs"): sourcekitd_request_array_create(&compilerargs, compilerargs.count)
        ]

        var keys = Array(dict.keys.map({ $0 as sourcekitd_uid_t? }))
        var values = Array(dict.values)
        guard let req = sourcekitd_request_dictionary_create(&keys, &values, dict.count) else {
            throw "unable to create the request from the give values."
        }        

        let res: sourcekitd_object_t = sourcekitd_send_request_sync(req)
        defer { sourcekitd_response_dispose(res) }
        log("sourcekitd: response received", category: languageServerLogCategory)

        let failed = sourcekitd_response_is_error(res)
        if failed {
            let errorKind = sourcekitd_response_error_get_kind(res)
            let errorDescription = sourcekitd_response_error_get_description(res)
            log("sourcekitd: response failed (%d)", category: languageServerLogCategory, errorKind)
            log("sourcekitd: response error\n%{public}@", category: languageServerLogCategory, String(cString: errorDescription!))
            throw "sourcekitd: failed getting response"
        }
        else {
            let value = sourcekitd_response_get_value(res)
            let cstr = sourcekitd_variant_json_description_copy(value)

            let message = String(cString: cstr!)
            log("sourcekitd: response received\n%{public}@", category: languageServerLogCategory, message)
            
            return try JSValue.parse(message)
        }
    }
}

