/* --------------------------------------------------------------------------------------------
* Copyright (c) David Owens II (owensd.io). All rights reserved.
* Licensed under the MIT License. See License.md in the project root for license information.
* ------------------------------------------------------------------------------------------ */

import Foundation
import Swifter
import langsrvfmk

// The language service works with a basic JSON-RPC2 service.
// The `method` is the command for sourcekitten
// The `params` make up the additional data

/* Example package structure:
{
       "jsonrpc": "2.0",
       "method": "complete",
       "params": {
               // The name of the file the user is currently editing
               "source": "main.swift",

               // The full text buffer the user is currently editing
               "buffer": "import ...",

               // The character offset (assumes UTF8) into the content buffer
               "offset": 13,

               // The root path for the project
               "projectRoot": "path/to/project",

               // The path, relative to `projectRoot`, for all of the source files that
               // should be considered for completions.
               "sources": [ "main.swift", "other.swift", "foo/yep.swift" ],

               // The list of frameworks that should be considered for completion.
               "frameworks": [ "SourceKitten.framework" ]
       }
}
*/

extension Request {
	init(request: HttpRequest) throws {
		let data = NSData(bytes: request.body, length: request.body.count)
		guard let object = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) else {
			throw ErrorCodes.ParseError
		}
		guard let json = object as? [String:AnyObject] else { throw ErrorCodes.ParseError }

		try self.init(json: json)
	}
}


let defaultPort: in_port_t = 6004;

let server = HttpServer()
server.POST["/complete"] = { request in
	do {
		let req = try Request(request: request)
		switch req.command {
		case .Complete: return HttpResponse.OK(.Json(Commands.complete(req).json))
		}
	}
	catch {
		return HttpResponse.BadRequest(.Text("\(error)"))
	}
}

try server.start(defaultPort)
print("Server has started ( port = \(defaultPort) ). Try to connect now...")

NSRunLoop.mainRunLoop().run()
