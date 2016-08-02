/* --------------------------------------------------------------------------------------------
 * Copyright (c) David Owens II (owensd.io). All rights reserved.
 * Licensed under the MIT License. See License.md in the project root for license information.
 * ------------------------------------------------------------------------------------------ */

import Foundation
import SourceKittenFramework


public enum Commands {
	public static func complete(request: Request) -> Response {
		// sourcekitten complete --file main.swift --offset 54 --compilerargs -- "/Users/owensd/Projects/vscode-swift/collateral/swift-3.0-395e967875/basic/Sources/Cards.swift"

		let args: [String] = ["complete", "--text", "\(request.buffer)", "--offset", "\(request.offset)"]
		let sourcekitten = NSTask()
		sourcekitten.launchPath = "/usr/local/bin/sourcekitten"
		sourcekitten.arguments = args

		let pipe = NSPipe()
		sourcekitten.standardOutput = pipe

		sourcekitten.launch()

		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		let json: [AnyObject] = try! NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as! [AnyObject]

		return Response(id: request.id, result: json)
	}
}