/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib

/// The set of parameters that are used for the `initialize` method.
public struct InitializeParams<OptionsType: Decodable> {
	 /// The process Id of the parent process that started the server. Is `null` if the process
     /// has not been started by another process.
	 /// If the parent process is not alive then the server should exit (see exit notification)
     /// its process.
	public var processId: Int?

	 /// The rootPath of the workspace. Is `null` if no folder is open.
	@available(*, deprecated:3.0, message: "The `rootUri` member should be used instead.")
	public var rootPath: String? = nil

	 /// The root URI of the workspace. Is `null`` if no folder is open. If both `rootPath` and
     /// `rootUri` are set, `rootUri` wins.
	public var rootUri: DocumentUri? = nil

	/// User provided initialization options.
	public var initializationOptions: OptionsType? = nil

	/// The capabilities provided by the client (editor or tool).
	public var capabilities = ClientCapabilities()

	/// The initial trace setting. If omitted trace is disabled ('off').
	public var trace: TraceSetting? = nil
}

extension InitializeParams: Encodable {
    public func toJson() -> JSValue {
        let json: JSValue = [
            "nyi": "nyi"
        ]

        return json
    }
}

// MARK: Serialization

extension InitializeParams {
    public static func from(json: JSValue) throws -> InitializeParams {
        guard let _ = json.object else { throw "The `params` value must be a dictionary." }
        let processId = json["processId"].integer ?? nil
        let rootPath = json["rootPath"].string ?? nil
        let rootUri = json["rootUri"].string ?? nil
        let initializationOptions = try OptionsType.from(json: json["intializationOptions"])
        let capabilities = try ClientCapabilities.from(json: json["capabilities"])
        let trace = try TraceSetting.from(json: json["trace"])

        return InitializeParams(
            processId: processId,
            rootPath: rootPath,
            rootUri: rootUri,
            initializationOptions: initializationOptions,
            capabilities: capabilities,
            trace: trace
        )
    }
}