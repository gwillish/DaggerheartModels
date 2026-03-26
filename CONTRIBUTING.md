# Contributing to DaggerheartModels

DaggerheartModels is the Swift Package backing the
[Encounter](https://github.com/gwillish/encounter) app. It contains the
Daggerheart model layer — the types that describe adversaries, environments,
encounters, and content packs — as well as the observable stores and CLI tools
built on top of them.

---

## Scope

### In scope

- Model types in `DaggerheartModels`: `Adversary`, `DaggerheartEnvironment`,
  `EncounterDefinition`, `DHPackContent`, and related value types
- Observable stores in `DaggerheartKit`: `Compendium`, `EncounterStore`,
  `EncounterSession`, `SessionRegistry`
- The `validate-dhpack` CLI tool
- The `.dhpack` JSON Schema at `schemas/dhpack.schema.json`
- Test coverage for all of the above

### Out of scope

- SwiftUI views — those live in [gwillish/encounter](https://github.com/gwillish/encounter)
- App-level lifecycle, navigation, or settings
- New content types not grounded in the Daggerheart SRD or `.dhpack` format

---

## Proposing changes

1. **Open an issue first.** Discuss before writing code.
2. **A human must be the proposer.** AI-generated feature proposals without a
   human author will not be considered.
3. For behavioral changes to `DHPackContent` or the `.dhpack` JSON Schema, explain
   compatibility impact — existing pack files should continue to decode correctly.

---

## Code expectations

- **Language:** Swift 6.2, `.swiftLanguageMode(.v6)`
- **`DaggerheartModels` target:** Foundation-only. No `import Observation`,
  `import AppKit`, `import UIKit`, or any other Apple-platform-only framework.
  Code in this target must compile and run on Linux.
- **`DaggerheartKit` target:** Apple-platform `@Observable` stores.
  Uses `import Observation` and `import DaggerheartModels`.
- **`MemberImportVisibility` is active.** Every file must explicitly import the
  module that defines the types it uses. `import DaggerheartKit` does not make
  `Adversary` visible — add `import DaggerheartModels` too.
- **No force-unwrap** anywhere in source or test code.
- **Access control:** `public` on all exported types and their stored properties.
- **Naming:** use Daggerheart game terms as-is (`hp`, `stress`, `thresholds`).

---

## Formatting

This project uses **`swift-format`** (the built-in Swift toolchain formatter).
The `.swift-format` file at the project root is the canonical configuration.

Run before every commit:

```bash
./Scripts/format.sh
```

PRs with formatting violations will be asked to reformat before review.

---

## Testing

Tests use **Swift Testing** (`import Testing`), not XCTest.

```bash
# Run all tests
swift test

# Linux-safe model tests (what CI runs)
swift test --filter DaggerheartModelsTests
```

Guidelines:

- Write a failing test first — red before green.
- Tests that use `@Observable` stores or Apple-only APIs belong in `DaggerheartKitTests`.
- Tests that should also run on Linux belong in `DaggerheartModelsTests`. Keep them
  free of `Compendium`, `EncounterStore`, and other Apple-only types.
- Place JSON fixtures in `Tests/DaggerheartModelsTests/Fixtures/` and access them
  via `Bundle.module.url(forResource:withExtension:subdirectory: "Fixtures")`.

---

## Pull request process

1. **Link to an issue.** Every PR must reference the issue it addresses.
2. **Human author required.** AI-generated code is permitted; the PR author and at
   least one reviewer must be human.
3. **Tests required.** New behavior without tests will not be merged.
4. **swift-format clean.** Run `./Scripts/format.sh` before pushing.
5. **Linux CI must pass.** The `DaggerheartModelsTests` suite runs on Linux in CI —
   do not introduce Linux-incompatible code into the `DaggerheartModels` target.
