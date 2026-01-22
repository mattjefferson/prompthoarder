# Prompt Hoarder Implementation Plan

Version: 0.5

**Changelog:**
- v0.5: Added cloud sync ignore patterns (correct iCloud/Dropbox/editor temps), atomic write edge case handling (cross-volume, case-rename, disk full), introduced `PromptSummary` for efficient list views, clarified `body_cache` vs `content`
- v0.4: Added `FileWatcher` service for external edit detection, specified variable grammar edge cases (first `}}` wins), clarified `order_index` allows gaps, defined import ID conflict resolution dialog
- v0.3: Added `VaultAccessCoordinator` for bookmark lifecycle, `DatabaseManager` for rebuild process, clarified deletion semantics with app-layer enforcement, documented FTS rebuild strategy
- v0.2: Initial edge cases and constraints

## 1. Summary

Native macOS app for storing, finding, and reusing AI prompts. Menu bar-first access with full main window for management. Prompts stored as Markdown files; metadata/workflows in SQLite.

**Key decisions:**
- SwiftUI + MVVM architecture
- SPM multi-target: `PromptHoarderCore` (shared) + `PromptHoarder` (app)
- GRDB for SQLite (FTS5 search)
- Direct distribution + Sparkle updates
- CLI deferred to Phase 2 (architecture supports it)
- Paste injection deferred to Phase 2

---

## 2. Architecture

### 2.1 Module Structure

```
PromptHoarder/
├── Package.swift
├── Sources/
│   ├── PromptHoarderCore/       # Shared library (GUI + future CLI)
│   │   ├── Models/
│   │   ├── Storage/
│   │   ├── Services/
│   │   └── Utilities/
│   └── PromptHoarder/           # macOS app
│       ├── App/
│       ├── Views/
│       ├── ViewModels/
│       ├── MenuBar/
│       └── Resources/
├── Tests/
│   ├── PromptHoarderCoreTests/
│   └── PromptHoarderTests/
└── Scripts/
```

### 2.2 Layer Responsibilities

| Layer | Responsibility |
|-------|----------------|
| **Core/Models** | Domain types: `Prompt`, `Workflow`, `WorkflowStep`, `Tag`, `Category` |
| **Core/Storage** | SQLite via GRDB, file system ops, vault management |
| **Core/Services** | Search, variable resolver, import/export, vault sync |
| **App/ViewModels** | UI state, user actions, bindings to Core services |
| **App/Views** | SwiftUI views, menu bar popover, main window |

### 2.3 Data Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   SwiftUI View  │────▶│   ViewModel     │────▶│  Core Service   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                        ┌───────────────────────────────┴───────────────────────────────┐
                        ▼                                                               ▼
                ┌───────────────┐                                               ┌───────────────┐
                │   SQLite DB   │                                               │  Vault Files  │
                │  (metadata,   │                                               │   (.md)       │
                │   workflows,  │                                               └───────────────┘
                │   FTS index)  │
                └───────────────┘
```

### 2.4 Requirements, Constraints, and Edge Cases (Decisions)

These are explicit product/engineering constraints that affect the MVP design and prevent data-loss bugs.

**Source of truth**
- **Vault files are canonical** (Markdown + YAML front matter). SQLite is a **derived index/cache** for speed.
- App must be able to **rebuild the DB from the vault** at any time (Settings: "Rebuild Index").

**Atomicity + "no silent data loss"**
- All writes go through a single coordinator (actor) so we can enforce ordering and de-dup concurrent saves.
- Any operation that changes content/metadata uses **atomic file writes** (write temp + `replaceItemAt`) and then updates SQLite in a transaction.
- If DB update fails after writing files, the app shows an error and schedules a rescan; the vault remains correct.

**Atomic write edge cases:**
| Scenario | Handling |
|----------|----------|
| Cross-volume vault (external drive) | Temp file MUST be in vault directory (e.g., `.uuid.tmp`), not `/tmp`. Otherwise `replaceItemAt` falls back to non-atomic copy+delete. |
| Case-only rename (`Foo.md` → `foo.md`) | Use intermediate: `Foo.md` → `.foo.md.tmp` → `foo.md` (APFS case-insensitive workaround) |
| Disk full | Check available space before write (heuristic: 2× file size). Fail with clear error before partial write. |
| Permission denied | Fail fast with actionable error ("Cannot write to vault folder"). Don't leave temp files behind. |
| File locked by another process | Retry with backoff (3 attempts, 100ms/500ms/1s), then fail with user message. |

**External edits + conflicts**
- If a file changes on disk while a prompt is open in the editor, do not auto-overwrite.
- Show a conflict UI with actions: **Keep Mine**, **Use Disk Version**, **Duplicate as New Prompt** (creates a new UUID).
- **Detection mechanism** (two-layer approach):
  1. **FSEvents watcher**: Monitor open files in real-time. When change detected, show non-blocking banner in editor: "File changed on disk. [Reload] [Ignore]"
  2. **Save-time hash check**: Before any save, compare current file hash against hash at load time. If mismatch and FSEvents missed it, show conflict dialog.
- FSEvents lifecycle: start watching when prompt opens in editor, stop when editor closes. Use `DispatchSource.makeFileSystemObjectSource` for per-file monitoring.
- Edge case: if file is deleted externally while open, show alert with options: **Save as New File**, **Discard Changes**.

**Vault location + macOS sandboxing**
- Vault location must be stored as a **security-scoped bookmark** (works for sandboxed + non-sandboxed builds).
- Import/export and "change vault location" are always done via file pickers (NSOpenPanel/NSSavePanel) to keep permissions correct.
- **Bookmark lifecycle management** (via `VaultAccessCoordinator`):
  - Call `startAccessingSecurityScopedResource()` once at app launch; balance with `stopAccessingSecurityScopedResource()` at termination.
  - Store bookmark data in UserDefaults (key: `vaultBookmarkData`).
  - On bookmark resolution failure (user moved/renamed folder externally):
    1. Show alert: "Vault folder not found at expected location."
    2. Offer actions: **Locate Vault** (file picker to re-resolve), **Use Default** (reset to `~/Library/Application Support/PromptHoarder/Vault/`).
    3. After re-resolution, regenerate and store new bookmark.
  - Bookmark staleness check: attempt resolution on every app launch; if URL differs from stored path, update stored path.
  - For sandboxed builds: bookmark must be created from NSOpenPanel result to obtain persistent access rights.

**Deletion semantics**
- Prompts referenced by workflow steps cannot be deleted silently. MVP behavior:
  - Default action: **Archive** (hide from default views, keep file + DB row).
  - If user chooses Delete: block unless they explicitly remove/replace affected workflow steps (and show list of impacted workflows).
- **App-layer enforcement**: `PromptStore.delete()` must query `workflow_steps` for references *before* attempting deletion. The `ON DELETE RESTRICT` FK constraint is a safety net, not the primary enforcement mechanism.
- Delete flow: (1) check workflow references, (2) if referenced → return error with affected workflow IDs, (3) if not referenced → delete file atomically, (4) delete DB row in transaction.
- Archive flow: set `is_archived = 1` in DB and add `archived: true` to file front matter (keeps file/DB in sync).

**FTS correctness**
- FTS must have a stable integer key for row mapping; UUID remains the app-level identifier.

**Index rebuild process**
- "Rebuild Index" (Settings) must drop and recreate the entire SQLite database, including FTS tables.
- Process: (1) close DB connection, (2) delete `index.sqlite*`, (3) create fresh DB with schema, (4) full vault scan to repopulate.
- `sqlite_id` values are ephemeral and will differ after rebuild—this is acceptable since FTS is also rebuilt.
- During rebuild, app shows progress UI and blocks edits; menu bar remains functional for copy-only operations using cached data.
- If rebuild fails mid-process, delete partial DB and retry; vault files remain untouched.

**Import ID conflict resolution**
- When importing a file whose `id` (from front matter) already exists in the vault:
  1. **Single file import**: Show dialog with options:
     - **Import as Copy** (default): Generate new UUID, import as separate prompt. Log maps `oldId → newId`.
     - **Replace Existing**: Overwrite existing prompt file and DB entry.
     - **Skip**: Do not import this file.
  2. **Bulk import**: Same dialog with additional checkbox: "Apply to all conflicts"
- If imported file has no `id` in front matter: generate new UUID (no conflict possible).
- If imported file has malformed `id`: treat as no ID, generate new UUID, log warning.
- `ImportResult.previousId` tracks old→new UUID mapping for audit/undo purposes.

**Variable templating grammar**
- Define an explicit, testable grammar (see §5.3) including escaping and defaults.

---

## 3. Tech Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| UI Framework | SwiftUI | Modern, declarative, native menu bar support |
| Architecture | MVVM | Testable, clean separation, SwiftUI-friendly |
| Database | GRDB + SQLite | Best Swift SQLite library, FTS5 support, migrations |
| Build System | Swift Package Manager | Multi-target support, matches CodexBar pattern |
| Updates | Sparkle | Standard macOS update framework |
| Logging | swift-log | Structured logging, matches CodexBar |
| Markdown | swift-markdown (Apple) | Native parsing for preview |
| Concurrency | Swift 6 strict concurrency | Future-proof, thread safety |
| Min macOS | 14.0 (Sonoma) | SwiftUI improvements, modern APIs |

### 3.1 Dependencies

```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.9.0"),
    .package(url: "https://github.com/apple/swift-markdown", from: "0.5.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"), // Phase 2
]
```

---

## 4. Data Model

### 4.1 SQLite Schema

```sql
-- Prompts (SQLite is an index/cache; canonical content/metadata is in the vault file)
CREATE TABLE prompts (
    sqlite_id INTEGER PRIMARY KEY,          -- stable key for FTS content_rowid
    id TEXT NOT NULL UNIQUE,                -- UUID (app-level identifier; matches file front matter)
    title TEXT NOT NULL,
    file_path TEXT NOT NULL UNIQUE,         -- relative to vault
    category_id TEXT,                       -- FK to categories
    is_favorite INTEGER NOT NULL DEFAULT 0,
    is_archived INTEGER NOT NULL DEFAULT 0, -- MVP "soft delete"
    content_hash TEXT NOT NULL,             -- SHA256 of file content
    body_cache TEXT NOT NULL,               -- plain text for FTS
    created_at TEXT NOT NULL,               -- ISO8601
    updated_at TEXT NOT NULL,
    usage_count INTEGER NOT NULL DEFAULT 0,
    last_used_at TEXT,
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

-- Tags (many-to-many)
CREATE TABLE tags (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

-- Prefer case-insensitive uniqueness for human-entered tags.
CREATE UNIQUE INDEX tags_name_nocase ON tags(name COLLATE NOCASE);

CREATE TABLE prompt_tags (
    prompt_id TEXT NOT NULL,
    tag_id TEXT NOT NULL,
    PRIMARY KEY (prompt_id, tag_id),
    FOREIGN KEY (prompt_id) REFERENCES prompts(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Categories
CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE UNIQUE INDEX categories_name_nocase ON categories(name COLLATE NOCASE);

-- Workflows
CREATE TABLE workflows (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE workflow_tags (
    workflow_id TEXT NOT NULL,
    tag_id TEXT NOT NULL,
    PRIMARY KEY (workflow_id, tag_id),
    FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

CREATE TABLE workflow_steps (
    id TEXT PRIMARY KEY,
    workflow_id TEXT NOT NULL,
    prompt_id TEXT NOT NULL,
    order_index INTEGER NOT NULL,           -- No unique constraint; gaps allowed (e.g., 0,5,10)
    step_notes TEXT,
    variable_overrides TEXT,                -- JSON
    FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE,
    -- Deletion is handled at the product level (archive first; explicit delete requires user action).
    FOREIGN KEY (prompt_id) REFERENCES prompts(id) ON DELETE RESTRICT
);

-- Note: order_index intentionally has no UNIQUE constraint.
-- Gaps are allowed to simplify drag-drop reordering (insert at midpoint).
-- App sorts by order_index ASC; ties broken by id for stability.
-- Optional: compact indices to 0,1,2,... on workflow save (not required for correctness).

-- FTS5 index
CREATE VIRTUAL TABLE prompts_fts USING fts5(
    title,
    body_cache,
    content='prompts',
    content_rowid='sqlite_id'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER prompts_ai AFTER INSERT ON prompts BEGIN
    INSERT INTO prompts_fts(rowid, title, body_cache)
    VALUES (NEW.sqlite_id, NEW.title, NEW.body_cache);
END;

CREATE TRIGGER prompts_ad AFTER DELETE ON prompts BEGIN
    INSERT INTO prompts_fts(prompts_fts, rowid, title, body_cache)
    VALUES ('delete', OLD.sqlite_id, OLD.title, OLD.body_cache);
END;

CREATE TRIGGER prompts_au AFTER UPDATE ON prompts BEGIN
    INSERT INTO prompts_fts(prompts_fts, rowid, title, body_cache)
    VALUES ('delete', OLD.sqlite_id, OLD.title, OLD.body_cache);
    INSERT INTO prompts_fts(rowid, title, body_cache)
    VALUES (NEW.sqlite_id, NEW.title, NEW.body_cache);
END;
```

### 4.2 Prompt File Format

```markdown
---
id: 2f2b1d9c-8b9d-4f4d-9b5f-2a1b1b2c3d4e
title: Code Review Assistant
tags:
  - swift
  - code-review
category: Engineering
favorite: true
created_at: 2026-01-22T00:00:00Z
updated_at: 2026-01-22T00:00:00Z
---

# Code Review Assistant

Review the code for {{language}} focusing on:
- Correctness
- Security
- Style

## Context
{{context}}
```

**Front matter (recommendation):**
- Required: `id`
- Recommended for portability/rebuild: `title`, `tags`, `category`, `favorite`, timestamps
- SQLite is the fast index; when files and DB disagree, **file wins** after conflict resolution rules (see §2.4).

### 4.3 Swift Models

```swift
// Core/Models/PromptSummary.swift
// Lightweight struct for list views—DB-only, no file reads
struct PromptSummary: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var tags: [Tag]
    var category: Category?
    var isFavorite: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var usageCount: Int
    var lastUsedAt: Date?
    // Note: no content field—use Prompt for full content
}

// Core/Models/Prompt.swift
// Full struct for detail/edit views—includes file content
struct Prompt: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var content: String              // Full Markdown body (loaded from file on-demand)
    var tags: [Tag]
    var category: Category?
    var isFavorite: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var usageCount: Int
    var lastUsedAt: Date?

    var variables: [PromptVariable] { /* parsed from content */ }

    var summary: PromptSummary { /* project to lightweight form */ }
}

// Clarification: body_cache vs content
// - body_cache (DB column): plain text extracted from Markdown, used for FTS indexing
// - Prompt.content: full Markdown source, loaded from vault file only when needed

struct PromptVariable: Identifiable, Equatable, Sendable {
    let id: String                   // variable name
    var defaultValue: String?
}

struct Tag: Identifiable, Codable, Equatable, Sendable, Hashable {
    let id: UUID
    var name: String
}

struct Category: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
}

struct Workflow: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var description: String?
    var tags: [Tag]
    var steps: [WorkflowStep]
    var createdAt: Date
    var updatedAt: Date
}

struct WorkflowStep: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var promptId: UUID
    var orderIndex: Int
    var stepNotes: String?
    var variableOverrides: [String: String]
}
```

---

## 5. Core Services

### 5.1 VaultAccessCoordinator

Manages security-scoped bookmark lifecycle and vault access permissions.

```swift
protocol VaultAccessCoordinating: Sendable {
    /// Current vault URL (nil if bookmark unresolved)
    var vaultURL: URL? { get }

    /// Attempt to resolve stored bookmark; returns success
    func resolveBookmark() async -> Bool

    /// Store new bookmark from user-selected URL (NSOpenPanel result)
    func storeBookmark(for url: URL) throws

    /// Start accessing security-scoped resource (call at app launch)
    func startAccessing() -> Bool

    /// Stop accessing (call at app termination)
    func stopAccessing()
}

enum VaultAccessError: Error {
    case bookmarkNotFound
    case bookmarkStale(lastKnownPath: String)
    case accessDenied
}
```

**Implementation notes:**
- Singleton/actor to ensure balanced start/stop calls
- Store bookmark in UserDefaults as `Data`
- Log all access state transitions for debugging permission issues

### 5.2 VaultManager

Handles file system operations and vault scanning.

```swift
protocol VaultManaging: Sendable {
    var vaultURL: URL { get }

    func scanVault() async throws -> VaultScanResult
    func readPromptContent(id: UUID) async throws -> String
    func writePromptContent(id: UUID, content: String) async throws
    func deletePromptFile(id: UUID) async throws
    func importFiles(_ urls: [URL]) async throws -> [ImportResult]
    func exportPrompt(_ prompt: Prompt, to url: URL) async throws
    func exportLibrary(to url: URL) async throws
}

struct VaultScanResult {
    let newFiles: [URL]
    let modifiedFiles: [URL]
    let deletedIds: [UUID]
}

struct ImportResult {
    let url: URL
    let promptId: UUID?          // nil if import failed
    let error: ImportError?
    let previousId: UUID?        // non-nil if ID conflict resulted in new UUID
}

enum ImportError: Error {
    case invalidFormat
    case notUTF8
    case fileTooLarge
    case idConflict(existingId: UUID)
    case parseError(String)
}

enum WriteError: Error {
    case insufficientSpace(required: Int64, available: Int64)
    case permissionDenied(path: URL)
    case fileLocked(path: URL, afterRetries: Int)
    case directoryNotFound(path: URL)
}
```

**Vault scan performance (recommendation):**
- Track `mtime` + file size and only re-hash/re-parse files whose attributes changed.
- Ignore cloud sync artifacts, temp files, and OS metadata (see ignore patterns below).

**Ignore patterns for vault scanning:**
```swift
static let ignorePatterns: [String] = [
    // iCloud placeholders (dot prefix + .icloud suffix)
    #"^\..+\.icloud$"#,

    // Dropbox/OneDrive conflicts
    #".+ \(.*conflicted copy.*\).+"#,

    // Editor swap/temp files
    #".+\.swp$"#,
    #".+~$"#,
    #"^\.#.+"#,
    #"^#.+#$"#,

    // macOS metadata
    #"^\.DS_Store$"#,
    #"^\._.*"#,

    // Generic temp patterns
    #".+\.tmp$"#,
    #".+\.temp$"#,
]
```
- Log skipped files at debug level to help users diagnose "why isn't my prompt showing up?"
- OneDrive placeholder files (cloud-only) require attribute checks; defer to Phase 2 or document as known limitation.

### 5.2.1 DatabaseManager

Manages SQLite database lifecycle including migrations and rebuild.

```swift
protocol DatabaseManaging: Sendable {
    /// Current database connection state
    var isConnected: Bool { get }

    /// Initialize database, run migrations
    func initialize() async throws

    /// Full rebuild: drop DB, recreate schema, repopulate from vault
    func rebuild(progress: @escaping (RebuildProgress) -> Void) async throws

    /// Close connection (for rebuild or shutdown)
    func close() async
}

struct RebuildProgress: Sendable {
    let phase: RebuildPhase
    let filesProcessed: Int
    let totalFiles: Int
}

enum RebuildPhase: Sendable {
    case deletingOldDatabase
    case creatingSchema
    case scanningVault
    case indexingFiles
    case rebuildingFTS
    case complete
}
```

**Rebuild safety:**
- Rebuild acquires exclusive lock; all other DB operations wait or fail fast
- If rebuild fails, old DB is already deleted; app prompts to retry or quit
- Consider keeping `.sqlite.backup` until rebuild succeeds for recovery (optional enhancement)

### 5.3 PromptStore

SQLite operations via GRDB.

```swift
protocol PromptStoring: Sendable {
    // List views—fast, DB-only queries (no file reads)
    func fetchAllSummaries(includeArchived: Bool) async throws -> [PromptSummary]
    func search(query: String, filters: SearchFilters) async throws -> [PromptSummary]

    // Detail/edit views—loads content from vault file
    func fetch(id: UUID) async throws -> Prompt?

    // Mutations
    func save(_ prompt: Prompt) async throws
    func delete(id: UUID) async throws -> DeleteResult
    func archive(id: UUID) async throws
    func incrementUsage(id: UUID) async throws
}

enum DeleteResult {
    case deleted
    case blocked(referencingWorkflows: [WorkflowReference])
}

struct WorkflowReference: Sendable {
    let workflowId: UUID
    let workflowTitle: String
    let stepCount: Int  // how many steps reference this prompt
}

struct SearchFilters {
    var tags: [Tag]?
    var category: Category?
    var favoritesOnly: Bool
    var includeArchived: Bool
    var sortBy: SortOption
}

enum SortOption {
    case updatedAt
    case title
    case usageCount  // Phase 2
}
```

### 5.4 FileWatcher

Monitors open files for external changes using DispatchSource.

```swift
protocol FileWatching: Sendable {
    /// Start watching a file; calls handler on change or deletion
    func watch(url: URL, onChange: @escaping (FileChangeEvent) -> Void) -> FileWatchToken

    /// Stop watching (also called when token is deallocated)
    func stopWatching(_ token: FileWatchToken)
}

struct FileWatchToken: Sendable {
    let id: UUID
    let url: URL
}

enum FileChangeEvent: Sendable {
    case modified
    case deleted
    case renamed(newURL: URL)
}
```

**Implementation notes:**
- Use `DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask:)`
- Event mask: `.write | .delete | .rename`
- One source per open file; clean up on editor close
- Coalesce rapid events (debounce ~100ms) to avoid UI spam

### 5.5 VariableResolver

Parses and resolves `{{variables}}` in prompts.

```swift
protocol VariableResolving: Sendable {
    func extractVariables(from content: String) -> [PromptVariable]
    func resolve(content: String, values: [String: String]) -> String
    func validate(content: String) -> [VariableWarning]  // For template debugging
}

struct VariableWarning: Sendable {
    let range: Range<String.Index>
    let message: String  // e.g., "Invalid variable name: starts with digit"
}
```

**Variable grammar (specification):**
- Token form: `{{ name }}` (whitespace allowed around name)
- Name regex: `[A-Za-z_][A-Za-z0-9_.-]*`
- Optional inline default: `{{name=default value}}` (default runs until first `}}`)
- Escaping: `\{{` renders a literal `{{` and does not start a token
- Substitution scope: apply to the Markdown body only (exclude YAML front matter)

**Edge case behavior:**
| Input | Behavior | Rationale |
|-------|----------|-----------|
| `{{name=has }} more}}` | Default = `has `, leaves ` more}}` as literal | First `}}` wins (greedy) |
| `{{outer={{inner}}}}` | Extracts variable named `outer={{inner` | First `}}` wins |
| `{{}}` or `{{ }}` | Treated as literal text, no substitution | Invalid: empty name |
| `{{name` | Treated as literal text | Invalid: unclosed token |
| `{{name=}}` | Valid, empty default; substitutes to `""` if no value provided | Explicit empty default |
| `{{123name}}` | Treated as literal text | Invalid: name must start with letter/underscore |

**Parser behavior:**
- Invalid syntax → treat as literal text (no error thrown, no substitution)
- Log warning for invalid tokens to help users debug templates
- Future (Phase 2): consider `\}}` escape sequence to allow `}}` in defaults

### 5.6 WorkflowStore

```swift
protocol WorkflowStoring: Sendable {
    func fetchAll() async throws -> [Workflow]
    func fetch(id: UUID) async throws -> Workflow?
    func save(_ workflow: Workflow) async throws
    func delete(id: UUID) async throws
}
```

---

## 6. View Structure

### 6.1 Main Window

```
┌─────────────────────────────────────────────────────────────────┐
│ ◀ ▶  Prompt Hoarder                              🔍 Search...   │
├────────────────┬────────────────────────────────────────────────┤
│ 📚 All Prompts │  ┌────────────────────────────────────────────┐│
│ ⭐ Favorites   │  │ Code Review Assistant            ⭐ ⋯     ││
│ 📁 Categories  │  ├────────────────────────────────────────────┤│
│   └ Engineering│  │ # Code Review Assistant                    ││
│   └ Writing    │  │                                            ││
│ 🏷️ Tags        │  │ Review the code for {{language}}...        ││
│   └ swift      │  │                                            ││
│   └ prompt-eng │  │ ─────────────────────────────────────────  ││
│ 🔄 Workflows   │  │ Tags: swift, code-review                   ││
│ 🕐 Recent      │  │ Category: Engineering                      ││
│                │  │                                            ││
│                │  │ [Edit] [Preview] [Copy] [Use]              ││
│                │  └────────────────────────────────────────────┘│
└────────────────┴────────────────────────────────────────────────┘
```

### 6.2 Menu Bar Popover

```
┌──────────────────────────────────┐
│ 🔍 Search prompts...             │
├──────────────────────────────────┤
│ ⭐ Favorites    🔄 Workflows     │
├──────────────────────────────────┤
│ Code Review Assistant        ⏎   │
│ API Documentation Gen        ⏎   │
│ Bug Report Template          ⏎   │
│ ───────────────────────────────  │
│ 🕐 Recently Used                 │
│ Code Review Assistant            │
├──────────────────────────────────┤
│ ⚙️ Settings    📂 Open Library   │
└──────────────────────────────────┘
```

### 6.3 Variable Resolver Sheet

```
┌──────────────────────────────────┐
│ Fill Variables                   │
├──────────────────────────────────┤
│ language: [Swift            ▼]   │
│ context:  [                    ] │
│           [                    ] │
├──────────────────────────────────┤
│           [Cancel]  [Copy]       │
└──────────────────────────────────┘
```

### 6.4 View Hierarchy

```
App/
├── PromptHoarderApp.swift          # @main, menu bar + window
├── AppState.swift                  # Global observable state
├── Views/
│   ├── MainWindow/
│   │   ├── MainWindowView.swift
│   │   ├── SidebarView.swift
│   │   ├── PromptListView.swift
│   │   ├── PromptDetailView.swift
│   │   ├── PromptEditorView.swift
│   │   └── MarkdownPreviewView.swift
│   ├── Workflows/
│   │   ├── WorkflowListView.swift
│   │   ├── WorkflowBuilderView.swift
│   │   └── WorkflowRunnerView.swift
│   ├── MenuBar/
│   │   ├── MenuBarManager.swift
│   │   ├── MenuBarPopover.swift
│   │   ├── QuickSearchView.swift
│   │   └── VariableResolverSheet.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Shared/
│       ├── TagPickerView.swift
│       ├── CategoryPickerView.swift
│       └── PromptRowView.swift
├── ViewModels/
│   ├── LibraryViewModel.swift
│   ├── PromptDetailViewModel.swift
│   ├── WorkflowViewModel.swift
│   ├── MenuBarViewModel.swift
│   └── SearchViewModel.swift
```

---

## 7. Implementation Phases

### Phase 1: Foundation (MVP)

#### 1.1 Project Setup
- [ ] Create SPM package structure
- [ ] Configure targets: `PromptHoarderCore`, `PromptHoarder`
- [ ] Add dependencies (GRDB, swift-log, swift-markdown)
- [ ] Configure strict concurrency
- [ ] Set up SwiftLint, SwiftFormat
- [ ] Create app icon, assets

#### 1.2 Core Data Layer
- [ ] Implement SQLite schema + migrations (GRDB)
- [ ] Implement `DatabaseManager` (lifecycle, rebuild)
  - Full rebuild: delete DB → create schema → scan vault → repopulate
  - Progress reporting for UI
  - Exclusive lock during rebuild
- [ ] Implement `PromptStore` (CRUD, search with FTS5)
  - `delete()` returns `DeleteResult` with workflow references check
  - `archive()` for soft-delete (updates file front matter + DB)
- [ ] Implement `VaultAccessCoordinator` (bookmark lifecycle)
  - Store/resolve security-scoped bookmarks
  - Handle stale bookmarks with user prompts
  - Balance `startAccessing`/`stopAccessing` calls
- [ ] Implement `VaultManager` (file ops, vault scanning)
  - Temp files in same directory as target (e.g., `.uuid.tmp`) for true atomicity
  - Case-only rename workaround for APFS
  - Pre-write space check, permission validation
  - Retry with backoff for locked files
  - Ignore cloud sync artifacts (see ignore patterns in §5.2)
  - Log skipped files at debug level
- [ ] Implement file ↔ DB sync logic (file canonical, DB derived)
- [ ] Implement content hashing for change detection
- [ ] Implement `FileWatcher` (DispatchSource-based)
  - Monitor open files for write/delete/rename events
  - Debounce rapid events (~100ms)
  - Clean up watchers on editor close
- [ ] Handle external file edits gracefully
  - Real-time banner: "File changed on disk. [Reload] [Ignore]"
  - Save-time hash check as safety net
  - Conflict UI: Keep Mine / Use Disk / Duplicate as New
  - Deleted file UI: Save as New File / Discard Changes
- [ ] Optional backup service (configurable)
- [ ] Unit tests for storage layer

#### 1.3 Domain Services
- [ ] Implement `VariableResolver` (regex parsing, substitution)
  - First `}}` wins parsing strategy
  - Invalid syntax → literal text + warning log
  - `validate()` method for template debugging
  - Unit tests for all edge cases (see §5.5 table)
- [ ] Implement `TagStore`, `CategoryStore`
- [ ] Implement `WorkflowStore`
  - Sort steps by `order_index ASC, id` for stability
  - Optional: compact indices on save
- [ ] Implement import service (single file, folder)
  - ID conflict dialog: Import as Copy / Replace / Skip
  - Bulk import: "Apply to all conflicts" checkbox
  - Track old→new UUID mapping in `ImportResult`
- [ ] Implement export service (single prompt, full library)
- [ ] Unit tests for services

#### 1.4 Main Window UI
- [ ] App shell with NavigationSplitView
- [ ] Sidebar with sections (All, Favorites, Categories, Tags, Workflows)
- [ ] Prompt list view with search
- [ ] Prompt detail view (read mode)
- [ ] Prompt editor (Markdown editing)
- [ ] Markdown preview (swift-markdown)
- [ ] Tag picker, category picker
- [ ] Create/edit/duplicate/delete prompts
- [ ] Favorites toggle
- [ ] Dark mode support
- [ ] UI tests for main flows

#### 1.5 Menu Bar
- [ ] Menu bar status item
- [ ] Popover with search
- [ ] Quick results list
- [ ] Keyboard navigation
- [ ] Variable resolver sheet (inline)
- [ ] Copy to clipboard action
- [ ] "Open in main app" action
- [ ] Favorites/Recent tabs
- [ ] UI tests for menu bar

#### 1.6 Workflows (Basic)
- [ ] Workflow list view
- [ ] Workflow builder (add steps, reorder via drag-drop)
- [ ] Workflow runner (step-by-step, copy per step)
- [ ] Progress tracking for current run
- [ ] UI tests for workflows

#### 1.7 Import/Export
- [ ] Import single .md file
- [ ] Import folder (bulk)
- [ ] Export single prompt as .md
- [ ] Export full library as .zip
- [ ] Handle ID conflicts on import
- [ ] Handle weird files safely (non-UTF8, huge files, symlinks, cloud placeholders, conflicted copies)
- [ ] File dialogs, progress indicators

#### 1.8 Polish & Release Prep
- [ ] Settings view (vault location, appearance, backup toggle)
- [ ] Onboarding / first-run experience
- [ ] Sparkle integration for updates
- [ ] Error handling, user feedback
- [ ] Performance testing (5k prompts target)
- [ ] README, basic docs

### Phase 2: Power Features

#### 2.1 CLI
- [ ] Add `PromptHoarderCLI` target
- [ ] Add Commander dependency
- [ ] Commands: `search`, `get`, `list`, `copy`
- [ ] Output formats: plain, JSON
- [ ] Shell completion scripts

#### 2.2 Paste Injection
- [ ] Accessibility permission request flow
- [ ] Implement paste via CGEvent / AXUIElement
- [ ] Settings toggle for paste mode
- [ ] Fallback handling for incompatible apps

#### 2.3 Global Hotkeys
- [ ] KeyboardShortcuts integration
- [ ] Hotkey to open menu bar
- [ ] Hotkey to copy last used prompt
- [ ] Settings UI for hotkey configuration

#### 2.4 Enhanced Search
- [ ] Smart collections (saved searches)
- [ ] Sort by usage count
- [ ] Recent prompts tracking

#### 2.5 Workflow Enhancements
- [ ] Shared variables across workflow steps
- [ ] Workflow tags
- [ ] Duplicate workflow

#### 2.6 URL Scheme
- [ ] Register `prompthoarder://` scheme
- [ ] `prompt/<id>` - open prompt
- [ ] `prompt/<id>/copy` - copy to clipboard
- [ ] `workflow/<id>/run` - start workflow runner

#### 2.7 Apple Shortcuts
- [ ] App Intents for Shortcuts
- [ ] "Get Prompt" action
- [ ] "Search Prompts" action
- [ ] "Copy Prompt" action
- [ ] "Run Workflow" action

### Phase 3: Advanced

- [ ] iCloud sync with conflict resolution
- [ ] Prompt versioning
- [ ] Git-friendly export format
- [ ] Optional encryption
- [ ] Local trigger endpoint (opt-in)

---

## 8. Testing Strategy

### 8.1 Unit Tests (PromptHoarderCoreTests)

| Component | Coverage Target | Focus Areas |
|-----------|-----------------|-------------|
| PromptStore | 90% | CRUD, FTS search accuracy, filters |
| VaultManager | 85% | File ops, scan detection, atomic writes |
| VariableResolver | 95% | Edge cases, nested vars, escaping |
| WorkflowStore | 90% | Step ordering, cascade deletes |
| Import/Export | 85% | Format handling, conflict resolution |

### 8.2 UI Tests (PromptHoarderTests)

| Flow | Priority |
|------|----------|
| Create prompt end-to-end | P0 |
| Search and filter | P0 |
| Menu bar search + copy | P0 |
| Variable resolution | P0 |
| Workflow create + run | P1 |
| Import/export | P1 |
| Settings changes | P2 |

### 8.3 Performance Tests

Target: 5,000 prompts (stress test; typical usage expected to be <500)

| Operation | Target | Notes |
|-----------|--------|-------|
| Search latency | <200ms | FTS5 query + summary hydration |
| App launch | <1s to menu bar ready | DB open + initial query only |
| Vault scan | <2s | Incremental via mtime; full scan on rebuild |
| List view render | <100ms | Uses `PromptSummary`, no file reads |
| Detail view open | <50ms | Single file read |

---

## 9. File System Layout

### 9.1 Vault Structure

Default location (user-configurable):

```
~/Library/Application Support/PromptHoarder/
├── Vault/                              # Configurable location
│   └── prompts/
│       ├── 2f2b1d9c-8b9d-4f4d-9b5f-2a1b1b2c3d4e.md
│       ├── 3a4c2e8f-1d2a-4b5c-8e9f-0a1b2c3d4e5f.md
│       └── ...
├── .backups/                           # Optional, when backup enabled
│   └── 2024-01-15T10-30-00/
├── index.sqlite
├── index.sqlite-wal
└── index.sqlite-shm
```

**Note:** SQLite DB stays in Application Support even if vault location changes. This ensures the index is always in a known location and can rebuild from vault files if needed.

### 9.2 Exported Library

```
PromptHoarder-Export-2024-01-15/
├── prompts/
│   ├── code-review-assistant.md
│   └── ...
├── metadata.json          # Full metadata for reimport
└── README.md              # Human-readable index
```

---

## 10. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation | Status |
|------|--------|------------|------------|--------|
| FTS search too slow at scale | High | Low | Benchmark early; `PromptSummary` for list views; FTS on `body_cache` | ✅ Addressed |
| File/DB sync drift | High | Medium | File canonical; hash + mtime; rebuild command; `FileWatcher`; conflict UI | ✅ Addressed |
| Atomic write failures | Medium | Low | Same-dir temp files; case-rename workaround; space check; retry with backoff | ✅ Addressed |
| Cloud sync artifacts in vault | Medium | Medium | Comprehensive ignore patterns for iCloud/Dropbox/editors; debug logging | ✅ Addressed |
| Menu bar popover focus issues | Medium | Medium | Test across macOS versions, fallback behaviors | Open |
| Accessibility permission UX | Medium | Medium | Clear onboarding, graceful degradation (Phase 2) | Open |
| Markdown parsing edge cases | Low | Medium | Use Apple's swift-markdown, sanitize input | Open |
| Multi-process contention (future CLI) | Medium | Medium | WAL mode; single-writer coordinator; clear error UX | Open |
| Security-scoped bookmark staleness | Medium | Medium | `VaultAccessCoordinator`; re-resolve UI; bookmark refresh on launch | ✅ Addressed |

---

## 11. Resolved Decisions

1. **Vault location**: User-configurable from the start
   - Default: `~/Library/Application Support/PromptHoarder/Vault/`
   - Settings UI to change location
   - Migration helper when changing locations

2. **External edits**: Cannot prevent; handle gracefully with good error handling
   - Detect changes via hash mismatch on access
   - Reload content from file when mismatch detected
   - Surface errors clearly in UI (toast/alert)
   - Never silently lose user data

3. **Backup strategy**: Configurable option (off by default)
   - Settings toggle for auto-backup
   - When enabled: backup before destructive operations
   - Keep last N backups in `.backups/` (configurable N)
   - Manual "Backup Now" option always available

4. **Menu bar icon**: Static for MVP, dynamic in Phase 2

---

## 12. Success Metrics

- Search returns results in <200ms for 5,000 prompts
- Menu bar to clipboard in <3 interactions
- Zero data loss from file/DB sync issues
- 80%+ test coverage on Core module
- Clean build with strict concurrency
