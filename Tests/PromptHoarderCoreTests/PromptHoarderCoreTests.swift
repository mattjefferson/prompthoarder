@testable import PromptHoarderCore
import XCTest

final class PromptHoarderCoreTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(PromptHoarderCore.version.isEmpty)
    }
}
