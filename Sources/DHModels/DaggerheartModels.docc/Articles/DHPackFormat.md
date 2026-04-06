# The .dhpack Format

Complete reference for the Encounter content pack file format.

## Overview

A `.dhpack` file is a plain JSON file with a custom extension. The extension tells
iOS and macOS to route the file to Encounter on open, which imports the content into
the app's compendium. Any text editor can create or inspect one.

The format is based on the [seansbox/daggerheart-srd](https://github.com/seansbox/daggerheart-srd)
community JSON schema — the closest thing to a community standard for Daggerheart JSON data.

## Top-level structure

A `.dhpack` accepts two JSON structures:

**Pack wrapper (recommended)** — supports adversaries, environments, or both:

```json
{
  "adversaries": [ ... ],
  "environments": [ ... ]
}
```

**Bare adversary array** — direct seansbox export format, adversaries only:

```json
[ ... ]
```

Use the pack wrapper for new packs. The bare array format exists for compatibility with
direct exports from seansbox/daggerheart-srd tooling.

## Adversary object

Each adversary in the array must conform to this schema.

```json
{
  "id": "iron-golem",
  "name": "Iron Golem",
  "source": "My Homebrew Pack",
  "tier": 2,
  "type": "Bruiser",
  "description": "A hulking construct of hammered iron, animated by an ancient binding rune.",
  "motives_and_tactics": "Relentless; ignores difficult terrain. Focuses on the nearest PC.",
  "difficulty": 14,
  "thresholds": "10/18",
  "hp": 12,
  "stress": 4,
  "atk": "+4",
  "attack": "Iron Fist",
  "range": "Very Close",
  "damage": "1d12+4 phy",
  "experience": "Construct Lore +2",
  "feature": [
    {
      "name": "Runic Shell - Passive",
      "text": "The first time the Iron Golem would take a Major hit each scene, reduce the damage to a Minor hit instead.",
      "feat_type": "passive"
    }
  ]
}
```

### Adversary fields

| Field | Required | Type | Notes |
|---|---|---|---|
| `id` | Recommended | String | URL-safe slug, e.g. `"iron-golem"`. Auto-derived from `name` if absent. |
| `name` | Yes | String | Display name |
| `source` | No | String | Pack name, author, or `"homebrew"`. Stored lowercase. |
| `tier` | Yes | Integer or string | `1`–`4`, matching PC level tiers |
| `type` | Yes | String | See **Adversary types** below |
| `description` | Yes | String | One-line appearance or demeanor |
| `motives_and_tactics` | No | String | GM-facing guidance on running this adversary |
| `difficulty` | Yes | Integer or string | DC for all player rolls against this adversary |
| `thresholds` | Either | String | Combined `"major/severe"` format, e.g. `"8/15"`. Minions with no thresholds use `"None"`. |
| `threshold_major` | Either | Integer | Pre-split alternative to `thresholds` |
| `threshold_severe` | Either | Integer | Pre-split alternative to `thresholds` |
| `hp` | Yes | Integer or string | Hit points |
| `stress` | Yes | Integer or string | Stress capacity |
| `atk` | Yes | String | Attack modifier, e.g. `"+3"` |
| `attack` | Yes | String | Name of the attack or weapon |
| `range` | Yes | String | See **Attack ranges** below |
| `damage` | Yes | String | Dice expression, e.g. `"1d12+2 phy"` |
| `experience` | No | String | Optional tag, e.g. `"Tremor Sense +2"` |
| `feature` | No | Array | Actions, reactions, and passives — see **Feature object** below |

> **Threshold note:** Provide either the combined `thresholds` string **or** the pair
> `threshold_major` / `threshold_severe`. You do not need both. Minions with no damage
> thresholds use `"thresholds": "None"`.
>
> **Numeric strings:** `tier`, `difficulty`, `hp`, and `stress` accept either a JSON
> number or a numeric string (e.g. `"12"`) for compatibility with SRD tooling that
> exports all fields as strings.

### Adversary types

| `type` value | Role |
|---|---|
| `"Bruiser"` | Tough; deliver powerful attacks |
| `"Horde"` | Groups acting as one unit — special HP and attack rules apply |
| `"Leader"` | Command and summon other adversaries; high stress capacity |
| `"Minion"` | Easily dispatched; dangerous in numbers |
| `"Ranged"` | Fragile in melee; deal high damage at range |
| `"Skulk"` | Maneuver and ambush |
| `"Social"` | Conversation-based challenges |
| `"Solo"` | Designed for climactic one-on-one encounters |
| `"Standard"` | General-purpose adversary |
| `"Support"` | Enhance allies and disrupt opponents |

Horde variants from older SRD exports (e.g. `"Horde (3/HP)"`) are normalized to
`"Horde"` automatically.

### Attack ranges

| `range` value |
|---|
| `"Melee"` |
| `"Very Close"` |
| `"Close"` |
| `"Far"` |
| `"Very Far"` |

### Damage expression format

Damage strings follow the pattern `XdY[+Z] type`:

| Example | Meaning |
|---|---|
| `"1d10+3 phy"` | Physical damage, 1d10 plus 3 |
| `"2d6 mag"` | Magical damage, 2d6 |
| `"1d8 phy"` | Physical damage, 1d8 |

`phy` = physical, `mag` = magical, per SRD terminology.

## Feature object

Features are the actions, reactions, and passives that appear on adversary and environment stat blocks.

```json
{
  "name": "Pack Tactics - Passive",
  "text": "Deals +1 damage for each other Pack member within Very Close range.",
  "feat_type": "passive"
}
```

| Field | Required | Values |
|---|---|---|
| `name` | Yes | Unique within this adversary |
| `text` | Yes | Rules text |
| `feat_type` | No | `"action"`, `"reaction"`, `"passive"`. If absent, inferred from a ` - Action` / ` - Reaction` suffix in `name`; defaults to `"passive"`. |

Feature types:
- **Actions** — trigger when this adversary has the spotlight
- **Reactions** — trigger regardless of spotlight
- **Passives** — always in effect

## Environment object

Environments share the feature schema but have no HP, Stress, or attack fields.

```json
{
  "id": "smoldering-ruins",
  "name": "Smoldering Ruins",
  "source": "My Homebrew Pack",
  "description": "Crumbling walls and drifting ash make every step treacherous.",
  "feature": [
    {
      "name": "Choking Smoke - Passive",
      "text": "PCs must spend 1 Hope at the start of each round or suffer 1d4 stress.",
      "feat_type": "passive"
    }
  ]
}
```

| Field | Required | Notes |
|---|---|---|
| `id` | Recommended | Slug, auto-derived from `name` if absent |
| `name` | Yes | |
| `source` | No | Stored lowercase |
| `description` | Yes | |
| `feature` | No | Same feature object schema as adversaries |

## Minimal working example

The smallest valid `.dhpack` with one adversary and one environment:

```json
{
  "adversaries": [
    {
      "name": "Cave Bat",
      "tier": 1,
      "type": "Minion",
      "description": "A small, frantic bat disturbed from its roost.",
      "difficulty": 10,
      "thresholds": "None",
      "hp": 2,
      "stress": 1,
      "atk": "+1",
      "attack": "Bite",
      "range": "Melee",
      "damage": "1d4 phy"
    }
  ],
  "environments": [
    {
      "name": "Dark Cave",
      "description": "Complete darkness. PCs without light sources act at disadvantage.",
      "feature": [
        {
          "name": "Pitch Black - Passive",
          "text": "PCs without a light source have disadvantage on all rolls.",
          "feat_type": "passive"
        }
      ]
    }
  ]
}
```

Save as `my-pack.dhpack` and the file is ready to import or share.

## Relationship to upstream formats

| Tool | Compatibility |
|---|---|
| [seansbox/daggerheart-srd](https://github.com/seansbox/daggerheart-srd) | Full. Direct `.build/json/adversaries.json` exports can be renamed `.dhpack` and imported as-is (bare array format). |
| [BeastVault](https://github.com/ly0va/beastvault) | Full. Exports in the same community format; JSON arrays import directly or can be wrapped in a pack object. |
| [fantasy-statblocks](https://github.com/javalent/fantasy-statblocks) | Full. Field names match this schema. |
| [daggersearch/daggerheart-data](https://github.com/daggersearch/daggerheart-data) | Not compatible — covers player-facing content (classes, ancestries, items), not adversaries. |

## JSON Schema

A machine-readable JSON Schema (draft 2020-12) for the `.dhpack` format is maintained
in the [DaggerheartModels](https://github.com/gwillish/DaggerheartModels) repository
at `schemas/dhpack.schema.json`. It can be used with VS Code's built-in JSON
validation, `ajv`, or any other JSON Schema-aware tool.

To enable VS Code validation, add a `$schema` field to your pack:

```json
{
  "$schema": "https://cdn.jsdelivr.net/gh/gwillish/DaggerheartModels@main/schemas/dhpack.schema.json",
  "adversaries": [ ... ]
}
```
