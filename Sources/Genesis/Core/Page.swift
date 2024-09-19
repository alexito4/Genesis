
/// A single `Page` in the site.
public protocol Page: Sendable {
    /// From the output folder. Like /blog/today
    var path: String { get }
    /// Name for the file to put in the path. Like "index.html", the default
    var fileName: String { get }
    
    var priority: SitemapPriority { get }
    
    func render(context: Context) async throws -> String
}

public extension Page {
    /// The default file name, can be customized for sitemaps or feeds.
    var fileName: String { "index.html" }
    
    /// The default site map priority of all pages
    var priority: SitemapPriority { .default }
}

/// A provider that reads content from the `Context` to create pages.
public protocol PageProvider {
    func source(context: Context) async throws -> [any Page]
}
