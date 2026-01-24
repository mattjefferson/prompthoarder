import GRDB

enum DatabaseMigrations {
    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try createCoreTables(in: db)
            try createIndexes(in: db)
            try createFullTextSearch(in: db)
        }

        return migrator
    }

    private static func createCoreTables(in db: Database) throws {
        try db.create(table: "categories") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
        }

        try db.create(table: "tags") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
        }

        try db.create(table: "prompts") { t in
            t.column("sqlite_id", .integer).primaryKey()
            t.column("id", .text).notNull().unique()
            t.column("title", .text).notNull()
            t.column("file_path", .text).notNull().unique()
            t.column("category_id", .text)
                .references("categories", onDelete: .restrict)
            t.column("is_favorite", .boolean).notNull().defaults(to: false)
            t.column("is_archived", .boolean).notNull().defaults(to: false)
            t.column("content_hash", .text).notNull()
            t.column("body_cache", .text).notNull()
            t.column("created_at", .text).notNull()
            t.column("updated_at", .text).notNull()
            t.column("usage_count", .integer).notNull().defaults(to: 0)
            t.column("last_used_at", .text)
        }

        try db.create(table: "prompt_tags") { t in
            t.column("prompt_id", .text).notNull()
                .references("prompts", onDelete: .cascade)
            t.column("tag_id", .text).notNull()
                .references("tags", onDelete: .cascade)
            t.primaryKey(["prompt_id", "tag_id"])
        }

        try db.create(table: "workflows") { t in
            t.column("id", .text).primaryKey()
            t.column("title", .text).notNull()
            t.column("description", .text)
            t.column("created_at", .text).notNull()
            t.column("updated_at", .text).notNull()
        }

        try db.create(table: "workflow_steps") { t in
            t.column("id", .text).primaryKey()
            t.column("workflow_id", .text).notNull()
                .references("workflows", onDelete: .cascade)
            t.column("prompt_id", .text).notNull()
                .references("prompts", onDelete: .restrict)
            t.column("order_index", .integer).notNull()
            t.column("step_notes", .text)
            t.column("variable_overrides", .text)
        }
    }

    private static func createIndexes(in db: Database) throws {
        try db.execute(sql: "CREATE UNIQUE INDEX tags_name_nocase ON tags(name COLLATE NOCASE)")
        try db.execute(sql: "CREATE UNIQUE INDEX categories_name_nocase ON categories(name COLLATE NOCASE)")

        try db.create(index: "prompts_category_id", on: "prompts", columns: ["category_id"])
        try db.create(index: "prompts_is_favorite", on: "prompts", columns: ["is_favorite"])
        try db.create(index: "prompts_is_archived", on: "prompts", columns: ["is_archived"])
        try db.create(index: "prompts_updated_at", on: "prompts", columns: ["updated_at"])
        try db.create(index: "prompt_tags_tag_id", on: "prompt_tags", columns: ["tag_id"])
        try db.create(index: "workflow_steps_workflow_id", on: "workflow_steps", columns: ["workflow_id"])
        try db.create(index: "workflow_steps_prompt_id", on: "workflow_steps", columns: ["prompt_id"])
    }

    private static func createFullTextSearch(in db: Database) throws {
        try db.create(virtualTable: "prompts_fts", using: FTS5()) { t in
            t.synchronize(withTable: "prompts")
            t.column("title")
            t.column("body_cache")
        }
    }
}
