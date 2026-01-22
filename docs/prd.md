# Prompt Hoarder (macOS) PRD

## 1. Overview

**Product:** Prompt Hoarder  
**Platform:** Native macOS app  
**Primary job:** Store, find, parameterize, and reuse AI prompts (Markdown), including manual workflows (ordered sets of prompts) that a user follows step by step.

### 1.1 Problem statement
AI prompt users often accumulate prompts across notes, docs, chats, and files. Retrieval is slow, reuse is inconsistent, and multi-step prompt sequences are hard to repeat.

### 1.2 Solution
Prompt Hoarder provides:
- A local-first prompt library with Markdown content.
- Fast search and filtering by tags, categories, and favorites.
- Prompt templates with variables.
- Workflows as ordered prompt sequences (manual execution).
- Menu bar access for quick copy and optional paste into the active app.
- Extensible trigger surfaces (hotkeys, URL scheme, Apple Shortcuts) for devices and macro tools.

### 1.3 Guiding principles
- **Fast retrieval:** Search first, navigation second.
- **Low friction usage:** Copy is always available; paste is optional and permission-gated.
- **Local-first:** Offline by default. Clear privacy posture.
- **Portability:** Prompts stored as Markdown files for user ownership.
- **Resilience:** The library should survive index loss and recover via rebuild.

---

## 2. Goals and non-goals

### 2.1 Goals
1. Store prompts as Markdown with lightweight metadata.
2. Find prompts quickly via full-text search and filters.
3. Reuse prompts through variables and defaults.
4. Repeat multi-step processes via manual workflows.
5. Access prompts and workflows from a menu bar popover without context switching.

### 2.2 Non-goals (MVP)
- Automated workflow execution against AI APIs.
- Auto-submission to websites or chat UIs.
- Multi-user collaboration and shared libraries.
- Browser extensions.
- Cross-platform desktop support.

---

## 3. Users and use cases

### 3.1 Primary users
- Power users who maintain many prompts.
- Users who repeat processes using prompt sequences.
- Users who need prompts while working inside other apps (browser, IDE, email).

### 3.2 Primary use cases
- Create and save a prompt in Markdown.
- Tag and categorize prompts.
- Search prompts by text and metadata.
- Parameterize prompts using `{{variables}}`.
- Build workflows as ordered prompt sequences.
- Use prompts or workflows from the menu bar to copy or paste into the active app.
- Trigger a specific prompt or workflow via hotkey or automation (Phase 2+).

---

## 4. Scope and milestones

### 4.1 Phase 1 (MVP)
- Prompt library (create, edit, delete, duplicate)
- Markdown editor and preview
- Tags, categories, favorites
- Full-text search
- Template variables and resolver
- Workflows (manual runner)
- Menu bar popover for search + copy, optional paste
- Import and export

### 4.2 Phase 2
- Smart collections (saved searches)
- Workflow runner enhancements (shared variables across steps)
- Global hotkeys
- URL scheme
- Apple Shortcuts actions
- Optional sync (iCloud) with conflict-aware rules

### 4.3 Phase 3
- Device button support via hotkeys, Shortcuts, URL scheme
- Optional local trigger endpoint (opt-in)
- Versioning and Git-friendly exports

---

## 5. Functional requirements

## 5.1 Prompts

### 5.1.1 Prompt content
- Prompt body is stored as Markdown.
- Supports Markdown commonly used in prompts: headings, lists, code fences, inline code, bold/italic, links.

### 5.1.2 Prompt metadata
Minimum metadata:
- ID (UUID)
- Title
- Tags (0..n)
- Category (0..1)
- Favorite (boolean)
- Created at, updated at timestamps

Optional metadata (Phase 2+):
- Usage count
- Last used timestamp
- Notes
- Source

### 5.1.3 Prompt actions
- Create prompt
- Edit prompt
- Preview rendered Markdown
- Duplicate prompt
- Delete prompt (soft delete optional)
- Copy prompt
- Paste prompt (permission gated)
- Export prompt as `.md` file

### 5.1.4 Acceptance criteria
- User can create and save a Markdown prompt.
- User can tag prompts and filter by tag.
- Search finds prompts by words in title or body.
- Copy works from both main app and menu bar.

---

## 5.2 Organization and search

### 5.2.1 Organization model
- Tags: many per prompt.
- Categories: optional single category per prompt.
- Favorites: fast access list.

### 5.2.2 Search requirements
- Full-text search across title and body.
- Filters for tags, categories, favorites.
- Sort options: updated date, alphabetical (usage sort in Phase 2).

### 5.2.3 Performance targets
- Search should feel instant for typical libraries.
- Target: under 200 ms search results for 5,000 prompts on common hardware.

### 5.2.4 Acceptance criteria
- Combined search + filters return correct results.
- Menu bar search returns results quickly and consistently.

---

## 5.3 Parameterization (templates)

### 5.3.1 Syntax
- Variables use `{{variable_name}}` placeholders in Markdown.
- Variable names are case-sensitive and must match `[A-Za-z0-9_]+`.
- Variable defaults can be stored in metadata.

### 5.3.2 Resolve flow
- When a user chooses “Use Prompt”, the app detects variables and prompts for values.
- The user can accept defaults and override as needed.
- Result is a resolved prompt string ready for copy or paste.

### 5.3.3 Acceptance criteria
- Variables are detected reliably.
- Resolver output preserves Markdown formatting.
- Resolved content can be copied and pasted from the menu bar.

---

## 5.4 Workflows (manual chains)

### 5.4.1 Workflow definition
A workflow is an ordered list of steps. Each step references a prompt.

Workflow fields:
- ID (UUID)
- Title
- Description (optional)
- Tags (optional)
- Steps (ordered list)

Step fields:
- Prompt reference (prompt ID)
- Step notes (optional)
- Variable overrides (optional)

### 5.4.2 Workflow runner
- Presents steps in order.
- For each step:
  - show prompt content (preview)
  - collect variables if needed
  - actions: Copy, Paste (optional), Mark Done, Next, Back

### 5.4.3 Acceptance criteria
- User can create a workflow with multiple steps.
- User can reorder steps.
- Runner supports copy for each step and tracks progress for the current run.

---

## 5.5 Menu bar access and injection

### 5.5.1 Menu bar requirements
- Status bar icon opens a popover.
- Popover includes:
  - search box
  - results list
  - quick actions: Copy, Paste, Open in main app
  - variable resolver UI when needed
  - quick access tabs or filters: Favorites, Recent, Workflows

### 5.5.2 Injection modes
1. Copy to clipboard (default)
2. Paste into active app (optional)
   - Requires macOS permissions (Accessibility and possibly Input Monitoring)
   - Implementation should favor a safe and predictable paste method

### 5.5.3 Acceptance criteria
- User can retrieve and copy a prompt from the menu bar without switching apps.
- If paste mode is enabled, user can paste into the active app reliably.

---

## 6. Data storage and persistence

### 6.1 Storage choice
- Prompt bodies are stored as Markdown files on disk.
- Metadata and search index are stored in SQLite.

This is workable when the SQLite database is treated as an index and operational store, while files remain portable.

### 6.2 Source of truth
- Markdown files are the canonical store for prompt content.
- SQLite is the canonical store for fast search indexing and app-only operational metadata.

### 6.3 File layout
Recommended layout:
- `~/Library/Application Support/PromptHoarder/Vault/`
  - `prompts/`
    - `<prompt-id>.md`
  - `workflows/` (optional, Phase 2+ if workflows are file-based)
  - `index.sqlite`

### 6.4 Prompt file format
Each prompt file is Markdown and includes a minimal YAML front matter header with stable ID.

Example:
```yaml
---
id: 2f2b1d9c-8b9d-4f4d-9b5f-2a1b1b2c3d4e
title: "Code Review Assistant"
tags: ["code-review", "swift", "quality"]
category: "Engineering"
---

# Goal
Review the code for correctness, security, and style...

## Instructions
...
```

Notes:
- Keeping some metadata in front matter improves portability.
- Operational fields (usage stats, pinned state) can remain SQLite-only.

### 6.5 SQLite contents
SQLite tables store:
- normalized metadata for fast filtering and workflow references
- a cached copy of prompt body for indexing (or extracted plain text)
- full-text search index (SQLite FTS5 recommended)
- operational metadata: usage count, last used, UI state

### 6.6 Consistency rules
- Prompt ID is the stable key across file and DB.
- On app start and periodically, run a vault scan:
  - detect new files
  - detect removed files
  - detect modified files (hash or modified timestamp)
  - update cache and FTS index
- On save:
  - write file to a temp file and atomically replace
  - update SQLite row and FTS index in the same save operation

### 6.7 Failure and recovery
- If SQLite is deleted or corrupted, rebuild it by scanning the vault folder.
- If a file is missing but DB entry exists, mark prompt as missing and allow recovery tools.

---

## 7. Proposed data model

### 7.1 Prompt
- `id` (UUID, primary key)
- `title` (text)
- `file_path` (text, relative)
- `tags` (relation or JSON)
- `category` (text or relation)
- `is_favorite` (bool)
- `created_at` (timestamp)
- `updated_at` (timestamp)
- `content_hash` (text)
- `body_cache` (text, for indexing)
- `usage_count` (int, optional)
- `last_used_at` (timestamp, optional)

### 7.2 Workflow
- `id` (UUID)
- `title` (text)
- `description` (text, optional)
- `tags` (relation or JSON)
- `created_at`, `updated_at`

### 7.3 WorkflowStep
- `id` (UUID)
- `workflow_id` (UUID)
- `prompt_id` (UUID)
- `order_index` (int)
- `step_notes` (text, optional)
- `variable_overrides` (JSON, optional)

### 7.4 Search index
- SQLite FTS table indexed on:
  - `title`
  - `body_cache`
  - `notes` (optional)

---

## 8. UX requirements

### 8.1 Main app screens
- Library view with sidebar navigation:
  - All Prompts
  - Favorites
  - Categories
  - Tags
  - Workflows
  - Recent
- Prompt detail:
  - Markdown editor
  - Preview toggle
  - Variables inspector (detected)
  - Actions: Copy, Paste (optional), Export
- Workflow builder:
  - list of steps with drag and drop reordering
- Workflow runner:
  - step-by-step progression with Copy and Paste actions

### 8.2 Menu bar popover
- Search focused by default.
- Keyboard navigation for results.
- One-click copy.
- If variables exist, show a small form inline before final copy or paste.

---

## 9. Security, privacy, permissions

### 9.1 Privacy
- Local-first storage.
- No cloud required for MVP.
- No data leaves the machine without explicit export or sync opt-in.

### 9.2 Permissions
- Paste injection requires Accessibility permissions.
- Global hotkeys may require Input Monitoring depending on implementation.
- App must explain permissions with a clear onboarding screen and allow the feature to remain disabled.

### 9.3 Optional encryption (Phase 2+)
- Encrypt the SQLite database or prompt content with a user passphrase.
- Keep export flow explicit to avoid accidental plaintext leakage.

---

## 10. Integrations and triggers

### 10.1 Global hotkeys (Phase 2)
- Open menu bar search
- Copy last used prompt
- Run a specific workflow

### 10.2 URL scheme (Phase 2)
- `prompthoarder://prompt/<id>`
- `prompthoarder://workflow/<id>/run`

### 10.3 Apple Shortcuts actions (Phase 2)
- Get prompt by ID or search query
- Resolve variables
- Copy to clipboard
- Open workflow runner

### 10.4 Device buttons (Phase 3)
- Map device button to:
  - hotkey, or
  - Shortcut calling URL scheme

Optional advanced: local trigger endpoint (opt-in with token).

---

## 11. Non-functional requirements

- Fast startup and quick menu bar response.
- Search performance within targets.
- Reliable vault scanning and conflict handling.
- Graceful permission handling for paste and hotkeys.
- Works offline.

---

## 12. Risks and mitigations

### 12.1 Risks
- Paste injection may be inconsistent across apps.
- Two-store design can drift if not reconciled.
- Sync later can introduce conflicts.

### 12.2 Mitigations
- Clipboard-first as default.
- Treat SQLite as rebuildable index plus operational store.
- Stable IDs embedded in file header.
- Vault scan and hash-based change detection.

---

## 13. MVP checklist

### Must have
- Prompt CRUD with Markdown editor
- Tags, categories, favorites
- Full-text search
- Variable resolver
- Workflow builder and runner (manual)
- Menu bar popover with search and copy
- Import and export

### Should have
- Paste into active app (permission gated)
- Basic conflict detection for external edits

### Could have
- Smart collections
- Usage tracking
- iCloud sync (Phase 2+)

---

## 14. Open decisions

- How much metadata stays in YAML front matter vs SQLite only.
- Workflow storage: SQLite-only vs file-based format for portability.
- Encryption approach and user experience.
- Conflict strategy for external file edits and future sync.
