//
//  DifficultyBudget.swift
//  Encounter
//
//  Pure-function service for computing Daggerheart encounter difficulty
//  using the Battle Points system from the SRD.
//
//  All functions are static and take only value-type inputs.
//  This type has no state and no dependencies on session or UI.
//
//  SRD Reference — "Building Balanced Encounters":
//  Base budget: (3 × playerCount) + 2
//  Then apply adjustments and spend points to add adversaries by type.
//

import Foundation

/// Pure-function namespace for computing Daggerheart encounter difficulty
/// using the Battle Points system from the SRD.
///
/// All functions are static and operate on value types only.
/// No state, no dependencies on ``EncounterSession`` or UI.
nonisolated public enum DifficultyBudget {

  // MARK: - Battle Point Cost per Type

  /// The Battle Point cost for a single adversary of the given type.
  ///
  /// Per SRD "Building Balanced Encounters":
  /// - Minion group, Social, Support: 1 point
  /// - Horde, Ranged, Skulk, Standard: 2 points
  /// - Leader: 3 points
  /// - Bruiser: 4 points
  /// - Solo: 5 points
  public static func cost(for type: AdversaryType) -> Int {
    switch type {
    case .minion, .social, .support: return 1
    case .horde, .ranged, .skulk, .standard: return 2
    case .leader: return 3
    case .bruiser: return 4
    case .solo: return 5
    }
  }

  // MARK: - Base Budget

  /// The starting Battle Point budget before adjustments.
  ///
  /// Formula: `(3 × playerCount) + 2`
  public static func baseBudget(playerCount: Int) -> Int {
    (3 * playerCount) + 2
  }

  // MARK: - Total Cost

  /// Sum of Battle Point costs for a list of adversary types.
  public static func totalCost(for types: [AdversaryType]) -> Int {
    types.reduce(0) { $0 + cost(for: $1) }
  }

  // MARK: - Rating

  /// A snapshot of the encounter's difficulty budget analysis.
  nonisolated public struct Rating: Sendable, Equatable, Hashable {
    /// Total Battle Points available (base budget + adjustment).
    public let budget: Int
    /// Total Battle Points spent on the adversary roster.
    public let totalCost: Int
    /// Budget minus cost. Negative means over-budget.
    public let remaining: Int
  }

  /// Compute the difficulty rating for an adversary roster against a player count.
  ///
  /// - Parameters:
  ///   - adversaryTypes: The types of all adversaries in the encounter.
  ///   - playerCount: Number of player characters.
  ///   - budgetAdjustment: Manual adjustment to the base budget (from ``Adjustment`` point values).
  /// - Returns: A ``Rating`` with budget, cost, and remaining points.
  public static func rating(
    adversaryTypes: [AdversaryType],
    playerCount: Int,
    budgetAdjustment: Int = 0
  ) -> Rating {
    let budget = baseBudget(playerCount: playerCount) + budgetAdjustment
    let cost = totalCost(for: adversaryTypes)
    return Rating(budget: budget, totalCost: cost, remaining: budget - cost)
  }

  // MARK: - Adjustment Suggestions

  /// Predefined budget adjustments from the SRD.
  nonisolated public enum Adjustment: Sendable, Equatable, Hashable, CaseIterable {
    /// -1 for an easier or shorter fight.
    case easierFight
    /// -2 if using 2+ Solo adversaries.
    case multipleSolos
    /// -2 if adding +1d4 (or static +2) to all adversary damage.
    case boostedDamage
    /// +1 if choosing an adversary from a lower tier.
    case lowerTierAdversary
    /// +1 if no Bruisers, Hordes, Leaders, or Solos in the roster.
    case noBigThreats
    /// +2 for a harder or longer fight.
    case harderFight

    /// The Battle Point adjustment this represents.
    public var pointValue: Int {
      switch self {
      case .easierFight: return -1
      case .multipleSolos: return -2
      case .boostedDamage: return -2
      case .lowerTierAdversary: return 1
      case .noBigThreats: return 1
      case .harderFight: return 2
      }
    }

    /// Human-readable description for UI display.
    public var label: String {
      switch self {
      case .easierFight: return "Easier/shorter fight"
      case .multipleSolos: return "Using 2+ Solo adversaries"
      case .boostedDamage: return "Boosted adversary damage (+1d4 or +2)"
      case .lowerTierAdversary: return "Adversary from a lower tier"
      case .noBigThreats: return "No Bruisers, Hordes, Leaders, or Solos"
      case .harderFight: return "Harder/longer fight"
      }
    }
  }

  /// Determine which SRD adjustments apply automatically based on the roster.
  ///
  /// Only returns adjustments that can be mechanically detected:
  /// - `.multipleSolos` if 2+ Solo types
  /// - `.noBigThreats` if no Bruiser, Horde, Leader, or Solo types
  ///
  /// GM-discretionary adjustments (easier/harder fight, boosted damage,
  /// lower tier) must be toggled manually in the UI.
  public static func suggestedAdjustments(
    adversaryTypes: [AdversaryType]
  ) -> Set<Adjustment> {
    var result: Set<Adjustment> = []

    let soloCount = adversaryTypes.count(where: { $0 == .solo })
    if soloCount >= 2 {
      result.insert(.multipleSolos)
    }

    let bigThreatTypes: Set<AdversaryType> = [.bruiser, .horde, .leader, .solo]
    let hasBigThreat = adversaryTypes.contains { bigThreatTypes.contains($0) }
    if !hasBigThreat && !adversaryTypes.isEmpty {
      result.insert(.noBigThreats)
    }

    return result
  }
}
