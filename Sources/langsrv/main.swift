/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

 import langsrvlib

// Currently, the only supported language server protocol is `vscode-jsonrpc`.

print("disabled everything!")
let standardInput = StandardInputMessageSource()
let jsonrpc = LanguageServerProtocol()
// let langsrv = SwiftLanguageServer(source: standardInput, transport: jsonprc)
// langsrv.run()
