//
//  Party.swift
//  DHModels
//
//  A named group of player characters.
//

import Foundation

#if canImport(FoundationEssentials)
  import FoundationEssentials
#endif

// MARK: - Party

/// A named group of player characters.
///
/// `Party` stores ordered player IDs only; resolving full ``Player`` objects
/// from those IDs is the store's responsibility. A player may belong to
/// multiple parties.
nonisolated public struct Party: Codable, Sendable, Equatable, Hashable, Identifiable {
  /// A stable identifier for this party.
  public let id: UUID
  /// The party's display name.
  public var name: String
  /// Ordered list of player IDs; order determines display order.
  public var playerIDs: [UUID]

  /// Creates a party.
  ///
  /// - Parameters:
  ///   - id: Stable identifier; defaults to a new UUID.
  ///   - name: The party's display name.
  ///   - playerIDs: Ordered list of player IDs. Order determines display order.
  public init(
    id: UUID = UUID(),
    name: String,
    playerIDs: [UUID] = []
  ) {
    self.id = id
    self.name = name
    self.playerIDs = playerIDs
  }
}
