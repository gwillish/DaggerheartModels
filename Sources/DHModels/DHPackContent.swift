//
//  DHPackContent.swift
//  Encounter
//
//  Decoded representation of a .dhpack file.
//  A .dhpack is a JSON object with optional adversaries and environments arrays,
//  compatible with the seansbox/daggerheart-srd format (see ADR-0024).
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
import Foundation

#if canImport(UniformTypeIdentifiers)
  import UniformTypeIdentifiers

  // MARK: - UTType

  extension UTType {
    /// The `.dhpack` file type: a JSON content pack for Encounter.
    ///
    /// Declared in `Info.plist` as `gwillish.Encounter.dhpack`, conforming to
    /// `public.json → public.text → public.data`. The `public.json` conformance
    /// allows text editors and Quick Look to preview the file, and lets the OS
    /// route AirDrop and Files-app opens to Encounter (see ADR-0016).
    ///
    /// > Note: The UTI is *declared* here as a Swift constant; the OS-level
    /// > registration that enables file-open routing lives in the app's `Info.plist`
    /// > and cannot be moved into a Swift Package.
    ///
    /// Use `static let` (not `var`) because the type is exported by this app's
    /// bundle and is stable for the app's lifetime.
    public static let dhpack: UTType = UTType(
      exportedAs: "gwillish.Encounter.dhpack",
      conformingTo: .json)
  }
#endif

/// The decoded contents of a `.dhpack` file.
///
/// A pack may contain adversaries, environments, or both. Absent arrays decode
/// as empty rather than throwing, so partial packs are accepted.
///
/// ## Format
/// ```json
/// {
///   "adversaries": [ … ],
///   "environments": [ … ]
/// }
/// ```
/// A root-level array of adversaries (bare seansbox export format) is also
/// accepted and treated as a pack with environments omitted.
nonisolated public struct DHPackContent: Sendable {
  public let adversaries: [Adversary]
  public let environments: [DaggerheartEnvironment]

  public init(adversaries: [Adversary], environments: [DaggerheartEnvironment]) {
    self.adversaries = adversaries
    self.environments = environments
  }
}

nonisolated extension DHPackContent: Decodable {
  private enum CodingKeys: String, CodingKey {
    case adversaries, environments
  }

  public init(from decoder: Decoder) throws {
    // Try the keyed object format first {"adversaries":[…], "environments":[…]}.
    // Fall back to a bare adversary array (direct seansbox export).
    if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
      adversaries = (try? keyed.decode([Adversary].self, forKey: .adversaries)) ?? []
      environments = (try? keyed.decode([DaggerheartEnvironment].self, forKey: .environments)) ?? []
    } else {
      adversaries = try decoder.singleValueContainer().decode([Adversary].self)
      environments = []
    }
  }
}
