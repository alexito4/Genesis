
/// A type that loads content to be added into the `Context` so later `Pages` can work with it.
public protocol ContentLoader {
    func load(context: Context) async throws -> sending [any Content]
}

/// A single piece of content loaded. For example, a post.
public protocol Content {
    /// This content path relative to the base URL.
    /// a.k.a. the path in the output folder.
    var path: String { get }
}

public extension Content {
    /// Get the full URL to this content. Useful for creating feed XML that includes
    /// this content.
    func path(in site: any Site) -> String {
        site.url.appending(path: path).absoluteString
    }
}
