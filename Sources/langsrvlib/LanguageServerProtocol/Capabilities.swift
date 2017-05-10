/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import JSONLib

/// Client capabilities got introduced with the version 3.0 of the protocol. They therefore only
/// describe capabilities that got introduced in 3.x or later. Capabilities that existed in the 2.x
/// version of the protocol are still mandatory for clients. Clients cannot opt out of providing
/// them. So even if a client omits the `ClientCapabilities.textDocument.synchronization` it is
/// still required that the client provides text document synchronization (e.g. open, changed and
/// close notifications).
public struct ClientCapabilities {
	/// Workspace specific client capabilities.
	public var workspace: WorkspaceClientCapabilites? = nil

	/// Text document specific client capabilities.
	public var textDocument: TextDocumentClientCapabilities? = nil

	/// Experimental client capabilities.
	public var experimental: Any? = nil
}

/// `TextDocumentClientCapabilities` define capabilities the editor/tool provides on text documents.
public struct TextDocumentClientCapabilities {
    // TODO(owensd): fill this in
}

/// `WorkspaceClientCapabilites` define capabilities the editor/tool provides on the workspace:
public struct WorkspaceClientCapabilites {
    // TODO(owensd): fill this in
}

public struct ServerCapabilities {
	 /// Defines how text documents are synced. Is either a detailed structure defining each
	 /// notification or for backwards compatibility the `TextDocumentSyncKind` number.
	 public var textDocumentSync: TextDocumentSyncOptions?

	// /**
	//  * The server provides hover support.
	//  */
	// hoverProvider?: boolean;
	// /**
	//  * The server provides completion support.
	//  */
	// completionProvider?: CompletionOptions;
	// /**
	//  * The server provides signature help support.
	//  */
	// signatureHelpProvider?: SignatureHelpOptions;
	// /**
	//  * The server provides goto definition support.
	//  */
	// definitionProvider?: boolean;
	// /**
	//  * The server provides find references support.
	//  */
	// referencesProvider?: boolean;
	// /**
	//  * The server provides document highlight support.
	//  */
	// documentHighlightProvider?: boolean;
	// /**
	//  * The server provides document symbol support.
	//  */
	// documentSymbolProvider?: boolean;
	// /**
	//  * The server provides workspace symbol support.
	//  */
	// workspaceSymbolProvider?: boolean;
	// /**
	//  * The server provides code actions.
	//  */
	// codeActionProvider?: boolean;
	// /**
	//  * The server provides code lens.
	//  */
	// codeLensProvider?: CodeLensOptions;
	// /**
	//  * The server provides document formatting.
	//  */
	// documentFormattingProvider?: boolean;
	// /**
	//  * The server provides document range formatting.
	//  */
	// documentRangeFormattingProvider?: boolean;
	// /**
	//  * The server provides document formatting on typing.
	//  */
	// documentOnTypeFormattingProvider?: DocumentOnTypeFormattingOptions;
	// /**
	//  * The server provides rename support.
	//  */
	// renameProvider?: boolean;
	// /**
	//  * The server provides document link support.
	//  */
	// documentLinkProvider?: DocumentLinkOptions;
	// /**
	//  * The server provides execute command support.
	//  */
	// executeCommandProvider?: ExecuteCommandOptions;
	// /**
	//  * Experimental server capabilities.
	//  */
	// experimental?: any;
}


public struct TextDocumentSyncOptions {
	/// Open and close notifications are sent to the server.
	public var openClose: Bool?

	/// Change notificatins are sent to the server.
	public var change: TextDocumentSyncKind?

	/// Will save notifications are sent to the server.
	public var willSave: Bool?

	/// Will save wait until requests are sent to the server.
	public var willSaveWaitUntil: Bool?

	/// Save notifications are sent to the server.
	public var save: SaveOptions?
}

/// Save options.
public struct SaveOptions {
	/// The client is supposed to include the content on save.
	public var includeText: Bool?
}

/// Defines how the host (editor) should sync document changes to the language server.
public enum TextDocumentSyncKind: Int {
    /// Documents should not be synced at all.
	case none = 0

	/// Documents are synced by always sending the full content of the document.
	case full = 1

	/// Documents are synced by sending the full content on open. After that only incremental
	/// updates to the document are send.
	case incremental = 2
}


// MARK: Serialization

extension ClientCapabilities: Decodable {
	public static func from(json: JSValue) throws -> ClientCapabilities {
		// TODO(owensd): nyi
		return ClientCapabilities()
	}
}

extension ServerCapabilities: Encodable {}
extension TextDocumentSyncOptions: Encodable {}
extension TextDocumentSyncKind: Encodable {}