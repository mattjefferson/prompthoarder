# DatabaseManager

## Goals
- Manage SQLite lifecycle with GRDB.
- Run migrations on open.
- Provide a rebuild flow with progress callbacks.

## Assumptions
- DB lives at `~/Library/Application Support/PromptHoarder/index.sqlite`.
- Vault rebuild will be wired later (stubbed for now).

## Responsibilities
- `initialize()`: open queue, run migrations, enable WAL.
- `close()`: drop queue reference.
- `rebuild(progress:)`: close, delete files, recreate, migrate, report phases.

## Error Handling
- Surface migration errors as `DatabaseError.migrationFailed`.
- Rebuild errors capture phase.

## Tests
- Migration runs on initialize.
- WAL pragma enabled.
- Rebuild creates fresh DB file.
