/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import XCTest
@testable import langsrvlib


/// These are just basic tests to ensure that the desired API usage contracts are maintained.
class InterfaceTests: XCTestCase {
    class TestSource: MessageSource {
        func start(received: (MessageData) -> ()) {}
        func stop() {}
    }

    class BytesToStringAdapter: MessageProtocolDataAdapter {
        func translate(data: MessageData) throws -> String {
            return "free conversion!"
        }
    }

    class StringToLanguageServerCommandAdapter: MessageProtocolDataAdapter {
        func translate(data: String) throws -> LanguageServerCommand {
            return .initialize
        }
    }

    func testMessageSourceUsage() {
        func onreceive(data: MessageData) {}
        let source = TestSource()
        source.start(received: onreceive)
    }

    func testBytesToStringAdapter() {
        let _ = BytesToStringAdapter()
    }

    func testStringToLanguageServerCommandAdapter() {
        let _ = StringToLanguageServerCommandAdapter()
    }

    static var allTests = [
        ("MessageSource::Usage", testMessageSourceUsage),
        ("MessageProtocolDataAdapter::Usage", testBytesToStringAdapter),
        ("StringToLanguageServerCommandAdapter", testStringToLanguageServerCommandAdapter),
    ]
}
