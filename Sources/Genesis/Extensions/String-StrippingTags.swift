import Foundation

public extension String {
    /// Removes all HTML tags from a string, so it's safe to use as plain-text.
    func strippingTags() -> String {
        replacing(#/<.*?>/#, with: "")
    }
}
