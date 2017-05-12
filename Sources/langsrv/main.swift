/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import langsrvlib
import LanguageServerProtocol

// Currently, the only supported language server protocol is `vscode-jsonrpc`.

let inputBuffer = StandardInputBuffer()
let jsonrpc = JsonRpcProtocol()
let langsrv = SwiftLanguageServer(transport: jsonrpc)
langsrv.run(source: inputBuffer)
