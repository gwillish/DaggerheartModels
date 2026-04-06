# Authoring a Content Pack

Create your own adversaries and environments for Encounter.

## Overview

A `.dhpack` file is plain JSON — you can create one in any text editor, export one from
within the app, or generate one programmatically. This article walks through all three
paths.

For the complete field-by-field reference, see <doc:DHPackFormat>.

## Path 1: Write it in a text editor

This is the most direct approach and works on any platform.

### 1. Create a new JSON file

Open any text editor (TextEdit, VS Code, BBEdit, Zed — anything that can save plain
text) and start with the pack wrapper:

```json
{
  "adversaries": [],
  "environments": []
}
```

### 2. Add adversaries

Fill in the `adversaries` array. Every adversary needs at minimum: `name`, `tier`,
`type`, `description`, `difficulty`, a threshold (via `thresholds` or the split keys),
`hp`, `stress`, `atk`, `attack`, `range`, and `damage`.

```json
{
  "adversaries": [
    {
      "name": "Ashwalker",
      "tier": 1,
      "type": "Standard",
      "description": "Hollow-eyed wanderers from the Ashen Wastes, drawn to heat and sound.",
      "motives_and_tactics": "Slowly encircles prey; attacks when it outnumbers a target.",
      "difficulty": 11,
      "thresholds": "5/12",
      "hp": 5,
      "stress": 3,
      "atk": "+2",
      "attack": "Cinder Claws",
      "range": "Melee",
      "damage": "1d8+1 phy",
      "feature": [
        {
          "name": "Ash Cloud - Reaction",
          "text": "When the Ashwalker takes a Major hit, it releases a cloud of ash. All creatures within Very Close range must make a Difficulty 11 Agility roll or be Blinded until the end of their next turn.",
          "feat_type": "reaction"
        }
      ]
    }
  ]
}
```

### 3. Validate your JSON

Before saving as `.dhpack`, confirm the JSON is well-formed:

```bash
# Built-in on macOS and Linux:
python3 -m json.tool my-pack.json
```

A clean file prints the formatted JSON. An error prints the line number and problem.

If you use VS Code, add a `$schema` field to enable inline validation and
autocomplete:

```json
{
  "$schema": "https://cdn.jsdelivr.net/gh/gwillish/DaggerheartModels@main/schemas/dhpack.schema.json",
  "adversaries": [ ... ]
}
```

### 4. Save as .dhpack

Rename or save the file with a `.dhpack` extension, e.g. `ashen-wastes.dhpack`.

> On macOS, if the Finder warns you about changing the extension, click **Use .dhpack**.

### 5. Test the import

Send the file to a device with Encounter installed (AirDrop is the fastest) and open
it. If the import succeeds, your adversaries appear in the Compendium. If an error
banner appears, check the JSON for missing required fields.

## Path 2: Export from within the app (coming in a future release)

Encounter will support building and exporting packs directly from homebrew adversaries
you've created in the app — tracked in [issue #21](https://github.com/gwillish/encounter/issues/21).

Once available, the flow will look something like this:

1. Add adversaries to the Compendium using the in-app creator.
2. Select the adversaries you want to export (multi-select or select all homebrew).
3. Tap **Export Pack** and name the file.
4. The system share sheet appears — AirDrop it, save to Files, or share however you like.

This is the lowest-friction path for GMs who don't want to hand-edit JSON.

## Path 3: Generate programmatically

If you're building a tool or converting content from another system, construct the
JSON structure using any language that can serialize JSON and write the output with a
`.dhpack` extension.

The field names are stable (see <doc:DHPackFormat>), and the format accepts numeric
strings for `tier`, `difficulty`, `hp`, and `stress` — so loose-typed sources can
be passed through without coercing every field.

## Tips

- **Keep IDs URL-safe.** Slugs like `"ashwalker"` or `"iron-golem"` work; spaces or
  special characters don't. If you omit `id`, the app derives one from the name.
- **Give your pack a source field.** Setting `"source": "My Pack Name"` on each
  entry makes it easy to filter by source in the Compendium browser.
- **Minions have no thresholds.** Use `"thresholds": "None"` for minion-type
  adversaries that take a single hit rather than tracking Major/Severe thresholds.
- **Feature types are inferred.** If you name a feature `"Bite - Action"`, you can
  omit `feat_type` and the app will infer it correctly. Including `feat_type` explicitly
  is cleaner for machine-generated packs.
