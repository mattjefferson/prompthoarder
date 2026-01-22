import XCTest
@testable import PromptHoarderCore

final class PromptHoarderCoreTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(PromptHoarderCore.version.isEmpty)
    }
}
