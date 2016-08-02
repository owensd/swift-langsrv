/* --------------------------------------------------------------------------------------------
* Copyright (c) David Owens II (owensd.io). All rights reserved.
* Licensed under the MIT License. See License.md in the project root for license information.
* ------------------------------------------------------------------------------------------ */

import Foundation

public enum Command {
	case Complete

	public init?(_ s: String?) {
		guard let s = s else { return nil }

		switch s {
		case "complete": self = .Complete
		default: return nil
		}
	}
}

public enum ErrorCodes: Int, ErrorType {
	case ParseError = -32700			// Parse error: Invalid JSON was received by the server.
										// An error occurred on the server while parsing the JSON text.
	case InvalidRequest = -32600		// Invalid Request: The JSON sent is not a valid Request object.
	case MethodNotFound = -32601		// Method not found: The method does not exist / is not available.
	case InvalidParams = -32602			// Invalid params: Invalid method parameter(s).
	case InternalError = -32603			// Internal error: Internal JSON-RPC error.

	// -32000 to -32099	Server error	Reserved for implementation-defined server-errors.
}

public typealias FileName = String
public typealias Path = String
public typealias Buffer = String
public typealias ID = Int

public struct Request {
	private static let version = "2.0"

	public let id: ID
	public let command: Command
	public let source: FileName
	public let buffer: Buffer
	public let offset: Int
	public let projectRoot: Path

	public init(json: [String:AnyObject]) throws {
		guard json.count > 0 else { throw ErrorCodes.InvalidRequest }

		guard let jsonrpc: String = Request.parse(json, "jsonrpc") else { throw ErrorCodes.InvalidRequest }
		guard jsonrpc == Request.version else {
			assertionFailure("Invalid JSON RPC version: \(jsonrpc)")
			throw ErrorCodes.InvalidRequest
		}

		guard let responseId: NSNumber = Request.parse(json, "id") else { throw ErrorCodes.InvalidRequest }
		self.id = responseId.integerValue

		guard let method: String = Request.parse(json, "method") else { throw ErrorCodes.InvalidRequest }
		guard let command = Command(method) else {
			assertionFailure("Command was not of the supported command: \(method)")
			throw ErrorCodes.InvalidRequest
		}
		self.command = command

		guard let params: [String:AnyObject] = Request.parse(json, "params") else { throw ErrorCodes.InvalidRequest }

		guard let source: FileName = Request.parse(params, "source") else { throw ErrorCodes.InvalidRequest }
		self.source = source

		guard let buffer: Buffer = Request.parse(params, "buffer") else { throw ErrorCodes.InvalidRequest }
		self.buffer = buffer

		guard let offset: NSNumber = Request.parse(params, "offset") else { throw ErrorCodes.InvalidRequest }
		self.offset = offset.integerValue

		guard let projectRoot: Path = Request.parse(params, "projectRoot") else { throw ErrorCodes.InvalidRequest }
		self.projectRoot = projectRoot
	}

	private static func parse<T>(dict: [String:AnyObject], _ key: String) -> T? {
		guard let property = dict[key] else {
			assertionFailure("Missing `\(key)` property")
			return nil
		}

		guard let value = property as? T else {
			assertionFailure("The member `\(key)` is of the wrong type, expected: \(T.self)")
			return nil
		}

		return value
	}
}