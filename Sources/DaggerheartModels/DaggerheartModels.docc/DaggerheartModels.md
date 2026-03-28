# ``DaggerheartModels``

Foundation-only value types for the Daggerheart tabletop RPG system.

## Overview

`DaggerheartModels` provides the core data types for representing Daggerheart
game content. All types are pure Swift value types (`struct` / `enum`) with no
Apple-platform dependencies, making them suitable for use on Linux and in
server-side or CLI tools.

These types are the shared vocabulary between the Encounter app, the
`validate-dhpack` CLI tool, and any other tooling built around the Daggerheart
ecosystem.

## Topics

### Adversaries

- ``Adversary``
- ``AdversaryType``
- ``EncounterFeature``
- ``FeatureType``
- ``AttackRange``

### Environments

- ``DaggerheartEnvironment``

### Encounters

- ``EncounterDefinition``
- ``PlayerSlot``
- ``DifficultyBudget``
- ``Condition``

### Content Packs

- ``DHPackContent``
- ``ContentSource``
- ``ContentFingerprint``
- ``ContentStoreError``
