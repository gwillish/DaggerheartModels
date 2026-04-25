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

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

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
  public static func cost(for role: AdversaryType) -> Int {
    switch role {
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
    public let cost: Int
    /// Budget minus cost. Negative means over-budget.
    public let remaining: Int

    public init(budget: Int, cost: Int, remaining: Int) {
      self.budget = budget
      self.cost = cost
      self.remaining = remaining
    }
  }

  /// Compute the difficulty rating for an adversary roster against a player count.
  ///
  /// - Parameters:
  ///   - adversaryTypes: The types of all adversaries in the encounter.
  ///   - playerCount: Number of player characters.
  ///   - budgetAdjustment: Manual adjustment to the base budget (from ``Adjustment`` point values).
  /// - Returns: A ``Rating`` with budget, cost, and remaining points, or `nil` when `playerCount` is zero.
  public static func rating(
    adversaryTypes: [AdversaryType],
    playerCount: Int,
    budgetAdjustment: Int = 0
  ) -> Rating? {
    guard playerCount > 0 else { return nil }
    let budget = baseBudget(playerCount: playerCount) + budgetAdjustment
    let cost = totalCost(for: adversaryTypes)
    return Rating(budget: budget, cost: cost, remaining: budget - cost)
  }

  // MARK: - Tier Utilities

  /// Returns the Daggerheart tier (1–4) for a given character level (1–10).
  ///
  /// | Level | Tier |
  /// |-------|------|
  /// | 1     | 1    |
  /// | 2–4   | 2    |
  /// | 5–7   | 3    |
  /// | 8–10  | 4    |
  ///
  /// Per SRD "Building Balanced Encounters".
  public static func tier(forLevel level: Int) -> Int {
    switch level {
    case ...1: return 1
    case 2...4: return 2
    case 5...7: return 3
    default: return 4
    }
  }

  /// Returns the party tier derived from the median character level.
  ///
  /// The median level is computed, then rounded up (ceiling) before mapping
  /// to tier. When the median straddles a tier boundary the party is treated
  /// as the higher tier — giving slightly more adversary budget latitude.
  /// Empty input returns Tier 1 as a safe default.
  ///
  /// Examples:
  /// - `[1]` → median 1 → T1
  /// - `[2, 3, 4, 5]` → median 3.5 → ceil 4 → T2
  /// - `[4, 5]` → median 4.5 → ceil 5 → T3
  /// - `[7, 8, 9]` → median 8 → T4
  public static func partyTier(levels: [Int]) -> Int {
    guard !levels.isEmpty else { return 1 }
    let sorted = levels.sorted()
    let count = sorted.count
    let medianLevel: Double
    if count % 2 == 1 {
      medianLevel = Double(sorted[count / 2])
    } else {
      medianLevel = (Double(sorted[count / 2 - 1]) + Double(sorted[count / 2])) / 2.0
    }
    let ceiledLevel = Int(ceil(medianLevel))
    return tier(forLevel: ceiledLevel)
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

    /// Human-readable display name for UI rendering.
    public var displayName: String {
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
  /// Mechanically detected adjustments:
  /// - `.multipleSolos` — 2 or more Solo types in the roster.
  /// - `.noBigThreats` — no Bruiser, Horde, Leader, or Solo types, and the roster is non-empty.
  /// - `.lowerTierAdversary` — `partyTier` is non-nil and at least one adversary has a
  ///   known tier (non-zero entry in `adversaryTiers`) strictly less than `partyTier`.
  ///
  /// GM-discretionary adjustments (easier/harder fight, boosted damage) are never
  /// auto-detected and must be toggled manually.
  ///
  /// - Parameters:
  ///   - adversaryTypes: The types of all adversaries in the encounter.
  ///   - adversaryTiers: Tiers parallel to `adversaryTypes`; use `0` for unknown.
  ///   - partyTier: The party's derived tier; pass `nil` to skip lower-tier detection.
  public static func suggestedAdjustments(
    adversaryTypes: [AdversaryType],
    adversaryTiers: [Int] = [],
    partyTier: Int? = nil
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

    if let pt = partyTier {
      let hasLowerTier = zip(adversaryTypes, adversaryTiers).contains { _, tier in
        tier > 0 && tier < pt
      }
      if hasLowerTier {
        result.insert(.lowerTierAdversary)
      }
    }

    return result
  }
}

extension DifficultyBudget.Rating {
  /// Human-readable difficulty description based on `remaining` (budget − cost).
  ///
  /// Positive values indicate unspent budget; negative values indicate the
  /// roster exceeds the recommended budget. Thresholds match those in
  /// `DifficultyAssessorView` in the Encounter app.
  public var label: String {
    switch remaining {
    case 4...: return "Too Easy"
    case 1...3: return "Well Matched"
    case 0: return "On Budget"
    case -3...(-1): return "Challenging"
    case -6...(-4): return "Dangerous"
    default: return "Likely TPK"
    }
  }
}
