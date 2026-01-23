# Variable Resolver Sheet (Menu Bar)

## Goals
- When a prompt contains variables like `{{name}}`, show an inline form in the menu bar popover.
- Keep the flow fast: select prompt -> fill fields -> copy -> close.
- Avoid dependencies on the DB; use in-memory prompt content.

## Assumptions
- Variables are detected via `{{ ... }}` placeholders in prompt content.
- No default values yet; blanks are allowed.
- Variable resolution is simple string replacement.

## UI Layout
- Title: "Fill Variables"
- Form fields generated from variable list
  - Single-line `TextField` by default
  - Multi-line `TextEditor` for variable names containing "context" or "content"
- Footer actions: Cancel (Esc), Copy (Enter)

## Data Flow
- Menu bar selection triggers:
  - If prompt has no variables, copy immediately.
  - If prompt has variables, present sheet.
- Sheet maintains local dictionary of values.
- On Copy: resolve content, copy to clipboard, increment usage, close popover.

## Resolution Algorithm
- Extract ordered, unique variable names via regex: `\{\{\s*([^}]+?)\s*\}\}`.
- Replace each `{{name}}` (with optional whitespace) with provided value.

## Verification
- Select prompt with `{{var}}` -> sheet appears.
- Fields render with correct labels.
- Enter copies resolved prompt to clipboard.
- Escape cancels and closes sheet.
