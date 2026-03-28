//
//  SRDDecodeTests.swift
//  DaggerheartModelsTests
//
//  Loads the bundled SRD JSON from the test target's Fixtures directory
//  and verifies that every entry decodes without error.
//
//  The JSON files are declared as test resources in Package.swift so that
//  Bundle.module resolves them correctly on all platforms including Linux.
//

import Foundation
import Testing

@testable import DHModels

struct SRDDecodeTests {

  private static func url(forResource name: String) throws -> URL {
    try #require(
      Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
  }

  @Test func allSRDAdversariesDecodeWithoutError() throws {
    let url = try Self.url(forResource: "adversaries")
    let data = try Data(contentsOf: url)
    let adversaries = try JSONDecoder().decode([Adversary].self, from: data)
    #expect(adversaries.isEmpty == false)
    for adversary in adversaries {
      #expect(!adversary.name.isEmpty, "Adversary id=\(adversary.id) has empty name")
      #expect(
        (1...4).contains(adversary.tier),
        "Adversary \(adversary.name) has unexpected tier \(adversary.tier)")
    }
  }

  @Test func allSRDEnvironmentsDecodeWithoutError() throws {
    let url = try Self.url(forResource: "environments")
    let data = try Data(contentsOf: url)
    let environments = try JSONDecoder().decode([DaggerheartEnvironment].self, from: data)
    #expect(environments.isEmpty == false)
    for environment in environments {
      #expect(!environment.name.isEmpty, "Environment id=\(environment.id) has empty name")
    }
  }

  @Test func srdAdversaryCountMatchesExpected() throws {
    let url = try Self.url(forResource: "adversaries")
    let data = try Data(contentsOf: url)
    let adversaries = try JSONDecoder().decode([Adversary].self, from: data)
    #expect(adversaries.count == 129)
  }

  @Test func srdEnvironmentCountMatchesExpected() throws {
    let url = try Self.url(forResource: "environments")
    let data = try Data(contentsOf: url)
    let environments = try JSONDecoder().decode([DaggerheartEnvironment].self, from: data)
    #expect(environments.count == 19)
  }

  @Test func srdAdversaryIDsAreUnique() throws {
    let url = try Self.url(forResource: "adversaries")
    let data = try Data(contentsOf: url)
    let adversaries = try JSONDecoder().decode([Adversary].self, from: data)
    let ids = adversaries.map(\.id)
    let unique = Set(ids)
    #expect(
      unique.count == ids.count,
      "Duplicate adversary IDs found: \(ids.count - unique.count) duplicates")
  }

  @Test func srdAdversariesHaveNonEmptyFeatureText() throws {
    let url = try Self.url(forResource: "adversaries")
    let data = try Data(contentsOf: url)
    let adversaries = try JSONDecoder().decode([Adversary].self, from: data)
    for adversary in adversaries {
      for feature in adversary.features {
        #expect(!feature.name.isEmpty, "\(adversary.name) has a feature with empty name")
        #expect(!feature.text.isEmpty, "\(adversary.name) feature '\(feature.name)' has empty text")
      }
    }
  }
}
