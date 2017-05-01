/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import XCTest
@testable import langsrvlib

extension String: Error {}


/// These are just basic tests to ensure that the desired API usage contracts are maintained.
class InterfaceTests: XCTestCase {
    class TestSource: MessageSource {
        func run(received: (MessageData) -> ()) -> Never { fatalError("test run") }
    }

    class BytesToStringAdapter: MessageProtocolDataAdapter {
        func translate(data: MessageData) throws -> String {
            return "free conversion!"
        }
    }

    class StringToLanguageServerCommandAdapter: MessageProtocolDataAdapter {
        func translate(data: String) throws -> LanguageServerCommand {
            throw "nyi"
        }
    }

    func testMessageSourceUsage() {
        let _ = TestSource()
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
