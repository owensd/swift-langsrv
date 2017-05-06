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


// MARK: Serialization

extension ClientCapabilities: Decodable {
	public static func from(json: JSValue) throws -> ClientCapabilities {
		// TODO(owensd): nyi
		return ClientCapabilities()
	}
}