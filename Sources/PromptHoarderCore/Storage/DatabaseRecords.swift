import GRDB

struct PromptRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "prompts"

    var sqliteId: Int64?
    var id: String
    var title: String
    var filePath: String
    var categoryId: String?
    var isFavorite: Bool
    var isArchived: Bool
    var contentHash: String
    var bodyCache: String
    var createdAt: String
    var updatedAt: String
    var usageCount: Int
    var lastUsedAt: String?

    enum CodingKeys: String, CodingKey {
        case sqliteId = "sqlite_id"
        case id
        case title
        case filePath = "file_path"
        case categoryId = "category_id"
        case isFavorite = "is_favorite"
        case isArchived = "is_archived"
        case contentHash = "content_hash"
        case bodyCache = "body_cache"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case usageCount = "usage_count"
        case lastUsedAt = "last_used_at"
    }
}

struct TagRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "tags"

    var id: String
    var name: String
}

struct CategoryRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "categories"

    var id: String
    var name: String
}

struct PromptTagRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "prompt_tags"

    var promptId: String
    var tagId: String

    enum CodingKeys: String, CodingKey {
        case promptId = "prompt_id"
        case tagId = "tag_id"
    }
}

struct WorkflowRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "workflows"

    var id: String
    var title: String
    var description: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkflowStepRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "workflow_steps"

    var id: String
    var workflowId: String
    var promptId: String
    var orderIndex: Int
    var stepNotes: String?
    var variableOverrides: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workflowId = "workflow_id"
        case promptId = "prompt_id"
        case orderIndex = "order_index"
        case stepNotes = "step_notes"
        case variableOverrides = "variable_overrides"
    }
}
