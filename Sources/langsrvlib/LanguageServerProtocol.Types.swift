/*
 * This file defines all of the necessary types for implementing the 'Language Server Protocol'
 * as defined here: https://github.com/Microsoft/language-server-protocol/. 
 *
 * This is a common, JSON-RPC based protocol used to define interactions between a client endpoint,
 * such as a code editor, and a language server instance that is running. The transport mechanism
 * is not defined, nor is the language the server is running against.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

/// A general message as defined by JSON-RPC. 
public protocol Message {
    /// The language server protocol always uses "2.0" as the jsonrpc version.
    var jsonrpc: String { get }
}

/// A request ID used to coordinate request/response pairs.
public enum RequestId {

    /// The numeric value for the request ID.
    case number(Int)

    /// The string value for the request ID.
    case string(String)
}

/// A request message to describe a request between the client and the server. Every processed
/// request must send a response back to the sender of the request.
public struct RequestMessage<ParamsType>: Message {
    /// The language server protocol always uses "2.0" as the jsonrpc version.
    public let jsonrpc: String = "2.0"

    /// The ID for the given request. This is used to coordinate request/response pairs across
    /// the client and server.
    public var id: RequestId

    /// The language server command method to be invoked.
    public var method: String

    /// The paramaters for the message. 
    public var params: ParamsType

    /// Initializes a new `RequestMessage`. 
    public init(id: RequestId, method: String, params: ParamsType) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// Any given `ResponseMessage` can either return a result or an error.
public enum ResponseResult {
    /// The result to return back with the response.
    case result(AnyObject)

    /// The error to return back with the response.
    case error(code: Int, message: String, data: AnyObject?)
}

/// Response Message sent as a result of a request. If a request doesn't provide a result value the
/// receiver of a request still needs to return a response message to conform to the JSON RPC
/// specification. The result property of the ResponseMessage should be set to `null` in this case
/// to signal a successful request.
public struct ResponseMessage: Message {
    /// The language server protocol always uses "2.0" as the jsonrpc version.
    public let jsonrpc: String = "2.0"

    /// The ID for the given request. This is used to coordinate request/response pairs across
    /// the client and server. This is `null` when there is no associated response ID.
    public var id: RequestId?

    /// The result that is returned back with the response.
    /// Note: The spec has this as `result` or `error`, however, this is a deficiency with the
    /// type modelling of TypeScript. There are two possibilities: a result or an error. There
    /// is no case where both `result` and `error` can both have a value or both be `null`.
    public var result: ResponseResult

    /// Create a new response message. It is important that the `id` value match the corresponding
    /// request, otherwise the client/server cannot sync properly.
    public init(id: RequestId? = nil, result: ResponseResult) {
        self.id = id
        self.result = result
    }
}

/// A set of pre-defined error codes that can be used when an error occurs.
public enum /*namespace*/ ErrorCodes {
	// Defined by JSON RPC
	static let parseError = -32700
	static let invalidRequest = -32600
	static let methodNotFound = -32601
	static let invalidParams = -32602
	static let internalError = -32603
	static let serverErrorStart = -32099
	static let serverErrorEnd = -32000
	static let serverNotInitialized = -32002
	static let unknownErrorCode = -32001

	// Defined by the protocol.
	static let requestCancelled = -32800
}

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
	public var rootUri: String?  // TODO(owensd): Fix this to be a URI type, what's in foundation?

    // TODO(owensd): Finish up the InitializeParams

	// /**
	//  * User provided initialization options.
	//  */
	// initializationOptions?: any;

	// /**
	//  * The capabilities provided by the client (editor or tool)
	//  */
	// capabilities: ClientCapabilities;

	// /**
	//  * The initial trace setting. If omitted trace is disabled ('off').
	//  */
	// trace?: 'off' | 'messages' | 'verbose';

}