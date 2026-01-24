@testable import PromptHoarderCore
import GRDB
import XCTest

final class DatabaseManagerTests: XCTestCase {
    func testInitializeCreatesDatabaseFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("index.sqlite")

        let manager = DatabaseManager(dbURL: dbURL)
        try await manager.initialize()

        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
    }

    func testRebuildCreatesFreshDatabase() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("index.sqlite")

        let manager = DatabaseManager(dbURL: dbURL)
        try await manager.initialize()
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))

        try await manager.rebuild { _ in }
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
    }
}
