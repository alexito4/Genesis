//
// Location.swift
// Ignite
// https://www.github.com/twostraws/Ignite
// See LICENSE for license information.
//

import Foundation

/// A location that can be written into our sitemap.
public struct Location: Sendable {
    public var path: String
    public var priority: Double
}

extension Array where Element == Location {
    /// An extension that lets us determine whether one path is contained inside
    /// An array of `Location` objects.
    func contains(_ path: String) -> Bool {
        self.contains {
            $0.path == path
        }
    }
}
