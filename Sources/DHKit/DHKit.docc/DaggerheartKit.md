# ``DaggerheartKit``

Observable SwiftUI stores for running Daggerheart encounters on Apple platforms.

## Overview

`DaggerheartKit` provides `@Observable` classes that drive SwiftUI views in the
Encounter app. It depends on ``DaggerheartModels`` for the underlying value types.

All types require Apple platforms (iOS 17+, macOS 14+) and are isolated to
`@MainActor` by default.

## Topics

### Compendium

- ``Compendium``

### Encounter Persistence

- ``EncounterStore``
- ``EncounterStoreError``

### Live Session

- ``EncounterSession``
- ``AdversarySlot``
- ``EnvironmentSlot``
- ``SessionRegistry``
