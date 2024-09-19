import Foundation

public protocol Site: Sendable {
    /// The author of your site, which should be your name.
    /// Defaults to an empty string.
    var author: String { get }

    /// A string to append to the end of your page titles. For example, if you have
    /// a page titled "About Me" and a site title suffix of " – My Awesome Site", then
    /// your rendered page title will be "About Me – My Awesome Site".
    /// Defaults to an empty string.
//    var titleSuffix: String { get }

    /// The name of your site. Required.
    var name: String { get }

    /// An optional description for your site. Defaults to nil.
    var description: String? { get }

    /// The language your site is published in. Defaults to `.en`.
    var language: Language { get }

    /// The base URL for your site, e.g. https://www.example.com
    var url: URL { get }
}
