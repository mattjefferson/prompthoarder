# Prompt Hoarder

A native macOS app for storing, finding, parameterizing, and reusing AI prompts. Menu bar-first access with a full main window for library management. Prompts stored as portable Markdown files; metadata and workflows indexed in SQLite for fast search.

## Key Features

- **Prompt Library** — Create, edit, tag, and organize prompts as Markdown files
- **Fast Search** — Full-text search (FTS5) across titles and content with tag/category filters
- **Template Variables** — Use `{{variable}}` placeholders with defaults and inline resolution
- **Workflows** — Build ordered sequences of prompts for multi-step processes
- **Menu Bar Access** — Search and copy prompts without leaving your current app
- **Local-First** — All data stays on your machine; no cloud required
- **Portable** — Prompts are plain Markdown files you own and control

## Tech Stack

| Component | Choice |
|-----------|--------|
| **Language** | Swift 6 (strict concurrency) |
| **UI Framework** | SwiftUI |
| **Architecture** | MVVM |
| **Database** | SQLite via [GRDB](https://github.com/groue/GRDB.swift) (FTS5) |
| **Markdown** | [swift-markdown](https://github.com/apple/swift-markdown) (Apple) |
| **Logging** | [swift-log](https://github.com/apple/swift-log) |
| **Updates** | [Sparkle](https://github.com/sparkle-project/Sparkle) |
| **Build System** | Swift Package Manager |
| **Min macOS** | 14.0 (Sonoma) |

---

## Project Status

**Pre-implementation** — Architecture and requirements are documented; development has not started.

See the documentation below for detailed specifications:

| Document | Description |
|----------|-------------|
| [`docs/prd.md`](docs/prd.md) | Product Requirements Document — features, use cases, scope |
| [`docs/plans/plan.md`](docs/plans/plan.md) | Implementation Plan v0.5 — architecture, data model, services, phases |

---

## Architecture Overview

### Module Structure

```
PromptHoarder/
├── Package.swift
├── Sources/
│   ├── PromptHoarderCore/       # Shared library (GUI + future CLI)
│   │   ├── Models/              # Prompt, Workflow, Tag, Category
│   │   ├── Storage/             # GRDB, VaultManager, DatabaseManager
│   │   ├── Services/            # Search, VariableResolver, Import/Export
│   │   └── Utilities/
│   └── PromptHoarder/           # macOS app
│       ├── App/                 # Entry point, AppState
│       ├── Views/               # SwiftUI views
│       ├── ViewModels/          # MVVM view models
│       ├── MenuBar/             # Status item, popover
│       └── Resources/           # Assets, localizations
├── Tests/
│   ├── PromptHoarderCoreTests/
│   └── PromptHoarderTests/
└── Scripts/
```

### Data Flow

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

### Source of Truth

- **Vault files are canonical** — Markdown + YAML front matter
- **SQLite is a derived index** — Fast search, can be rebuilt from vault at any time
- **File wins on conflict** — After user-driven conflict resolution

---

## Data Model

### Prompt File Format

Prompts are stored as Markdown files with YAML front matter:

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

### Variable Syntax

| Syntax | Description |
|--------|-------------|
| `{{name}}` | Simple variable |
| `{{ name }}` | Whitespace allowed |
| `{{name=default}}` | Variable with default value |
| `\{{escaped}}` | Literal `{{` (not a variable) |

Variable names must match: `[A-Za-z_][A-Za-z0-9_.-]*`

### File System Layout

```
~/Library/Application Support/PromptHoarder/
├── Vault/                              # Configurable location
│   └── prompts/
│       ├── 2f2b1d9c-8b9d-4f4d-9b5f-2a1b1b2c3d4e.md
│       └── ...
├── .backups/                           # Optional
│   └── 2024-01-15T10-30-00/
├── index.sqlite
├── index.sqlite-wal
└── index.sqlite-shm
```

---

## Core Services

| Service | Responsibility |
|---------|----------------|
| `VaultAccessCoordinator` | Security-scoped bookmark lifecycle, vault permissions |
| `VaultManager` | File I/O, vault scanning, atomic writes, import/export |
| `DatabaseManager` | SQLite lifecycle, migrations, index rebuild |
| `PromptStore` | CRUD operations, FTS5 search, archive/delete |
| `FileWatcher` | Monitor open files for external changes (DispatchSource) |
| `VariableResolver` | Parse `{{variables}}`, resolve with user values |
| `WorkflowStore` | Workflow CRUD, step ordering |

---

## UI Structure

### Main Window

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

### Menu Bar Popover

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

---

## Implementation Phases

### Phase 1: MVP

- Prompt CRUD with Markdown editor and preview
- Tags, categories, favorites
- Full-text search (FTS5)
- Template variable resolver
- Workflow builder and manual runner
- Menu bar popover with search and copy
- Import/export (single file, folder, full library)
- Settings (vault location, appearance)

### Phase 2: Power Features

- CLI tool (`search`, `get`, `list`, `copy`)
- Paste injection (Accessibility permission)
- Global hotkeys
- URL scheme (`prompthoarder://prompt/<id>`)
- Apple Shortcuts integration
- Smart collections (saved searches)

### Phase 3: Advanced

- iCloud sync with conflict resolution
- Prompt versioning
- Git-friendly export format
- Optional encryption

---

## Performance Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| Search latency | <200ms | FTS5 query (5K prompts) |
| App launch | <1s | Menu bar ready |
| Vault scan | <2s | Incremental via mtime |
| List view render | <100ms | DB-only, no file reads |
| Detail view open | <50ms | Single file read |

---

## Development

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Swift 6.0+

### Getting Started

Development has not started yet. Once it begins:

```bash
# Clone the repository
git clone https://github.com/mattjefferson/prompthoarder.git
cd prompthoarder

# Open in Xcode
open Package.swift

# Or build from command line
swift build

# Run tests
swift test
```

### Dependencies

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

## Issue Tracking

This project uses [Beads](https://github.com/Dicklesworthstone/beads_rust) for issue tracking. Issues are stored in `.beads/` and tracked in git.

```bash
# View issues ready to work
br ready

# List all open issues
br list --status=open

# Show issue details
br show <id>

# Create new issue
br create --title="..." --type=task --priority=2

# Update status
br update <id> --status=in_progress

# Close issue
br close <id> --reason="Completed"
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/prd.md`](docs/prd.md) | Product requirements, use cases, functional specs |
| [`docs/plans/plan.md`](docs/plans/plan.md) | Implementation plan, architecture, data model, services |
| [`AGENTS.md`](AGENTS.md) | Agent workflow instructions for Beads |

---

## License

[MIT License](LICENSE) — Copyright (c) 2026 Matt Jefferson
