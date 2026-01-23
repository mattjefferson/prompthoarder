# Menu Bar Popover With Search

## Goals
- Provide instant search and quick access from the menu bar.
- Keep the popover lightweight and responsive (<200ms search feedback).
- Reuse in-memory prompt data for now (no DB dependency).

## Assumptions
- Search filters in-memory `LibraryViewModel.allPrompts`.
- Variable resolution and copy actions are stubbed until the resolver sheet lands.
- Keyboard navigation is basic (List selection + click); advanced key handling deferred.

## Layout
- Search field (auto-focused on appear).
- Tab bar: Favorites, Recent, Workflows.
- Results list (compact rows).
- Footer actions: Settings, Open Library, Quit.

## Data Flow
- `MenuBarView` owns `searchQuery`, `selectedTab`, and `selection`.
- Results computed by filtering `LibraryViewModel.allPrompts`.
- Tabs apply additional filters:
  - Favorites: `isFavorite == true`
  - Recent: `updatedAt` within last 14 days
  - Workflows: `workflowIds` not empty

## Actions
- Clicking a result selects it (no copy yet).
- Settings opens the Settings window.
- Open Library activates the main window.
- Quit terminates the app.

## Verification
- Popover renders with tabs and results.
- Search filters list quickly.
- Tabs switch filters.
- Footer actions respond.
