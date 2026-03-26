# DaggerheartModels

Swift Package containing the model layer for Daggerheart encounter tools.
Extracted from [gwillish/encounter](https://github.com/gwillish/encounter).

Documentation is hosted on the **Swift Package Index**:
[swiftpackageindex.com/gwillish/DaggerheartModels](https://swiftpackageindex.com/gwillish/DaggerheartModels)

---

## What's inside

### `DaggerheartModels` — Foundation-only, Linux-compatible

Pure value types (structs and enums) that model Daggerheart catalog and encounter
data. No UIKit, AppKit, Observation, or Apple-only frameworks — safe to use on
Linux and in server-side Swift.

| Type | Purpose |
|---|---|
| `Adversary` | Catalog entry for a Daggerheart adversary (stats, features, thresholds) |
| `AdversaryType` | Adversary role enum: Bruiser, Horde, Leader, Minion, Ranged, Skulk, Social, Solo, Standard, Support |
| `AdversaryFeature` | Named action, reaction, or passive on an adversary or environment |
| `FeatureType` | Feature category enum: action, reaction, passive |
| `AttackRange` | Attack range enum: Melee, Very Close, Close, Far, Very Far |
| `DaggerheartEnvironment` | Catalog entry for a scene environment |
| `EncounterDefinition` | Saved encounter definition (name, adversary roster, GM notes) |
| `PlayerSlot` | Player configuration within an encounter definition |
| `DHPackContent` | Top-level type for `.dhpack` content pack files |
| `ContentSource` | Remote content source (URL, display name, cache metadata) |
| `ContentFingerprint` | Snapshot hash + etag for change detection |
| `ContentStoreError` | Errors from content source management |
| `DifficultyBudget` | Difficulty assessment helpers |
| `Condition` | Status condition (name, description) |

### `DaggerheartKit` — Apple-platform `@Observable` stores

`@MainActor` observable classes for SwiftUI integration. Requires Apple platforms
(iOS 17+, macOS 14+, tvOS 17+, watchOS 10+). Depends on `DaggerheartModels` and
`swift-log`.

| Type | Purpose |
|---|---|
| `Compendium` | Loads SRD adversary and environment JSON from the bundle; supports homebrew and community source packs; full-text search |
| `EncounterStore` | Persists `EncounterDefinition` files to disk; create, save, delete, duplicate |
| `EncounterSession` | Runtime mutable state for a live encounter: HP/stress tracking, adversary slots, player slots |
| `SessionRegistry` | Cache of active `EncounterSession` instances keyed by encounter ID |
| `CompendiumError` | Errors from Compendium loading |
| `EncounterStoreError` | Errors from EncounterStore persistence |

### `validate-dhpack` — CLI tool

Command-line tool that validates one or more `.dhpack` files against the
`DHPackContent` decoder and reports pass/fail:

```bash
swift run validate-dhpack my-pack.dhpack
```

---

## Content packs

Community and homebrew content is distributed as `.dhpack` files — plain JSON
containing adversaries, environments, or both.

The JSON Schema for `.dhpack` is at [`schemas/dhpack.schema.json`](schemas/dhpack.schema.json).
Add `"$schema"` to your pack file to enable validation and autocomplete in VS Code:

```json
{
  "$schema": "https://cdn.jsdelivr.net/gh/gwillish/DaggerheartModels@main/schemas/dhpack.schema.json",
  "adversaries": [ ... ]
}
```

Pin to a release tag for stability (e.g. `@0.1.0` instead of `@main`).

Use `validate-dhpack` to check a pack file against the decoder:

```bash
swift run validate-dhpack my-pack.dhpack
```

A complete field reference is in [`docs/dhpack-format.md`](docs/dhpack-format.md).

---

## Adding to your project

```swift
// Package.swift
.package(url: "https://github.com/gwillish/DaggerheartModels.git", from: "0.1.0"),

// Apple-platform app target
.product(name: "DaggerheartKit", package: "DaggerheartModels"),

// Linux / server target (models only)
.product(name: "DaggerheartModels", package: "DaggerheartModels"),
```

---

## Building and testing

```bash
# Build both library targets
swift build

# Run all tests
swift test

# Linux-safe model tests only
swift test --filter DaggerheartModelsTests
```

See `CLAUDE.md` for the full development guide.
