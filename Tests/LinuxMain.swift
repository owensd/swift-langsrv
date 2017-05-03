import XCTest
@testable import langsrvlibTests

XCTMain([
    testCase(HeaderAcceptanceTests.allTests),
    testCase(HeaderRejectionTests.allTests)
])
