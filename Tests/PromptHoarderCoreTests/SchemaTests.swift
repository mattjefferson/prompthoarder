@testable import PromptHoarderCore
import GRDB
import XCTest

final class SchemaTests: XCTestCase {
    func testInitialMigrationCreatesTablesAndIndexes() throws {
        let dbQueue = try DatabaseQueue()
        try DatabaseMigrations.migrator().migrate(dbQueue)

        try dbQueue.read { db in
            let tables = try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'table'"
            )

            XCTAssertTrue(tables.contains("prompts"))
            XCTAssertTrue(tables.contains("tags"))
            XCTAssertTrue(tables.contains("categories"))
            XCTAssertTrue(tables.contains("prompt_tags"))
            XCTAssertTrue(tables.contains("workflows"))
            XCTAssertTrue(tables.contains("workflow_steps"))
            XCTAssertTrue(tables.contains("prompts_fts"))

            let indexes = try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'index'"
            )

            XCTAssertTrue(indexes.contains("tags_name_nocase"))
            XCTAssertTrue(indexes.contains("categories_name_nocase"))
            XCTAssertTrue(indexes.contains("prompts_category_id"))
            XCTAssertTrue(indexes.contains("prompts_is_favorite"))
            XCTAssertTrue(indexes.contains("prompts_is_archived"))
            XCTAssertTrue(indexes.contains("prompts_updated_at"))
            XCTAssertTrue(indexes.contains("prompt_tags_tag_id"))
            XCTAssertTrue(indexes.contains("workflow_steps_workflow_id"))
            XCTAssertTrue(indexes.contains("workflow_steps_prompt_id"))
        }
    }
}
