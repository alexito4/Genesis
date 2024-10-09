import Foundation

/// A location that can be written into our sitemap.
public struct Location: Sendable {
    public var path: String
    public var priority: Double
}

extension Array<Location> {
    /// An extension that lets us determine whether one path is contained inside
    /// An array of `Location` objects.
    func contains(_ path: String) -> Bool {
        contains {
            $0.path == path
        }
    }
}
