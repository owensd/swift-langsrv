/*
 * Welcome to the Swift Language Server.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

 import Foundation
 import JSONLib

public final class SwiftLanguageServer {
    /// Runs the language server. This waits for input via `stdin`, parses it, and then triggers
    /// the appropriately registered handler. If no handler is found, then `unhandled` is triggered
    /// with the contents of the message.
    public func run(source: MessageSource) -> Never {
        source.run() { data in
        }
    }
}
