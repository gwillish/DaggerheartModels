//
//  Condition.swift
//  Encounter
//
//  Status effects that can be applied to combatants in a Daggerheart encounter.
//
//  The three standard conditions come from the SRD:
//  - Hidden: Rolls against this creature have disadvantage.
//  - Restrained: Cannot move, but can still take actions.
//  - Vulnerable: All rolls targeting this creature have advantage.
//
//  Features may impose unique conditions via the `.custom` case.
//  Per the SRD, the same condition cannot stack on a target.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
import Foundation

/// A condition that can be applied to a combatant in a Daggerheart encounter.
///
/// The SRD defines three standard conditions. Feature abilities may impose
/// additional conditions via `.custom(String)`. The same condition cannot
/// stack on a single target — use `Set<Condition>` to enforce this.
nonisolated public enum Condition: Hashable, Sendable, Codable {
  /// Rolls against this creature have disadvantage.
  /// Removed when an adversary moves to see you, you move into sight, or you attack.
  case hidden
  /// Cannot move, but can take actions from current position.
  /// Cleared with a successful action roll (PCs) or GM spending spotlight (adversaries).
  case restrained
  /// All rolls targeting this creature have advantage.
  /// Applied when a PC marks all Stress. Cleared with a move.
  case vulnerable
  /// A feature-imposed condition with a custom name.
  case custom(String)

  /// The three standard SRD conditions available for toggle in encounter UI.
  /// `.custom` is omitted because it requires a name parameter.
  public static let standardConditions: [Condition] = [.hidden, .restrained, .vulnerable]

  /// Human-readable display name for UI rendering.
  public var displayName: String {
    switch self {
    case .hidden: return "Hidden"
    case .restrained: return "Restrained"
    case .vulnerable: return "Vulnerable"
    case .custom(let name): return name
    }
  }

  // MARK: - Codable

  private enum CodingKeys: String, CodingKey {
    case type, name
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .hidden:
      try container.encode("hidden", forKey: .type)
    case .restrained:
      try container.encode("restrained", forKey: .type)
    case .vulnerable:
      try container.encode("vulnerable", forKey: .type)
    case .custom(let name):
      try container.encode("custom", forKey: .type)
      try container.encode(name, forKey: .name)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "hidden": self = .hidden
    case "restrained": self = .restrained
    case "vulnerable": self = .vulnerable
    case "custom":
      let name = try container.decode(String.self, forKey: .name)
      self = .custom(name)
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container,
        debugDescription: "Unknown condition type: '\(type)'"
      )
    }
  }
}
