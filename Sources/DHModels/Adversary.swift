//
//  Adversary.swift
//  Encounter
//
//  Static catalog models for Daggerheart adversaries.
//  These represent SRD or homebrew definitions — not live encounter state.
//  See EncounterSession.swift for runtime tracking types.
//
//  JSON schema compatible with:
//    - seansbox/daggerheart-srd  (.build/json/adversaries.json)
//    - ly0va/beastvault           (YAML/JSON library format)
//    - javalent/fantasy-statblocks (Daggerheart layout)
//  See docs/data-schema.md for full field reference and source notes.
//

import Foundation

// MARK: - AdversaryType

/// The role an adversary plays in a conflict.
///
/// Source: Daggerheart SRD "Using Adversaries" — each type modifies
/// how the adversary is run at the table.
nonisolated public enum AdversaryType: String, Codable, CaseIterable, Sendable {
  /// Tough; deliver powerful attacks. Usually have extra HP.
  case bruiser = "Bruiser"
  /// Groups of identical creatures acting as a single unit.
  /// Special HP/attack rules apply; see SRD "Horde" section.
  case horde = "Horde"
  /// Command and summon other adversaries. High stress capacity.
  case leader = "Leader"
  /// Easily dispatched but dangerous in numbers.
  case minion = "Minion"
  /// Fragile up close; deal high damage at range.
  case ranged = "Ranged"
  /// Maneuver and exploit opportunities to ambush.
  case skulk = "Skulk"
  /// Present conversation-based challenges.
  case social = "Social"
  /// Designed for one-on-one or climactic encounters.
  case solo = "Solo"
  /// Catch-all for adversaries without an explicit type label.
  case standard = "Standard"
  /// Enhance allies and disrupt opponents.
  case support = "Support"

  // SRD JSON encodes horde variants with HP-per-unit notation,
  // e.g. "Horde (3/HP)". Normalise all to .horde.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    if let exact = Self(rawValue: raw) {
      self = exact
    } else if raw.hasPrefix("Horde") {
      self = .horde
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unknown AdversaryType '\(raw)'"
      )
    }
  }
}

// MARK: - AttackRange

/// Distance bands used for attacks and abilities in Daggerheart.
nonisolated public enum AttackRange: String, Codable, CaseIterable, Sendable {
  case melee = "Melee"
  case veryClose = "Very Close"
  case close = "Close"
  case far = "Far"
  case veryFar = "Very Far"
}

// MARK: - FeatureType

/// The three categories of adversary features from the SRD.
///
/// - **Actions** trigger when the adversary has the spotlight.
/// - **Reactions** trigger regardless of who has the spotlight.
/// - **Passives** are always in effect.
nonisolated public enum FeatureType: String, Codable, CaseIterable, Sendable {
  case action = "action"
  case reaction = "reaction"
  case passive = "passive"

  /// Infers the feature type from the " - Type" suffix in SRD feature names,
  /// e.g. "Earth Eruption - Action" → .action. Defaults to .passive.
  public static func inferred(from featureName: String) -> FeatureType {
    let lower = featureName.lowercased()
    if lower.hasSuffix("- action") { return .action }
    if lower.hasSuffix("- reaction") { return .reaction }
    return .passive
  }
}

// MARK: - EncounterFeature

/// A single named feature (action, reaction, or passive) on an adversary or environment.
nonisolated public struct EncounterFeature: Codable, Identifiable, Sendable, Equatable, Hashable {
  // `id` uses name because feature names are unique within a given adversary.
  public var id: String { name }

  public let name: String
  public let text: String
  public let kind: FeatureType

  // Community JSON uses "feat_type"; SRD JSON omits it entirely.
  // When absent, kind is inferred from the " - Type" suffix in the feature name.
  enum CodingKeys: String, CodingKey {
    case name
    case text
    case kind = "feat_type"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    text = try c.decode(String.self, forKey: .text)
    if let rawType = try c.decodeIfPresent(String.self, forKey: .kind),
      let parsed = FeatureType(rawValue: rawType)
    {
      kind = parsed
    } else {
      // SRD JSON omits feat_type; infer from the " - Type" name suffix.
      kind = FeatureType.inferred(from: name)
    }
  }

  public init(name: String, text: String, kind: FeatureType) {
    self.name = name
    self.text = text
    self.kind = kind
  }
}

// MARK: - Adversary

/// A Daggerheart adversary as defined in the SRD or a homebrew compendium.
///
/// This is a **catalog model** — it represents the static definition of an
/// adversary, not a live instance being tracked in an encounter.
/// See ``AdversarySlot`` in `EncounterSession.swift` for the runtime type.
///
/// ## JSON Compatibility
/// The `thresholds` field is stored in community JSON as a single
/// `"major/severe"` string (e.g. `"8/15"`). The custom decoder splits this
/// into `thresholdMajor` and `thresholdSevere` integers. Both the combined
/// string key and pre-split `threshold_major` / `threshold_severe` keys
/// are accepted.
nonisolated public struct Adversary: Codable, Identifiable, Sendable, Equatable, Hashable {

  // MARK: Identity
  /// URL-safe slug, e.g. `"acid-burrower"`. Used as stable ID for cross-referencing.
  public let id: String
  public let name: String
  /// Content source tag, always lowercased: `"srd"`, `"homebrew"`, a book name, etc.
  /// Values from external JSON are normalized to lowercase at decode time.
  public let source: String
  /// `true` if this adversary comes from a non-SRD source (homebrew or a named book).
  public var isHomebrew: Bool { source != "srd" }

  // MARK: Classification
  /// Opposes PCs of the matching tier (1–4).
  public let tier: Int
  public let role: AdversaryType

  // MARK: Description
  public let flavorText: String
  /// GM-facing guidance on how to play this adversary at the table.
  public let motivesAndTactics: String?

  // MARK: Core Stats
  /// The DC for all player rolls made against this adversary.
  /// Adversaries never roll Evasion — they use a flat Difficulty.
  public let difficulty: Int
  /// Damage required to trigger a **Major** hit on this adversary.
  public let thresholdMajor: Int
  /// Damage required to trigger a **Severe** hit on this adversary.
  public let thresholdSevere: Int
  public let hp: Int
  public let stress: Int

  // MARK: Standard Attack
  /// Attack modifier string, e.g. `"+3"`.
  public let attackModifier: String
  /// Name of the standard attack or weapon, e.g. `"Claws"`.
  public let attackName: String
  public let attackRange: AttackRange
  /// Damage expression, e.g. `"1d12+2 phy"`. Parse with a dice library as needed.
  public let damage: String

  // MARK: Additional
  /// Optional experience tag, e.g. `"Tremor Sense +2"`.
  public let experience: String?
  /// Actions, reactions, and passives for this adversary.
  public let features: [EncounterFeature]

  // MARK: - CodingKeys

  enum CodingKeys: String, CodingKey {
    case id, name, source, tier, type, description
    case motivesAndTactics = "motives_and_tactics"
    case difficulty
    // Raw combined key from community JSON ("8/15"):
    case thresholds
    // Pre-split alternative keys (our own export format):
    case thresholdMajor = "threshold_major"
    case thresholdSevere = "threshold_severe"
    case hp, stress
    case attackModifier = "atk"
    case attackName = "attack"
    case attackRange = "range"
    case damage, experience
    case features = "feature"
  }

  // MARK: - Decode Helpers

  /// Derives a URL-safe slug from a display name, e.g. "Acid Burrower" → "acid-burrower".
  private static func slug(_ name: String) -> String {
    name.lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
      .joined(separator: "-")
  }

  /// Decodes a keyed value that the source JSON may encode as either an Int or a numeric String.
  private static func intOrString<K: CodingKey>(
    _ container: KeyedDecodingContainer<K>, forKey key: K
  ) throws -> Int {
    if let intVal = try? container.decode(Int.self, forKey: key) { return intVal }
    let str = try container.decode(String.self, forKey: key)
    guard let intVal = Int(str) else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: container,
        debugDescription: "Expected Int or numeric String, got '\(str)'"
      )
    }
    return intVal
  }

  // MARK: - Decodable

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)

    // name decoded first so it can serve as the id fallback.
    name = try c.decode(String.self, forKey: .name)
    let rawID = try c.decodeIfPresent(String.self, forKey: .id) ?? Self.slug(name)
    guard !rawID.isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .id, in: c,
        debugDescription: "Adversary 'id' must not be empty (name: '\(name)')"
      )
    }
    id = rawID
    // Normalize source to lowercase so "SRD", "srd", "Homebrew", etc. all compare equal.
    source = (try c.decodeIfPresent(String.self, forKey: .source) ?? "srd").lowercased()
    // SRD JSON encodes numeric stats as strings; homebrew may use ints.
    tier = try Self.intOrString(c, forKey: .tier)
    role = try c.decode(AdversaryType.self, forKey: .type)
    flavorText = try c.decode(String.self, forKey: .description)
    motivesAndTactics = try c.decodeIfPresent(String.self, forKey: .motivesAndTactics)
    difficulty = try Self.intOrString(c, forKey: .difficulty)
    hp = try Self.intOrString(c, forKey: .hp)
    stress = try Self.intOrString(c, forKey: .stress)
    attackModifier = try c.decode(String.self, forKey: .attackModifier)
    attackName = try c.decode(String.self, forKey: .attackName)
    attackRange = try c.decode(AttackRange.self, forKey: .attackRange)
    damage = try c.decode(String.self, forKey: .damage)
    experience = try c.decodeIfPresent(String.self, forKey: .experience)
    features = try c.decodeIfPresent([EncounterFeature].self, forKey: .features) ?? []

    // Threshold decoding: prefer pre-split keys, fall back to "major/severe" string.
    if let major = try c.decodeIfPresent(Int.self, forKey: .thresholdMajor),
      let severe = try c.decodeIfPresent(Int.self, forKey: .thresholdSevere)
    {
      thresholdMajor = major
      thresholdSevere = severe
    } else if let raw = try c.decodeIfPresent(String.self, forKey: .thresholds) {
      // SRD minions encode "None" — they have no damage thresholds.
      // Some adversaries encode a partial value like "4/None" where the
      // severe threshold is absent. Treat any "None" component as 0.
      if raw == "None" {
        thresholdMajor = 0
        thresholdSevere = 0
      } else {
        let parts =
          raw
          .split(separator: "/")
          .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else {
          throw DecodingError.dataCorruptedError(
            forKey: .thresholds, in: c,
            debugDescription: "Expected 'major/severe' format, got '\(raw)'"
          )
        }
        thresholdMajor = Int(parts[0]) ?? 0
        thresholdSevere = Int(parts[1]) ?? 0
      }
    } else {
      throw DecodingError.keyNotFound(
        CodingKeys.thresholds,
        DecodingError.Context(
          codingPath: c.codingPath,
          debugDescription:
            "No threshold data found (tried 'thresholds', 'threshold_major'/'threshold_severe')"
        )
      )
    }
  }

  // MARK: - Encodable (uses pre-split keys for clarity)

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(source, forKey: .source)
    try c.encode(tier, forKey: .tier)
    try c.encode(role, forKey: .type)
    try c.encode(flavorText, forKey: .description)
    try c.encodeIfPresent(motivesAndTactics, forKey: .motivesAndTactics)
    try c.encode(difficulty, forKey: .difficulty)
    try c.encode(thresholdMajor, forKey: .thresholdMajor)
    try c.encode(thresholdSevere, forKey: .thresholdSevere)
    try c.encode(hp, forKey: .hp)
    try c.encode(stress, forKey: .stress)
    try c.encode(attackModifier, forKey: .attackModifier)
    try c.encode(attackName, forKey: .attackName)
    try c.encode(attackRange, forKey: .attackRange)
    try c.encode(damage, forKey: .damage)
    try c.encodeIfPresent(experience, forKey: .experience)
    try c.encode(features, forKey: .features)
  }

  // MARK: - Memberwise init (for previews / tests)

  public init(
    id: String,
    name: String,
    source: String = "srd",
    tier: Int,
    role: AdversaryType,
    flavorText: String,
    motivesAndTactics: String? = nil,
    difficulty: Int,
    thresholdMajor: Int,
    thresholdSevere: Int,
    hp: Int,
    stress: Int,
    attackModifier: String,
    attackName: String,
    attackRange: AttackRange,
    damage: String,
    experience: String? = nil,
    features: [EncounterFeature] = []
  ) {
    self.id = id
    self.name = name
    self.source = source
    self.tier = tier
    self.role = role
    self.flavorText = flavorText
    self.motivesAndTactics = motivesAndTactics
    self.difficulty = difficulty
    self.thresholdMajor = thresholdMajor
    self.thresholdSevere = thresholdSevere
    self.hp = hp
    self.stress = stress
    self.attackModifier = attackModifier
    self.attackName = attackName
    self.attackRange = attackRange
    self.damage = damage
    self.experience = experience
    self.features = features
  }
}

// MARK: - CustomStringConvertible

extension Adversary: CustomStringConvertible {
  /// A human-readable summary: name, tier, and type.
  public var description: String { "\(name) (Tier \(tier) \(role))" }
}

extension Adversary: CustomDebugStringConvertible {
  /// A debug-focused identity string with key combat stats.
  public var debugDescription: String {
    "Adversary(id: \(id), tier: \(tier), role: \(role), hp: \(hp), stress: \(stress), difficulty: \(difficulty))"
  }
}
