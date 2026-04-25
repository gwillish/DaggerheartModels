//
//  ModelTests.swift
//  DaggerheartModelsTests
//
//  Unit tests for pure Codable model types:
//  Adversary, Condition, EncounterDefinition,
//  DifficultyBudget, DaggerheartEnvironment.
//

import Foundation
import Testing

@testable import DHModels

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

// MARK: - Adversary Decoding

struct AdversaryDecodingTests {

  // MARK: Combined threshold string ("8/15")

  @Test func decodesThresholdsFromCombinedString() throws {
    let json = """
      {
        "id": "test-creature",
        "name": "Test Creature",
        "source": "SRD",
        "tier": 1,
        "type": "Bruiser",
        "description": "A test creature.",
        "difficulty": 12,
        "thresholds": "8/15",
        "hp": 8,
        "stress": 3,
        "atk": "+3",
        "attack": "Claws",
        "range": "Very Close",
        "damage": "1d10+2 phy",
        "feature": []
      }
      """.data(using: .utf8)!

    let adversary = try JSONDecoder().decode(Adversary.self, from: json)
    #expect(adversary.thresholdMajor == 8)
    #expect(adversary.thresholdSevere == 15)
  }

  // MARK: Pre-split threshold keys

  @Test func decodesThresholdsFromSplitKeys() throws {
    let json = """
      {
        "id": "warlord-keth",
        "name": "Warlord Keth",
        "tier": 2,
        "type": "Leader",
        "description": "A scarred half-giant general.",
        "difficulty": 14,
        "threshold_major": 9,
        "threshold_severe": 17,
        "hp": 12,
        "stress": 6,
        "atk": "+5",
        "attack": "Greataxe",
        "range": "Very Close",
        "damage": "2d10+4 phy",
        "feature": []
      }
      """.data(using: .utf8)!

    let adversary = try JSONDecoder().decode(Adversary.self, from: json)
    #expect(adversary.thresholdMajor == 9)
    #expect(adversary.thresholdSevere == 17)
    #expect(adversary.source == "srd")  // absent in JSON → default "srd" (lowercased)
  }

  // MARK: Feature decoding

  @Test func decodesFeatures() throws {
    let json = """
      {
        "id": "test",
        "name": "Test",
        "tier": 1,
        "type": "Minion",
        "description": "Desc",
        "difficulty": 9,
        "thresholds": "3/6",
        "hp": 3,
        "stress": 2,
        "atk": "+1",
        "attack": "Bite",
        "range": "Very Close",
        "damage": "1d6 phy",
        "feature": [
          { "name": "Pack Tactics", "text": "Deals bonus damage in groups.", "feat_type": "passive" },
          { "name": "Snap",         "text": "Triggers when hit.",            "feat_type": "reaction" },
          { "name": "Lunge",        "text": "Extra attack once per round.",  "feat_type": "action" }
        ]
      }
      """.data(using: .utf8)!

    let adversary = try JSONDecoder().decode(Adversary.self, from: json)
    #expect(adversary.features.count == 3)
    #expect(adversary.features[0].kind == FeatureType.passive)
    #expect(adversary.features[1].kind == FeatureType.reaction)
    #expect(adversary.features[2].kind == FeatureType.action)
  }

  // MARK: AdversaryType round-trip

  @Test func adversaryTypeRoundTrip() throws {
    for type_ in AdversaryType.allCases {
      let encoded = try JSONEncoder().encode(type_)
      let decoded = try JSONDecoder().decode(AdversaryType.self, from: encoded)
      #expect(decoded == type_)
    }
  }

  // MARK: AttackRange round-trip

  @Test func attackRangeRoundTrip() throws {
    for range in AttackRange.allCases {
      let encoded = try JSONEncoder().encode(range)
      let decoded = try JSONDecoder().decode(AttackRange.self, from: encoded)
      #expect(decoded == range)
    }
  }

  // MARK: New SRD adversary types (Skulk, Social, Support)

  @Test func decodesNewAdversaryTypes() throws {
    for typeString in ["Skulk", "Social", "Support"] {
      let json = """
        {
          "id": "test-\(typeString.lowercased())",
          "name": "Test \(typeString)",
          "tier": 1,
          "type": "\(typeString)",
          "description": "A test creature.",
          "difficulty": 10,
          "thresholds": "5/10",
          "hp": 4,
          "stress": 2,
          "atk": "+2",
          "attack": "Strike",
          "range": "Close",
          "damage": "1d6 phy",
          "feature": []
        }
        """.data(using: .utf8)!

      let adversary = try JSONDecoder().decode(Adversary.self, from: json)
      #expect(adversary.role.rawValue == typeString)
    }
  }

  @Test func adversaryTypeHasAllTenCases() {
    #expect(AdversaryType.allCases.count == 10)
  }

  // MARK: Malformed threshold throws

  @Test func malformedThresholdStringThrows() {
    let json = """
      {
        "id": "bad",
        "name": "Bad",
        "tier": 1,
        "type": "Minion",
        "description": "Desc",
        "difficulty": 9,
        "thresholds": "notanumber",
        "hp": 3,
        "stress": 2,
        "atk": "+1",
        "attack": "Bite",
        "range": "Close",
        "damage": "1d6 phy",
        "feature": []
      }
      """.data(using: .utf8)!

    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(Adversary.self, from: json)
    }
  }
}

// MARK: - Condition

struct ConditionTests {

  @Test func standardConditionsExist() {
    let conditions: Set<Condition> = [.hidden, .restrained, .vulnerable]
    #expect(conditions.count == 3)
  }

  @Test func customConditionEquality() {
    let c1 = Condition.custom("Enraged")
    let c2 = Condition.custom("Enraged")
    let c3 = Condition.custom("Prone")
    #expect(c1 == c2)
    #expect(c1 != c3)
  }

  @Test func conditionSetPreventsStacking() {
    var conditions: Set<Condition> = []
    conditions.insert(.hidden)
    conditions.insert(.hidden)
    #expect(conditions.count == 1)
  }

  @Test func conditionCodableRoundTrip() throws {
    let original: Set<Condition> = [.hidden, .restrained, .custom("Enraged")]
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Set<Condition>.self, from: data)
    #expect(decoded == original)
  }

  @Test func conditionDisplayName() {
    #expect(Condition.hidden.displayName == "Hidden")
    #expect(Condition.restrained.displayName == "Restrained")
    #expect(Condition.vulnerable.displayName == "Vulnerable")
    #expect(Condition.custom("Enraged").displayName == "Enraged")
  }
}

// MARK: - EncounterDefinition

struct EncounterDefinitionTests {

  @Test func definitionIsValueType() {
    var def1 = EncounterDefinition(name: "Test")
    let def2 = def1
    def1.name = "Modified"
    #expect(def2.name == "Test")
  }

  @Test func definitionCodableRoundTrip() throws {
    var definition = EncounterDefinition(name: "Bandit Ambush")
    definition.adversaryIDs = ["ironguard-soldier", "ironguard-soldier", "thornwood-archer"]
    definition.environmentIDs = ["collapsing-bridge"]
    definition.playerConfigs = [
      PlayerConfig(
        name: "Aldric", maxHP: 6, maxStress: 6,
        evasion: 12, thresholdMajor: 8, thresholdSevere: 15, armorSlots: 3
      )
    ]
    definition.gmNotes = "Start with archers hidden."

    let data = try JSONEncoder().encode(definition)
    let decoded = try JSONDecoder().decode(EncounterDefinition.self, from: data)

    #expect(decoded.name == "Bandit Ambush")
    #expect(decoded.adversaryIDs.count == 3)
    #expect(decoded.environmentIDs == ["collapsing-bridge"])
    #expect(decoded.playerConfigs.count == 1)
    #expect(decoded.playerConfigs[0].name == "Aldric")
    #expect(decoded.gmNotes == "Start with archers hidden.")
  }

  @Test func definitionHasTimestamps() {
    let before = Date.now
    let definition = EncounterDefinition(name: "Test")
    let after = Date.now
    #expect(definition.createdAt >= before)
    #expect(definition.createdAt <= after)
    #expect(definition.modifiedAt >= before)
  }

  @Test func modifiedAtOnlyChangesAfterSave() {
    var def = EncounterDefinition(name: "Test")
    let before = def.modifiedAt
    def.name = "Changed"
    def.adversaryIDs = ["ironguard-soldier"]
    def.gmNotes = "Remember the trap."
    // Direct property mutations must NOT update modifiedAt — only store.save() stamps it.
    #expect(def.modifiedAt == before)
  }

  @Test func decodingDoesNotResetModifiedAt() throws {
    let definition = EncounterDefinition(
      name: "Test",
      modifiedAt: Date(timeIntervalSince1970: 1_000_000)
    )
    let data = try JSONEncoder().encode(definition)
    let decoded = try JSONDecoder().decode(EncounterDefinition.self, from: data)
    #expect(decoded.modifiedAt == definition.modifiedAt)
  }

  @Test func playerConfigCodableRoundTrip() throws {
    let config = PlayerConfig(
      name: "Sera", level: 3, maxHP: 8, maxStress: 6,
      evasion: 14, thresholdMajor: 10, thresholdSevere: 18, armorSlots: 4
    )
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(PlayerConfig.self, from: data)

    #expect(decoded.name == "Sera")
    #expect(decoded.level == 3)
    #expect(decoded.maxHP == 8)
    #expect(decoded.evasion == 14)
    #expect(decoded.armorSlots == 4)
  }

  @Test func playerConfigLevelDefaultsToOneWhenAbsentInJSON() throws {
    let json = try #require(
      """
      {
        "id": "00000000-0000-0000-0000-000000000002",
        "name": "Legacy",
        "maxHP": 6,
        "maxStress": 6,
        "evasion": 12,
        "thresholdMajor": 8,
        "thresholdSevere": 15,
        "armorSlots": 3
      }
      """.data(using: .utf8))
    let decoded = try JSONDecoder().decode(PlayerConfig.self, from: json)
    #expect(decoded.level == 1)
  }
}

// MARK: - DifficultyBudget

struct DifficultyBudgetTests {

  // MARK: Battle Point Costs

  @Test func minionCostsOnePoint() {
    #expect(DifficultyBudget.cost(for: .minion) == 1)
  }

  @Test func socialAndSupportCostOnePoint() {
    #expect(DifficultyBudget.cost(for: .social) == 1)
    #expect(DifficultyBudget.cost(for: .support) == 1)
  }

  @Test func standardTierCostsTwoPoints() {
    for type in [AdversaryType.horde, .ranged, .skulk, .standard] {
      #expect(
        DifficultyBudget.cost(for: type) == 2,
        "Expected \(type) to cost 2, got \(DifficultyBudget.cost(for: type))"
      )
    }
  }

  @Test func leaderCostsThreePoints() {
    #expect(DifficultyBudget.cost(for: .leader) == 3)
  }

  @Test func bruiserCostsFourPoints() {
    #expect(DifficultyBudget.cost(for: .bruiser) == 4)
  }

  @Test func soloCostsFivePoints() {
    #expect(DifficultyBudget.cost(for: .solo) == 5)
  }

  // MARK: Base Budget

  @Test func baseBudgetForFourPCs() {
    #expect(DifficultyBudget.baseBudget(playerCount: 4) == 14)
  }

  @Test func baseBudgetForThreePCs() {
    #expect(DifficultyBudget.baseBudget(playerCount: 3) == 11)
  }

  @Test func baseBudgetForOnePCMinimum() {
    #expect(DifficultyBudget.baseBudget(playerCount: 1) == 5)
  }

  // MARK: Total Cost

  @Test func totalCostForAdversaryList() {
    let types: [AdversaryType] = [.minion, .minion, .bruiser, .leader]
    #expect(DifficultyBudget.totalCost(for: types) == 9)
  }

  // MARK: Rating

  @Test func ratingWithinBudgetIsBalanced() throws {
    let rating = try #require(
      DifficultyBudget.rating(
        adversaryTypes: [.standard, .standard, .minion],
        playerCount: 4
      ))
    #expect(rating.cost == 5)
    #expect(rating.budget == 14)
    #expect(rating.remaining == 9)
  }

  @Test func ratingOverBudgetShowsNegativeRemaining() throws {
    let rating = try #require(
      DifficultyBudget.rating(
        adversaryTypes: [.solo, .solo, .bruiser],
        playerCount: 3
      ))
    #expect(rating.cost == 14)
    #expect(rating.budget == 11)
    #expect(rating.remaining == -3)
  }

  @Test func ratingWithBudgetAdjustment() throws {
    let rating = try #require(
      DifficultyBudget.rating(
        adversaryTypes: [.standard],
        playerCount: 4,
        budgetAdjustment: -2
      ))
    #expect(rating.budget == 12)
    #expect(rating.cost == 2)
    #expect(rating.remaining == 10)
  }

  @Test func ratingReturnsNilForZeroPlayers() {
    #expect(DifficultyBudget.rating(adversaryTypes: [.standard], playerCount: 0) == nil)
  }

  @Test func ratingReturnsNilForNegativePlayers() {
    #expect(DifficultyBudget.rating(adversaryTypes: [], playerCount: -1) == nil)
  }

  // MARK: Rating.category / displayName

  @Test func categoryTooEasy() {
    // lower boundary (4) and a value well above
    #expect(DifficultyBudget.Rating(budget: 14, cost: 10, remaining: 4).category == .tooEasy)
    #expect(DifficultyBudget.Rating(budget: 14, cost: 4, remaining: 10).category == .tooEasy)
  }

  @Test func categoryWellMatched() {
    #expect(DifficultyBudget.Rating(budget: 14, cost: 11, remaining: 3).category == .wellMatched)
    #expect(DifficultyBudget.Rating(budget: 14, cost: 13, remaining: 1).category == .wellMatched)
  }

  @Test func categoryOnBudget() {
    #expect(DifficultyBudget.Rating(budget: 14, cost: 14, remaining: 0).category == .onBudget)
  }

  @Test func categoryChallenging() {
    #expect(DifficultyBudget.Rating(budget: 14, cost: 15, remaining: -1).category == .challenging)
    #expect(DifficultyBudget.Rating(budget: 14, cost: 17, remaining: -3).category == .challenging)
  }

  @Test func categoryDangerous() {
    #expect(DifficultyBudget.Rating(budget: 14, cost: 18, remaining: -4).category == .dangerous)
    #expect(DifficultyBudget.Rating(budget: 14, cost: 20, remaining: -6).category == .dangerous)
  }

  @Test func categoryLikelyTPK() {
    // boundary (-7) and a value well below
    #expect(DifficultyBudget.Rating(budget: 14, cost: 21, remaining: -7).category == .likelyTPK)
    #expect(DifficultyBudget.Rating(budget: 14, cost: 24, remaining: -10).category == .likelyTPK)
  }

  @Test func displayNameMatchesCategoryRawValue() {
    let rating = DifficultyBudget.Rating(budget: 14, cost: 14, remaining: 0)
    #expect(rating.displayName == rating.category.rawValue)
    #expect(rating.displayName == "On Budget")
  }

  // MARK: Adjustment Suggestions

  @Test func adjustmentForMultipleSolos() {
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [.solo, .solo]
    )
    #expect(adjustments.contains(.multipleSolos))
  }

  @Test func noMultipleSolosForSingleSolo() {
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [.solo]
    )
    #expect(!adjustments.contains(.multipleSolos))
  }

  @Test func adjustmentForNoBigThreats() {
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [.standard, .minion, .ranged]
    )
    #expect(adjustments.contains(.noBigThreats))
  }

  @Test func noBigThreatsNotSuggestedWhenBruiserPresent() {
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [.standard, .bruiser]
    )
    #expect(!adjustments.contains(.noBigThreats))
  }

  @Test func emptyRosterHasNoSuggestions() {
    let adjustments = DifficultyBudget.suggestedAdjustments(adversaryTypes: [])
    #expect(adjustments.isEmpty)
  }

  @Test func adjustmentPointValues() {
    #expect(DifficultyBudget.Adjustment.easierFight.pointValue == -1)
    #expect(DifficultyBudget.Adjustment.multipleSolos.pointValue == -2)
    #expect(DifficultyBudget.Adjustment.boostedDamage.pointValue == -2)
    #expect(DifficultyBudget.Adjustment.lowerTierAdversary.pointValue == 1)
    #expect(DifficultyBudget.Adjustment.noBigThreats.pointValue == 1)
    #expect(DifficultyBudget.Adjustment.harderFight.pointValue == 2)
  }

  // MARK: Tier Utilities

  @Test(arguments: zip(1...10, [1, 2, 2, 2, 3, 3, 3, 4, 4, 4]))
  func tierForLevel(level: Int, expectedTier: Int) {
    #expect(DifficultyBudget.tier(forLevel: level) == expectedTier)
  }

  @Test func partyTierSinglePlayer() {
    #expect(DifficultyBudget.partyTier(levels: [1]) == 1)
    #expect(DifficultyBudget.partyTier(levels: [5]) == 3)
    #expect(DifficultyBudget.partyTier(levels: [9]) == 4)
  }

  @Test func partyTierEmptyIsT1() {
    #expect(DifficultyBudget.partyTier(levels: []) == 1)
  }

  @Test func partyTierMedianBoundaryRoundsUp() {
    // [2,3,4,5] → median 3.5 → ceil 4 → T2
    #expect(DifficultyBudget.partyTier(levels: [2, 3, 4, 5]) == 2)
    // [4,5] → median 4.5 → ceil 5 → T3
    #expect(DifficultyBudget.partyTier(levels: [4, 5]) == 3)
  }

  @Test func partyTierOddCount() {
    // [7,8,9] → median 8 → T4
    #expect(DifficultyBudget.partyTier(levels: [7, 8, 9]) == 4)
  }

  // MARK: lowerTierAdversary auto-detection

  @Test func lowerTierAdversaryDetectedWhenPresent() {
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [.standard, .minion],
      adversaryTiers: [3, 1],
      partyTier: 3
    )
    #expect(adjustments.contains(.lowerTierAdversary))
  }

  @Test func lowerTierAdversaryNotDetectedWhenAllTiersMatch() {
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [.standard, .minion],
      adversaryTiers: [3, 3],
      partyTier: 3
    )
    #expect(!adjustments.contains(.lowerTierAdversary))
  }

  @Test func lowerTierAdversaryNotDetectedWithoutPartyTier() {
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [.standard],
      adversaryTiers: [1],
      partyTier: nil
    )
    #expect(!adjustments.contains(.lowerTierAdversary))
  }

  @Test func lowerTierAdversaryIgnoresUnknownTierZero() {
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [.standard],
      adversaryTiers: [0],
      partyTier: 3
    )
    #expect(!adjustments.contains(.lowerTierAdversary))
  }

  @Test func lowerTierAdversaryNotDetectedWithEmptyRoster() {
    // adversaryTiers has a lower-tier entry but adversaryTypes is empty —
    // zip silences the dangling tier, so no adjustment should fire.
    let adjustments = DifficultyBudget.suggestedAdjustments(
      adversaryTypes: [],
      adversaryTiers: [1],
      partyTier: 3
    )
    #expect(!adjustments.contains(.lowerTierAdversary))
  }

  @Test func suggestedAdjustmentsBackwardCompatible() {
    // Calling with no tier params must still detect multipleSolos / noBigThreats.
    let adjustments = DifficultyBudget.suggestedAdjustments(adversaryTypes: [.solo, .solo])
    #expect(adjustments.contains(.multipleSolos))
  }
}

// MARK: - Player

struct PlayerTests {

  @Test func playerIsValueType() {
    var player1 = Player(
      name: "Aldric", maxHP: 6, maxStress: 6,
      evasion: 12, thresholdMajor: 8, thresholdSevere: 15, armorSlots: 3
    )
    let player2 = player1
    player1.name = "Modified"
    #expect(player2.name == "Aldric")
  }

  @Test func playerCodableRoundTrip() throws {
    let player = Player(
      name: "Sera", maxHP: 8, maxStress: 6,
      evasion: 14, thresholdMajor: 10, thresholdSevere: 18, armorSlots: 4
    )
    let data = try JSONEncoder().encode(player)
    let decoded = try JSONDecoder().decode(Player.self, from: data)

    #expect(decoded.id == player.id)
    #expect(decoded.name == "Sera")
    #expect(decoded.maxHP == 8)
    #expect(decoded.maxStress == 6)
    #expect(decoded.evasion == 14)
    #expect(decoded.thresholdMajor == 10)
    #expect(decoded.thresholdSevere == 18)
    #expect(decoded.armorSlots == 4)
  }

  @Test func playerDefaultLevelIsOne() {
    let player = Player(
      name: "Aldric", maxHP: 6, maxStress: 6,
      evasion: 12, thresholdMajor: 8, thresholdSevere: 15, armorSlots: 3
    )
    #expect(player.level == 1)
  }

  @Test func playerLevelRoundTrip() throws {
    let player = Player(
      name: "Sera", level: 5, maxHP: 8, maxStress: 6,
      evasion: 14, thresholdMajor: 10, thresholdSevere: 18, armorSlots: 4
    )
    let data = try JSONEncoder().encode(player)
    let decoded = try JSONDecoder().decode(Player.self, from: data)
    #expect(decoded.level == 5)
  }

  @Test func playerLevelDefaultsToOneWhenAbsentInJSON() throws {
    let json = try #require(
      """
      {
        "id": "00000000-0000-0000-0000-000000000001",
        "name": "Legacy",
        "maxHP": 6,
        "maxStress": 6,
        "evasion": 12,
        "thresholdMajor": 8,
        "thresholdSevere": 15,
        "armorSlots": 3
      }
      """.data(using: .utf8))
    let decoded = try JSONDecoder().decode(Player.self, from: json)
    #expect(decoded.level == 1)
  }

  @Test func asConfigPreservesAllFields() {
    let player = Player(
      name: "Torven", level: 4, maxHP: 10, maxStress: 5,
      evasion: 11, thresholdMajor: 7, thresholdSevere: 14, armorSlots: 2
    )
    let config = player.asConfig()

    #expect(config.id == player.id)
    #expect(config.name == player.name)
    #expect(config.level == player.level)
    #expect(config.maxHP == player.maxHP)
    #expect(config.maxStress == player.maxStress)
    #expect(config.evasion == player.evasion)
    #expect(config.thresholdMajor == player.thresholdMajor)
    #expect(config.thresholdSevere == player.thresholdSevere)
    #expect(config.armorSlots == player.armorSlots)
  }
}

// MARK: - Party

struct PartyTests {

  @Test func partyIsValueType() {
    var party1 = Party(name: "The Wanderers")
    let party2 = party1
    party1.name = "Modified"
    #expect(party2.name == "The Wanderers")
  }

  @Test func partyCodableRoundTrip() throws {
    let ids = [UUID(), UUID(), UUID()]
    let party = Party(name: "Ironclad Company", playerIDs: ids)
    let data = try JSONEncoder().encode(party)
    let decoded = try JSONDecoder().decode(Party.self, from: data)

    #expect(decoded.id == party.id)
    #expect(decoded.name == "Ironclad Company")
    #expect(decoded.playerIDs == ids)
  }

  @Test func playerIDsOrderIsPreserved() throws {
    let ids = (0..<5).map { _ in UUID() }
    let party = Party(name: "Order Test", playerIDs: ids)
    let data = try JSONEncoder().encode(party)
    let decoded = try JSONDecoder().decode(Party.self, from: data)

    #expect(decoded.playerIDs == ids)
  }

  @Test func defaultPartyHasNoPlayers() {
    let party = Party(name: "Empty")
    #expect(party.playerIDs.isEmpty)
  }
}

// MARK: - DaggerheartEnvironment

struct EnvironmentModelTests {

  @Test func decodesFromJSON() throws {
    let json = """
      {
        "id": "arcane-storm",
        "name": "Arcane Storm",
        "source": "SRD",
        "description": "A tempest of wild magic.",
        "feature": [
          { "name": "Wild Discharge", "text": "Deals damage at random.", "feat_type": "passive" }
        ]
      }
      """.data(using: .utf8)!

    let env = try JSONDecoder().decode(DaggerheartEnvironment.self, from: json)
    #expect(env.id == "arcane-storm")
    #expect(env.features.count == 1)
    #expect(env.features[0].kind == FeatureType.passive)
  }
}
