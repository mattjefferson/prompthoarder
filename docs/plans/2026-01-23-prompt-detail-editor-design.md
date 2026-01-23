# Prompt Detail + Editor Design

## Goals
- Deliver a read-only prompt detail view with clear actions (copy/use/edit).
- Provide an editor sheet with title + body editing and optional live preview.
- Keep detail and list in sync via the in-memory model used by `LibraryViewModel`.
- Preserve the Liquid Glass visual language used in the main window.

## Non-Goals
- Persistence or database wiring (in-memory only for this phase).
- Advanced variable highlighting (defer to a later pass).
- Rich Markdown feature set beyond SwiftUI's built-in rendering.

## Assumptions
- `PromptSummary` is extended to include detail fields instead of introducing a new model.
- The list, detail, and editor all share `LibraryViewModel` as the source of truth.
- Markdown rendering uses `AttributedString(markdown:)` or equivalent SwiftUI support.

## Data Model Updates
Extend `PromptSummary` with detail fields:
- `content: String`
- `createdAt: Date`
- `updatedAt: Date`
- `lastUsedAt: Date?`
- `categoryName: String?`
- `notes: String?` (optional, for future use)

`LibraryViewModel` adds helpers:
- `prompt(for id: UUID) -> PromptSummary?`
- `updatePrompt(id: UUID, mutate: (inout PromptSummary) -> Void)`
- `toggleFavorite(id: UUID)`
- `incrementUsage(id: UUID)`

## PromptDetailView
Layout:
- Header row: title (large, semibold) + favorite toggle.
- Metadata row: updated date, usage count, category (small, secondary).
- Main body: Markdown-rendered content.
- Tags: horizontal chip row.
- Actions: Copy, Use, Edit (right-aligned).

Behavior:
- Resolves the prompt by id from `LibraryViewModel`.
- Favorite toggle updates the shared model.
- Copy action writes to NSPasteboard.
- Use action is a placeholder for VariableResolver (future task).
- Edit opens `PromptEditorView` as a sheet.

Visuals:
- Wrap main content in `liquidGlassSurface` with a generous corner radius.

## PromptEditorView
Layout:
- `NavigationStack` with toolbar actions.
- Left: Title `TextField` + body `TextEditor`.
- Right: optional preview pane (toggle via eye icon).

Behavior:
- Maintains a draft copy of the prompt fields.
- Save updates `LibraryViewModel` via `updatePrompt`.
- Cancel warns if there are unsaved changes.
- Preview uses the draft content and re-renders on change.

## Error Handling
- If the prompt is missing, show `ContentUnavailableView` and keep selection.
- Copy failures: minimal feedback (beep or inline status).
- Save failures: keep editor open and show a non-blocking warning.

## Testing + Verification
- Unit tests for `LibraryViewModel` updates (favorite toggle, edits, sort stability).
- SwiftUI previews for detail/editor with long content and many tags.
- Manual checks:
  - Select prompt -> detail loads.
  - Edit title/content -> save -> list + detail update.
  - Toggle favorite -> filter behavior remains correct.
  - Copy action places text on clipboard.
