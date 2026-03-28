//
//  DaggerheartEnvironment.swift
//  Encounter
//
//  Daggerheart environment catalog model.
//  Environments are distinct from adversaries: they have no HP or Stress,
//  and represent terrain hazards, magical phenomena, or scene elements
//  that interact with the action economy.
//
//  Named "DaggerheartEnvironment" to avoid collision with SwiftUI's
//  `Environment` property wrapper.
//
//  JSON schema: same community ecosystem as Adversary.swift.
//  BeastVault discriminates adversary vs. environment by absence of hp/stress.
//  See docs/data-schema.md for the full field reference.
//

import Foundation

/// A Daggerheart environment — a scene element with features but no HP or Stress.
///
/// Environments share the same feature schema as adversaries but represent
/// location hazards, terrain, or interactive elements rather than combatants.
/// They participate in encounters but are not tracked as HP pools.
nonisolated public struct DaggerheartEnvironment: Codable, Identifiable, Sendable, Equatable,
  Hashable
{

  // MARK: Identity
  /// URL-safe slug, e.g. `"collapsing-cavern"`.
  public let id: String
  public let name: String
  /// Content source tag, always lowercased: `"srd"`, `"homebrew"`, a book name, etc.
  public let source: String
  /// `true` if this environment comes from a non-SRD source (homebrew or a named book).
  public var isHomebrew: Bool { source != "srd" }

  // MARK: Description
  public let flavorText: String

  // MARK: Features
  /// Passives, reactions, and actions this environment contributes to the scene.
  public let features: [EncounterFeature]

  // MARK: - CodingKeys

  enum CodingKeys: String, CodingKey {
    case id, name, source, description
    // SRD JSON uses "feature"; homebrew/export uses "feature" too.
    case features = "feature"
  }

  // MARK: - Decodable

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // name decoded first so it can serve as the id fallback.
    name = try c.decode(String.self, forKey: .name)
    // SRD JSON has no id field; derive a slug from the name.
    id =
      try c.decodeIfPresent(String.self, forKey: .id)
      ?? name.lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
      .joined(separator: "-")
    // Normalize source to lowercase so "SRD", "srd", "Homebrew", etc. all compare equal.
    source = (try c.decodeIfPresent(String.self, forKey: .source) ?? "srd").lowercased()
    flavorText = try c.decode(String.self, forKey: .description)
    features = try c.decodeIfPresent([EncounterFeature].self, forKey: .features) ?? []
  }

  // MARK: - Encodable

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(source, forKey: .source)
    try c.encode(flavorText, forKey: .description)
    try c.encode(features, forKey: .features)
  }

  // MARK: - Memberwise init (for previews / tests)

  public init(
    id: String,
    name: String,
    source: String = "srd",
    flavorText: String,
    features: [EncounterFeature] = []
  ) {
    self.id = id
    self.name = name
    self.source = source
    self.flavorText = flavorText
    self.features = features
  }
}

// MARK: - CustomStringConvertible

extension DaggerheartEnvironment: CustomStringConvertible {
  /// The environment's display name.
  public var description: String { name }
}

extension DaggerheartEnvironment: CustomDebugStringConvertible {
  /// A debug-focused identity string with feature count.
  public var debugDescription: String {
    "Environment(id: \(id), name: \(name), features: \(features.count))"
  }
}
