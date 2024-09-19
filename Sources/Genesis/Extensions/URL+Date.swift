import Foundation

public extension URL {
    var fileCreationDate: Date {
        let fromFile = try? self.resourceValues(forKeys: [.creationDateKey]).creationDate
        return fromFile ?? .now
    }
}
