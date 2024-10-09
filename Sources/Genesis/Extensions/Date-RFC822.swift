import Foundation

public extension Date {
    /// Converts `Date` objects to RFC-822 format, which is used by RSS.
    var asRFC822: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.string(from: self)
    }
}
