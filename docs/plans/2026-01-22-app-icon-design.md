# App Icon and Menu Bar Icon Design

## Goals
- Distinctive, legible icon at 16px while still polished at 512/1024.
- Communicate “prompt library” via document + magnifier.
- Template-safe menu bar icon that reads in light/dark mode.

## Visual Direction
- Flat vector, rounded-square background with a paper doc + magnifier overlay.
- Minimal detail to avoid blur at small sizes; no gradients or drop shadows.
- Composition favors a strong silhouette: doc block plus circular lens/handle.

## Palette
- Teal background: `#2DB7B0` for a fresh, modern base.
- Paper: `#EAF7F6` with fold `#D6F1EF`.
- Ink: `#0B2230` for lines and magnifier.

## Asset Plan
- App icon: 1024px master rendered into 16–1024 with macOS appiconset sizes.
- Menu bar icon: monochrome outline symbol, 18px/36px PNGs, marked template.
- Stored in `Sources/PromptHoarder/Resources/Assets.xcassets` for SwiftPM processing.
