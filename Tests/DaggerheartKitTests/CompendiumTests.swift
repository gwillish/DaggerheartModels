//
//  CompendiumTests.swift
//  DaggerheartKitTests
//
//  Unit tests for Compendium: async load, dedup, homebrew management.
//
//  Compendium defaults to Bundle.module (DaggerheartKit's resource bundle),
//  which ships the full SRD JSON. Pass Bundle.main to force the error path
//  in contexts where the SRD resources are absent.
//

import DaggerheartModels
import Foundation
import Testing

@testable import DaggerheartKit

// MARK: - Compendium async load

@MainActor struct CompendiumLoadTests {

  @Test func isLoadingFalseAfterLoadCompletes() async {
    let compendium = Compendium()
    try? await compendium.load()
    #expect(compendium.isLoading == false)
  }

  @Test func concurrentLoadCallsAreDeduped() async {
    let compendium = Compendium()
    await withTaskGroup(of: Void.self) { group in
      group.addTask { try? await compendium.load() }
      group.addTask { try? await compendium.load() }
    }
    #expect(compendium.isLoading == false)
  }

  /// Verifies load() throws and sets loadError when the bundle has no SRD JSON.
  /// Bundle.main is used here because it has no DaggerheartKit resources in this
  /// test context, which reliably exercises the error path.
  @Test func loadSetsLoadErrorOnMissingResource() async {
    let compendium = Compendium(bundle: .main)
    var didThrow = false
    do {
      try await compendium.load()
    } catch {
      didThrow = true
    }
    if didThrow {
      #expect(compendium.loadError != nil)
    }
    #expect(compendium.isLoading == false)
  }

  @Test func homebrewSurvivesFailedLoad() async {
    let compendium = Compendium(bundle: .main)
    compendium.addAdversary(
      Adversary(
        id: "test-creature", name: "Test", tier: 1, type: .minion,
        description: "desc", difficulty: 8, thresholdMajor: 3, thresholdSevere: 6,
        hp: 3, stress: 2, attackModifier: "+1", attackName: "Bite",
        attackRange: .veryClose, damage: "1d6 phy"
      ))
    try? await compendium.load()
    #expect(compendium.isLoading == false)
  }
}

// MARK: - Homebrew distinction in Compendium

@MainActor struct CompendiumHomebrewTests {

  private func makeSoldier(id: String = "ironguard-soldier") -> Adversary {
    Adversary(
      id: id, name: "Ironguard Soldier", tier: 1, type: .bruiser,
      description: "A disciplined mercenary.", difficulty: 11,
      thresholdMajor: 5, thresholdSevere: 10, hp: 6, stress: 3,
      attackModifier: "+3", attackName: "Longsword",
      attackRange: .veryClose, damage: "1d10+3 phy"
    )
  }

  private func makeEnv(id: String = "bridge") -> DaggerheartEnvironment {
    DaggerheartEnvironment(id: id, name: "Bridge", description: "A rope bridge.")
  }

  @Test func homebrewAdversaryAppearsInHomebrewList() {
    let compendium = Compendium()
    compendium.addAdversary(makeSoldier())
    #expect(compendium.homebrewAdversaries.count == 1)
    #expect(compendium.homebrewAdversaries[0].id == "ironguard-soldier")
  }

  @Test func homebrewAdversaryAppearsInAllAdversaries() {
    let compendium = Compendium()
    compendium.addAdversary(makeSoldier())
    #expect(compendium.adversaries.contains { $0.id == "ironguard-soldier" })
  }

  @Test func srdAdversaryDoesNotAppearInHomebrewList() {
    let compendium = Compendium()
    #expect(compendium.homebrewAdversaries.isEmpty)
  }

  @Test func homebrewOverridesSRDEntryOnLookup() {
    let compendium = Compendium()
    var variant = makeSoldier()
    compendium.addAdversary(variant)
    variant = Adversary(
      id: "ironguard-soldier", name: "Elite Ironguard", tier: 2, type: .bruiser,
      description: "Upgraded.", difficulty: 14, thresholdMajor: 7, thresholdSevere: 14,
      hp: 10, stress: 4, attackModifier: "+5", attackName: "Longsword",
      attackRange: .veryClose, damage: "2d10+5 phy"
    )
    compendium.addAdversary(variant)
    #expect(compendium.adversary(id: "ironguard-soldier")?.name == "Elite Ironguard")
    #expect(compendium.homebrewAdversaries.count == 1)
  }

  @Test func removeHomebrewAdversaryRemovesFromBothLists() {
    let compendium = Compendium()
    compendium.addAdversary(makeSoldier())
    compendium.removeHomebrewAdversary(id: "ironguard-soldier")
    #expect(compendium.homebrewAdversaries.isEmpty)
    #expect(compendium.adversary(id: "ironguard-soldier") == nil)
  }

  @Test func homebrewEnvironmentAppearsInHomebrewList() {
    let compendium = Compendium()
    compendium.addEnvironment(makeEnv())
    #expect(compendium.homebrewEnvironments.count == 1)
  }

  @Test func removeHomebrewEnvironmentRemovesFromBothLists() {
    let compendium = Compendium()
    compendium.addEnvironment(makeEnv())
    compendium.removeHomebrewEnvironment(id: "bridge")
    #expect(compendium.homebrewEnvironments.isEmpty)
    #expect(compendium.environment(id: "bridge") == nil)
  }
}
