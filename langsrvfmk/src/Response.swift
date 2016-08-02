/* --------------------------------------------------------------------------------------------
* Copyright (c) David Owens II (owensd.io). All rights reserved.
* Licensed under the MIT License. See License.md in the project root for license information.
* ------------------------------------------------------------------------------------------ */

import Foundation

public struct Response {
	private static let version = "2.0"

	public let id: ID
	public let result: AnyObject

	public var json: [String:AnyObject] {
		return ["jsonrpc": (Response.version), "id": id, "result": result]
	}
}