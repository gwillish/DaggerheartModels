//
//  ContentModelTests.swift
//  DaggerheartModelsTests
//
//  Unit tests for ContentSource (backoff), ContentFingerprint (coding),
//  and DHPackContent (dual-format decoding).
//  All tested types are pure value types with no I/O dependencies.
//

import Foundation
import Testing

@testable import DaggerheartModels

// MARK: - ContentSource backoff

struct ContentSourceBackoffTests {

  private func makeSource() -> ContentSource {
    ContentSource(
      id: "test-source", name: "Test", url: URL(string: "https://example.com/pack.dhpack")!)
  }

  @Test func firstFailureIsOneHour() {
    let now = Date()
    let source = makeSource().recordingFailure(at: now)
    let expectedDelay: TimeInterval = 3_600  // 1h × 2^0
    let actual = source.nextAllowedFetch!.timeIntervalSince(now)
    #expect(abs(actual - expectedDelay) < 1)
    #expect(source.consecutiveFailures == 1)
  }

  @Test func secondFailureIsTwoHours() {
    let now = Date()
    let source = makeSource()
      .recordingFailure(at: now)
      .recordingFailure(at: now)
    let expectedDelay: TimeInterval = 7_200  // 1h × 2^1
    let actual = source.nextAllowedFetch!.timeIntervalSince(now)
    #expect(abs(actual - expectedDelay) < 1)
    #expect(source.consecutiveFailures == 2)
  }

  @Test func tenthFailureCapsAtSevenDays() {
    let now = Date()
    var source = makeSource()
    for _ in 0..<10 { source = source.recordingFailure(at: now) }
    let sevenDays: TimeInterval = 7 * 24 * 3_600
    let actual = source.nextAllowedFetch!.timeIntervalSince(now)
    #expect(abs(actual - sevenDays) < 1)
    #expect(source.consecutiveFailures == 10)
  }

  @Test func successResetsBackoff() {
    let now = Date()
    let fingerprint = ContentFingerprint(sha256: "abc123")
    let source = makeSource()
      .recordingFailure(at: now)
      .recordingFailure(at: now)
      .recordingSuccess(fingerprint: fingerprint, at: now)
    #expect(source.consecutiveFailures == 0)
    #expect(source.nextAllowedFetch == nil)
    #expect(source.lastFetched != nil)
    #expect(source.fingerprint == fingerprint)
  }

  @Test func isThrottledReturnsTrueWhileBackoffActive() {
    let now = Date()
    let source = makeSource().recordingFailure(at: now)
    #expect(source.isThrottled(at: now.addingTimeInterval(60)))  // 1 min later → still throttled
    #expect(!source.isThrottled(at: now.addingTimeInterval(4_000)))  // after 1h → clear
  }

  @Test func isThrottledFalseBeforeAnyFailure() {
    #expect(!makeSource().isThrottled())
  }

  @Test func localImportIsNeverThrottled() {
    let source = ContentSource(id: "imported", name: "Imported Pack")
    #expect(source.isLocalImport)
    #expect(!source.isThrottled())
    #expect(source.url == nil)
  }

  @Test func localImportHasLastFetchedSet() throws {
    let before = Date()
    let source = ContentSource(id: "imported", name: "Imported Pack")
    let after = Date()
    let fetched = try #require(source.lastFetched)
    #expect(fetched >= before && fetched <= after)
  }
}

// MARK: - ContentFingerprint coding

struct ContentFingerprintTests {

  @Test func roundTripWithEtag() throws {
    let original = ContentFingerprint(sha256: "deadbeef1234", etag: "\"v1.2.3\"")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ContentFingerprint.self, from: data)
    #expect(decoded == original)
  }

  @Test func roundTripWithoutEtag() throws {
    let original = ContentFingerprint(sha256: "abc123", etag: nil)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ContentFingerprint.self, from: data)
    #expect(decoded == original)
    #expect(decoded.etag == nil)
  }

  @Test func equalityIgnoresNilVsAbsentEtag() {
    let a = ContentFingerprint(sha256: "abc", etag: nil)
    let b = ContentFingerprint(sha256: "abc", etag: nil)
    #expect(a == b)
  }

  @Test func differentSha256IsNotEqual() {
    let a = ContentFingerprint(sha256: "aaa", etag: "v1")
    let b = ContentFingerprint(sha256: "bbb", etag: "v1")
    #expect(a != b)
  }
}

// MARK: - DHPackContent dual-format decoding

struct DHPackContentTests {

  private let adversaryJSON = """
    {
      "id": "cave-bat",
      "name": "Cave Bat",
      "tier": 1,
      "type": "Minion",
      "description": "A frantic bat.",
      "difficulty": 10,
      "thresholds": "None",
      "hp": 2,
      "stress": 1,
      "atk": "+1",
      "attack": "Bite",
      "range": "Melee",
      "damage": "1d4 phy"
    }
    """

  private let environmentJSON = """
    {
      "id": "dark-cave",
      "name": "Dark Cave",
      "description": "Pitch black.",
      "feature": []
    }
    """

  @Test func decodesKeyedObjectWithBoth() throws {
    let json = """
      {
        "adversaries": [\(adversaryJSON)],
        "environments": [\(environmentJSON)]
      }
      """.data(using: .utf8)!
    let pack = try JSONDecoder().decode(DHPackContent.self, from: json)
    #expect(pack.adversaries.count == 1)
    #expect(pack.adversaries[0].id == "cave-bat")
    #expect(pack.environments.count == 1)
    #expect(pack.environments[0].id == "dark-cave")
  }

  @Test func decodesKeyedObjectAdversariesOnly() throws {
    let json = """
      { "adversaries": [\(adversaryJSON)] }
      """.data(using: .utf8)!
    let pack = try JSONDecoder().decode(DHPackContent.self, from: json)
    #expect(pack.adversaries.count == 1)
    #expect(pack.environments.isEmpty)
  }

  @Test func decodesKeyedObjectEnvironmentsOnly() throws {
    let json = """
      { "environments": [\(environmentJSON)] }
      """.data(using: .utf8)!
    let pack = try JSONDecoder().decode(DHPackContent.self, from: json)
    #expect(pack.adversaries.isEmpty)
    #expect(pack.environments.count == 1)
  }

  @Test func decodesBareAdversaryArray() throws {
    let json = "[\(adversaryJSON)]".data(using: .utf8)!
    let pack = try JSONDecoder().decode(DHPackContent.self, from: json)
    #expect(pack.adversaries.count == 1)
    #expect(pack.adversaries[0].name == "Cave Bat")
    #expect(pack.environments.isEmpty)
  }

  @Test func emptyKeyedObjectProducesEmptyPack() throws {
    let json = "{}".data(using: .utf8)!
    let pack = try JSONDecoder().decode(DHPackContent.self, from: json)
    #expect(pack.adversaries.isEmpty)
    #expect(pack.environments.isEmpty)
  }

  @Test func adversarySourceNormalizedToLowercase() throws {
    let json = """
      { "adversaries": [
        {
          "name": "Test Beast",
          "source": "MyPack",
          "tier": 1, "type": "Bruiser", "description": "A beast.",
          "difficulty": 10, "thresholds": "5/10",
          "hp": 6, "stress": 2, "atk": "+2",
          "attack": "Claws", "range": "Melee", "damage": "1d8 phy"
        }
      ]}
      """.data(using: .utf8)!
    let pack = try JSONDecoder().decode(DHPackContent.self, from: json)
    #expect(pack.adversaries[0].source == "mypack")
  }
}
