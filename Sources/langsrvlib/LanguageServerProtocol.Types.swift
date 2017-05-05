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

/// A notification message. A processed notification message must not send a response back.
/// They work like events.
public struct NotificationMessage<ParamsType>: Message {
    /// The language server protocol always uses "2.0" as the jsonrpc version.
    public let jsonrpc: String = "2.0"

    /// The language server command method to be invoked.
    public var method: String

    /// The paramaters for the message. 
    public var params: ParamsType

    /// Initializes a new `NotificationMessage`. 
    public init(method: String, params: ParamsType) {
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

/// Position in a text document expressed as zero-based line and character offset. A position
/// is between two characters like an 'insert' cursor in a editor.
public struct Position {
    /// Line position in a document (zero-based).
    public var line: Int

    /// Character offset on a line in a document (zero-based).
    public var character: Int
}

/// A range in a text document expressed as (zero-based) start and end positions. A range is
/// comparable to a selection in an editor. Therefore the end position is exclusive.
public struct Range {
    /// The range's start position.
    public var start: Position

    /// The range's end position.
    public var end: Position
}

/// Represents a location inside a resource, such as a line inside a text file.
public struct Location {
    /// The URI of the document the location belongs to.
	var uri: DocumentUri

    /// The full range that should make up the range.
	var range: Range
}

/// Represents a diagnostic, such as a compiler error or warning. Diagnostic objects are only
/// valid in the scope of a resource.
public struct Diagnostic {
	/// The range at which the message applies.
	var range: Range

	 /// The diagnostic's severity. Can be omitted. If omitted it is up to the client to interpret
     /// diagnostics as error, warning, info or hint.
	var severity: Int?

	/// The diagnostic's code. Can be omitted.
	var code: DiagnosticCode?

	/// A human-readable string describing the source of this diagnostic, e.g. 'typescript' or
    /// 'super lint'.
	var source: String?

	/// The diagnostic's message.
	var message: String
}

/// A code to use within the `Diagnostic` type.
public enum DiagnosticCode {
    case number(Int)
    case string(String)
}

/// The protocol currently supports the following diagnostic severities:
public enum DiagnosticSeverity: Int {
	/// Reports an error.
	case error = 1

	/// Reports a warning.
	case warning = 2

	/// Reports an information.
	case information = 3

	/// Reports a hint.
	case hint = 4
}

/// Represents a reference to a command. Provides a title which will be used to represent a 
/// command in the UI. Commands are identitifed using a string identifier and the protocol 
/// currently doesn't specify a set of well known commands. So executing a command requires 
/// some tool extension code.
public struct Command {
	/// Title of the command, like `save`.
	var title: String

    /// The identifier of the actual command handler.
	var command: String

	/// Arguments that the command handler should be invoked with.
	var arguments: [Any]?
}

/// A textual edit applicable to a text document.
///
/// If multiple TextEdits are applied to a text document, all text edits describe changes made
/// to the initial document version. Execution wise text edits should applied from the bottom 
/// to the top of the text document. Overlapping text edits are not supported.
public struct TextEdit {
	/// The range of the text document to be manipulated. To insert text into a document create
    /// a range where start === end.
	public var range: Range

	/// The string to be inserted. For delete operations use an empty string.
	public var newText: String
}

/// Describes textual changes on a single text document. The text document is referred to as a
/// `VersionedTextDocumentIdentifier` to allow clients to check the text document version before
/// an edit is applied.
public struct TextDocumentEdit {
	/// The text document to change.
	public var textDocument: VersionedTextDocumentIdentifier

    /// The edits to be applied.
	public var edits: [TextEdit]
}

/// A workspace edit represents changes to many resources managed in the workspace. The edit
/// should either provide changes or documentChanges. If documentChanges are present they are
/// preferred over changes if the client can handle versioned document edits.
public struct WorkspaceEdit {
	/// Holds changes to existing resources.
	//public var changes?: { [uri: string]: TextEdit[]; };

	/// An array of `TextDocumentEdit`s to express changes to specific a specific
	/// version of a text document. Whether a client supports versioned document
	/// edits is expressed via `WorkspaceClientCapabilites.versionedWorkspaceEdit`.
	public var documentChanges: [TextDocumentEdit]?
}

/// Text documents are identified using a URI. On the protocol level, URIs are passed as strings.
/// The corresponding JSON structure looks like this:
public class TextDocumentIdentifier {
    /// The text document's URI.
	public var uri: DocumentUri

    public init(uri: DocumentUri) {
        self.uri = uri
    }
}

/// An item to transfer a text document from the client to the server.
public struct TextDocumentItem {
	/// The text document's URI.
	public var uri: DocumentUri

	/// The text document's language identifier.
	public var languageId: String

	/// The version number of this document (it will strictly increase after each
	/// change, including undo/redo).
	public var version: Int

	/// The content of the opened text document.
	public var text: String
}

/// An identifier to denote a specific version of a text document.
public final class VersionedTextDocumentIdentifier: TextDocumentIdentifier {
	/// The version number of this document.
	public var version: Int

    public init(uri: DocumentUri, version: Int) {
        self.version = version
        super.init(uri: uri)
    }
}

/// A parameter literal used in requests to pass a text document and a position inside that document.
public struct TextDocumentPositionParams {
	/// The text document.
	public var textDocument: TextDocumentIdentifier

	/// The position inside the text document.
	public var position: Position
}

/// A document filter denotes a document through properties like language, schema or pattern.
/// Examples are a filter that applies to TypeScript files on disk or a filter the applies to
/// JSON files with name package.json:
///
/// { language: 'typescript', scheme: 'file' }
///{ language: 'json', pattern: '**/package.json' }
public struct DocumentFilter {
	/// A language id, like `typescript`.
	public var language: String?

	/// A Uri [scheme](#Uri.scheme), like `file` or `untitled`.
	public var scheme: String?

	/// A glob pattern, like `*.{ts,js}`.
	public var pattern: String?
}

/// A document selector is the combination of one or many document filters.
public typealias DocumentSelector = [DocumentFilter];


// MARK: Parameter Types

// TODO(owensd): implement this properly...
public typealias DocumentUri = String

/// The set of parameters that are used for the `initialize` method.
public struct InitializeParams {
	 /// The process Id of the parent process that started the server. Is `null` if the process
     /// has not been started by another process.
	 /// If the parent process is not alive then the server should exit (see exit notification)
     /// its process.
	var processId: Int?

	 /// The rootPath of the workspace. Is `null` if no folder is open.
	@available(*, deprecated:3.0, message: "The `rootUri` member should be used instead.")
	var rootPath: String? = nil

	 /// The root URI of the workspace. Is `null`` if no folder is open. If both `rootPath` and
     /// `rootUri` are set, `rootUri` wins.
	var rootUri: DocumentUri?  // TODO(owensd): Fix this to be a URI type, what's in foundation?

	/// User provided initialization options.
	var initializationOptions: AnyObject? = nil

	// /**
	//  * The capabilities provided by the client (editor or tool)
	//  */
	// capabilities: ClientCapabilities;

	// /**
	//  * The initial trace setting. If omitted trace is disabled ('off').
	//  */
	// trace?: 'off' | 'messages' | 'verbose';

}

/// The base protocol offers support for request cancellation. To cancel a request, a notification
/// message with the following properties is sent:
/// Notification:
///   method: `$/cancelRequest`
///   params: `CancelParams` defined as follows:
public struct CancelParams {
    /// The ID of the request to cancel.
    public var id: RequestId
}