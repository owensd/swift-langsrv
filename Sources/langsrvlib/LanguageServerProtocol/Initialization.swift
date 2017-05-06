/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

/// The set of parameters that are used for the `initialize` method.
public struct InitializeParams {
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
	public var rootUri: DocumentUri?

	/// User provided initialization options.
	public var initializationOptions: AnyObject? = nil

	/// The capabilities provided by the client (editor or tool).
	public var capabilities: ClientCapabilities

	/// The initial trace setting. If omitted trace is disabled ('off').
	public var trace: TraceSetting?
}
