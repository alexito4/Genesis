import Foundation

public extension URL {
    var fileCreationDate: Date {
        let fromFile = try? resourceValues(forKeys: [.creationDateKey]).creationDate
        return fromFile ?? .now
    }
}
