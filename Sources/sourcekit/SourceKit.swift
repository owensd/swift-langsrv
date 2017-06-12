/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import Foundation
import sourcekitd

public struct SourceKitError: Error {
    public let message: String
}

public func sourcekit(initialize: Bool) {
    if initialize {
        sourcekitd_initialize()
    }
    else {
        sourcekitd_shutdown()
    }
}

/// Performs a SourceKit request for a `completion` request as defined here:
/// https://github.com/apple/swift/blob/master/tools/SourceKit/docs/Protocol.md#code-completion
public func sourcekit(completion content: String, offset: Int64, packageName: String, projectPath: String, filePath: String) throws -> String {
    let module = getModuleName(for: filePath, in: packageName)
    let dict = [
        sourcekitd_uid_get_from_cstr("key.request"): sourcekitd_request_uid_create(sourcekitd_uid_get_from_cstr("source.request.codecomplete")),
        sourcekitd_uid_get_from_cstr("key.name"): sourcekitd_request_string_create(filePath),
        sourcekitd_uid_get_from_cstr("key.sourcefile"): sourcekitd_request_string_create(filePath),
        sourcekitd_uid_get_from_cstr("key.sourcetext"): sourcekitd_request_string_create(content),
        sourcekitd_uid_get_from_cstr("key.offset"): sourcekitd_request_int64_create(offset),
        sourcekitd_uid_get_from_cstr("key.compilerargs"): try compilerArgs(projectPath: projectPath, module: module)
    ]

    return try request(dict)
}

/// Performs a SourceKit request for a `cursorInfo` request as defined here:
/// https://github.com/apple/swift/blob/master/tools/SourceKit/docs/Protocol.md#cursor-info
public func sourcekit(cursorInfo content: String, offset: Int64, packageName: String, projectPath: String, filePath: String) throws -> String {
    let module = getModuleName(for: filePath, in: packageName)
    let dict = [
        sourcekitd_uid_get_from_cstr("key.request"): sourcekitd_request_uid_create(sourcekitd_uid_get_from_cstr("source.request.cursorinfo")),
        sourcekitd_uid_get_from_cstr("key.sourcefile"): sourcekitd_request_string_create(filePath),
        sourcekitd_uid_get_from_cstr("key.sourcetext"): sourcekitd_request_string_create(content),
        sourcekitd_uid_get_from_cstr("key.offset"): sourcekitd_request_int64_create(offset),
        sourcekitd_uid_get_from_cstr("key.compilerargs"): try compilerArgs(projectPath: projectPath, module: module)
    ]

    return try request(dict)
}

private func request(_ dict: [sourcekitd_uid_t: sourcekitd_object_t?]) throws -> String {
    var keys = Array(dict.keys.map { $0 as sourcekitd_uid_t?})
    var values = Array(dict.values)
    guard let req = sourcekitd_request_dictionary_create(&keys, &values, dict.count) else {
        throw SourceKitError(message: "unable to create the request from the give values.")
    }

    let res: sourcekitd_object_t = sourcekitd_send_request_sync(req)
    defer { sourcekitd_response_dispose(res) }

    let failed = sourcekitd_response_is_error(res)
    if failed {
        let errorKind = String(describing: sourcekitd_response_error_get_kind(res))
        let errorDescription = String(describing: sourcekitd_response_error_get_description(res))
        throw SourceKitError(message: "kind: \(errorKind), description: \(errorDescription)")
    }
    else {
        let value = sourcekitd_response_get_value(res)
        let cstr = sourcekitd_variant_json_description_copy(value)
        let message = String(cString: cstr!)       
        return message
    }
}

private func getModuleName(for filePath: String, in packageName: String) -> String {
    let components = filePath.components(separatedBy: "/")
    guard let index = components.index(of: "Sources") else { return packageName }
    if index + 1 >= components.count { return packageName }
    let value = components[index + 1]
    return value.hasSuffix(".swift") ? packageName : value
}


private func compilerArgs(projectPath: String, module: String) throws -> sourcekitd_object_t {
    let buildPath = "\(projectPath)/.build"
    let yaml = try String(contentsOfFile: "\(buildPath)/debug.yaml")
    guard let moduleIndex = yaml.range(of: "<\(module).module>") else {
        throw SourceKitError(message: "Unable to find the module ('\(module)') in the debug.yaml file.")
    }

    // This is some super hacky and fragile "yaml" parsing code... it's good enough for now.
    func value(key: String) throws -> [String] {
        let label = "\(key): ["
        guard let startIndex = yaml.range(of: label, range: moduleIndex.lowerBound..<yaml.endIndex) else {
            throw SourceKitError(message: "Unable to find the key '\(label)' in the \(module) module description.")
        }
        guard let endIndex = yaml.range(of: "]\n", range: startIndex.upperBound..<yaml.endIndex) else {
            throw SourceKitError(message: "Error parsing the value for key '\(label)'.")
        }

        return yaml
            .substring(with: startIndex.upperBound..<endIndex.lowerBound)
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: ",")
    }

    var args =
        ((try value(key: "sources")) +
        ["-module-name", module] +
        (try value(key: "other-args")) +
        ["-I"] + (try value(key: "import-paths"))).map { sourcekitd_request_string_create($0) }
    return sourcekitd_request_array_create(&args, args.count)
}
