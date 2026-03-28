# DHModels — Claude Code Context

Swift Package containing the Daggerheart model layer.
Two targets: `DHModels` (Linux-safe value types) and `DHKit`
(Apple-platform `@Observable` stores). A `validate-dhpack` CLI validates content packs.

---

## Package structure

```
DHModels/
├── Sources/
│   ├── DHModels/      # Foundation-only; no Apple-only frameworks
│   ├── DHKit/
│   │   └── Resources/          # adversaries.json, environments.json (SRD data)
│   └── validate-dhpack/
├── Tests/
│   ├── DHModelsTests/ # Linux-compatible; runs in Linux CI
│   │   └── Fixtures/           # adversaries.json, environments.json, sample-homebrew.dhpack
│   └── DHKitTests/    # Apple-platform only
├── schemas/                    # dhpack.schema.json (JSON Schema for .dhpack files)
├── Package.swift
├── .swift-format               # Formatting rules (matches gwillish/encounter)
└── Scripts/format.sh           # Format all tracked Swift files
```

---

## Build configuration

- **Swift:** 6.2, `.swiftLanguageMode(.v6)`
- **Platforms:** iOS 17, macOS 14, tvOS 17, watchOS 10 (DHKit); unrestricted (DHModels)
- **Swift settings active on all targets:**
  - `.enableUpcomingFeature("MemberImportVisibility")` — members from transitive
    dependencies are not visible without an explicit import
- **DHKit additionally:**
  - `.defaultIsolation(MainActor.self)` — all non-isolated code defaults to `@MainActor`

### Implication of MemberImportVisibility

Any file that uses types from `DHModels` (even through `DHKit`)
must explicitly `import DHModels`. This applies to test files too.

---

## Building

```bash
# Build both libraries
swift build

# Build a specific target
swift build --target DHModels
swift build --target DHKit
swift build --target validate-dhpack
```

---

## Testing

```bash
# Run all tests
swift test

# Linux-safe model tests only (also what the Linux CI runs)
swift test --filter DHModelsTests

# Kit tests (Apple-platform only)
swift test --filter DHKitTests
```

Tests use **Swift Testing** (`import Testing`), not XCTest.

`DHModelsTests` must stay Linux-compatible: no `@Observable`, no
`Compendium`, no `EncounterStore`. Anything using Apple-platform-only types
belongs in `DHKitTests`.

---

## Formatting

Run before every commit:

```bash
./Scripts/format.sh
```

The script formats and lints all tracked Swift files:

```bash
git ls-files -z '*.swift' | xargs -0 swift-format format --parallel --in-place
git ls-files -z '*.swift' | xargs -0 swift-format lint --strict --parallel
```

---

## CI

`.github/workflows/linux.yml`:

- **Build + test on Linux** — Swift 6.1 and 6.2 on `ubuntu-latest`; runs
  `swift build --target DHModels`, `swift build --target validate-dhpack`,
  and `swift test --filter DHModelsTests`
- **swift-format lint** — runs on pull requests only; container `swift:6.2`

`DHKitTests` is intentionally excluded from Linux CI because
`DHKit` depends on `Observation`, which requires Apple platforms.

---

## Adding new model types

1. Add the `.swift` file to `Sources/DHModels/` if the type is
   Foundation-only, or to `Sources/DHKit/` if it needs `@Observable`
   or Apple-only frameworks.
2. Make it `public`.
3. Add `Codable` conformance if it will appear in `.dhpack` or JSON files.
4. Write tests in `DHModelsTests` (for model types) or `DHKitTests`
   (for observable stores). Follow red-green TDD.
5. Run `./Scripts/format.sh` before committing.

---

## Key conventions

- **No force-unwrap** in any source or test file.
- **Daggerheart naming:** use game terms as-is (`hp`, `stress`, `fear`, `hope`,
  `difficulty`, `thresholds`) — do not rename to generic equivalents.
- **Bundle resources:** `DHKit` resources (SRD JSON) are accessed via
  `Bundle.module`, which is internal — it cannot appear in a `public` default
  argument. Use `bundle: Bundle? = nil` and resolve as `bundle ?? .module` inside
  the function body.
- **Test fixtures:** place JSON fixtures in `Tests/DHModelsTests/Fixtures/`
  and declare them as `.copy("Fixtures")` in Package.swift. Access via
  `Bundle.module.url(forResource:withExtension:subdirectory:)` with
  `subdirectory: "Fixtures"`.

---

## Git

- **Never commit on behalf of the user.** Wait for an explicit request.
- **No Claude attribution** in commit messages.
