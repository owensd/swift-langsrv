/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import langsrvlib
import LanguageServerProtocol
import JsonRpcProtocol

let inputBuffer = StandardInputOutputBuffer()
let jsonrpc = JsonRpcProtocol()
let langsrv = SwiftLanguageServer(transport: jsonrpc)
langsrv.run(source: inputBuffer)
