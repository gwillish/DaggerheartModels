# DaggerheartModels

This is a Swift Package built to support creating tools for the TTRPG Daggerheart.
There's a great community growing that is assembling standard ways to share details
on players, adversaries, environments, and more in a JSON format.

This package provides type-safe models for the Swift programming language, and
some validation and extensions on those models, including a JSONSchema
declaration, to hopefully promote more cross app, language, and platform tool
sharing.

The JSON field names and schema conventions used by this package are derived from
the community ecosystem:

| Project | Author | Contribution |
|---|---|---|
| [seansbox/daggerheart-srd](https://github.com/seansbox/daggerheart-srd) | Sean Box | SRD content in JSON/CSV/Markdown; primary source for `adversaries.json` and `environments.json` field names |
| [ly0va/beastvault](https://github.com/ly0va/beastvault) | ly0va | Obsidian plugin; defined the adversary YAML/JSON import schema used by the community |
| [javalent/fantasy-statblocks](https://github.com/javalent/fantasy-statblocks) | Jeremy Valentine | Obsidian statblock layout that established community field naming conventions |
| [daggersearch/daggerheart-data](https://github.com/daggersearch/daggerheart-data) | daggersearch | Player-facing SRD content (classes, ancestries, items) in JSON |

Many thanks to these contributors for their work establishing the shared data
formats that make cross-tool compatibility possible.

[Documentation for DaggerheartModels](https://swiftpackageindex.com/gwillish/DaggerheartModels/documentation/daggerheartmodels)
is hosted on the **Swift Package Index**.

---

## What's inside

### `DaggerheartModels` 

Pure value types (structs and enums) that model Daggerheart catalog and encounter
data. No UIKit, AppKit, Observation, or Apple-only frameworks — safe to use on
Linux, server-side Swift, and hopefully Wasm as well.

| Type | Purpose |
|---|---|
| `Adversary` | Catalog entry for a Daggerheart adversary (stats, features, thresholds) |
| `AdversaryType` | Adversary role enum: Bruiser, Horde, Leader, Minion, Ranged, Skulk, Social, Solo, Standard, Support |
| `EncounterFeature` | Named action, reaction, or passive on an adversary or environment |
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
  "$schema": "https://cdn.jsdelivr.net/gh/gwillish/DaggerheartModels@0.1.1/schemas/dhpack.schema.json",
  "adversaries": [ ... ]
}
```

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
