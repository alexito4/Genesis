import Foundation

public extension Site {
    /// Retrieve a `Context` for this `Site`.
    func context(
        from file: StaticString = #filePath,
        buildDirectoryPath: String = "output"
    ) throws -> Context {
        try Context(
            for: self,
            from: file,
            buildDirectoryPath: buildDirectoryPath
        )
    }
}

public actor Context {
    /// The site that is currently being built.
    public nonisolated let site: any Site
    
    /// The root directory for the user's website package.
    private(set) public var rootDirectory: URL
    
    /// The directory containing their custom assets.
    private(set) public var assetsDirectory: URL
    
    /// The directory containing their Markdown files.
    private(set) public var contentDirectory: URL
    
    /// The directory containing includes to use with the `Include` element.
//    private(set) public var includesDirectory: URL
    
    /// The directory containing their final, built website.
    private(set) public var buildDirectory: URL
    
    /// Any warnings that have been issued during a build.
    private(set) var warnings = [String]()
    
    /// All the Markdown content this user has inside their Content folder.
    private(set) public var allContent = [any Content]()
    
    /// The sitemap for this site. Yes, using an array is less efficient when
    /// using `contains()`, but it allows us to list pages in a sensible order.
    /// (Technically speaking the order doesn't matter, but if the order changed
    /// randomly every time a build took place it would be annoying for source
    /// control!)
    private(set) public var siteMap = [Location]()
    
    /// Creates a new publishing context for a specific site, setting a root URL.
    /// - Parameters:
    ///   - site: The site we're currently publishing.
    ///   - rootURL: The URL of the root directory, where other key
    ///   folders are located.
    ///   - buildDirectoryPath: The path where the artifacts are generated.
    public init(
        for site: any Site,
        rootURL: URL,
        buildDirectoryPath: String
    ) throws {
        self.site = site
        
        self.rootDirectory = rootURL
        assetsDirectory = rootDirectory.appending(path: "Assets")
        contentDirectory = rootDirectory.appending(path: "Content")
//        includesDirectory = rootDirectory.appending(path: "Includes")
        buildDirectory = rootDirectory.appending(path: buildDirectoryPath)
    }
    
    /// Creates a new publishing context for a specific site, providing the path to
    /// one of the user's file. This then navigates upwards to find the root directory.
    /// - Parameters:
    ///   - site: The site we're currently publishing.
    ///   - file: One file from the user's package.
    ///   - buildDirectoryPath: The path where the artifacts are generated.
    ///   The default is "Build".
    init(for site: any Site, from file: StaticString, buildDirectoryPath: String) throws {
        let sourceBuildDirectories = try URL.selectDirectories(from: file)
        assert(sourceBuildDirectories.build == sourceBuildDirectories.source, "Detected Build and Source directories are not the same, so is this running as a Mac app? Fine, but was not expected.")
        try self.init(
            for: site,
            rootURL: sourceBuildDirectories.source,
            buildDirectoryPath: buildDirectoryPath
        )
    }
    
    public func reportWarning(
        _ warning: String
    ) {
        warnings.append(warning)
    }
}

/// API for each step of the generation
public extension Context {
    
    func loadContent(
        from loaders: sending [any ContentLoader]
    ) async throws {
        // TODO: this should be a concurrent map
        for loader in loaders {
            let loadedContent = try await loader.load(context: self)
            
            for content in loadedContent {
                if allContent.contains(where: { $0.path == content.path }) {
                    throw PublishingError.duplicateContentWithSamePath(content.path)
                }
                allContent.append(content)
            }
        }
    }
    
    func mutateContent<T: Content>(
        path: String,
        as: T.Type,
        mutate: (inout T) -> Void
    ) {
        guard let index = allContent.firstIndex(where: { $0.path == path }) else { return }
        var content = allContent[index] as! T
        mutate(&content)
        allContent[index] = content
    }
        
    /// Removes all content from the Build folder, so we're okay to recreate it.
    func clearBuildFolder() throws(PublishingError) {
        do {
            try FileManager.default.removeItem(at: buildDirectory)
        } catch {
            print("Could not remove buildDirectory (\(buildDirectory)), but it will be re-created anyway.")
        }

        do {
            try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
        } catch {
            throw .failedToCreateBuildDirectory(buildDirectory)
        }
    }
    
    /// Renders the pages to the output folder.
    func generateStaticPages(
        pages: sending [any Page]
    ) async throws {
        for page in pages {
            try await render(page)
        }
        
    }
        
    /// Runs the given `PageProvider`s and renders all `Page`s returned from them.
    /// Renders the pages to the output folder.
    func generateContentPages(
        providers: sending [any PageProvider]
    ) async throws {
        for provider in providers {
            let pages = try await provider.source(context: self)
            try await generateStaticPages(pages: pages)
        }
    }
    
    private func render(_ staticPage: any Page) async throws {
        let outputString = try await staticPage.render(context: self)

        let outputDirectory = buildDirectory.appending(path: staticPage.path)
        
        try write(
            outputString,
            to: outputDirectory,
            fileName: staticPage.fileName,
            priority: staticPage.priority
        )//isHomePage ? 1 : 0.9)
    }
    
    /// Writes a single string of data to a URL.
    /// - Parameters:
    ///   - string: The string to write.
    ///   - directory: The directory to write to. This has "index.html"
    ///   appended to it, so users are directed to the correct page immediately.
    ///   - priority: A priority value to control how important this content
    ///   is for the sitemap.
    private func write(
        _ string: String,
        to directory: URL,
        fileName: String,
        priority: SitemapPriority
    ) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw PublishingError.failedToCreateBuildDirectory(directory)
        }

        let outputURL = directory.appending(path: fileName)
        
        // Check the sitemap
        let siteMapPath = if fileName == "index.html" {
            directory.relative(to: buildDirectory)
        } else {
            outputURL.relative(to: buildDirectory)
        }
        if siteMap.contains(siteMapPath) {
            throw PublishingError.duplicateContentWithSamePath(siteMapPath)
        }
        
        do {
            try string.write(to: outputURL, atomically: true, encoding: .utf8)

            // Add to sitemap
            if priority != .hidden {
                siteMap.append(Location(path: siteMapPath, priority: priority.value))
            }
        } catch {
            throw PublishingError.failedToCreateBuildFile(outputURL)
        }
    }
    
    /// Copy the assets in the `assetsDirectory` to the `buildDirectory.
    func copyAssets() throws {
        let assets = try FileManager.default.contentsOfDirectory(
            at: assetsDirectory,
            includingPropertiesForKeys: nil
        )
        
        for asset in assets {
            try FileManager.default.copyItem(
                at: assetsDirectory.appending(path: asset.lastPathComponent),
                to: buildDirectory.appending(path: asset.lastPathComponent)
            )
        }
    }
    
    func checkWarnings() {
        if warnings.isEmpty == false {
            print("Publish completed with warnings:")
            print(warnings.map { "\t- \($0)" }.joined(separator: "\n"))
        }
    }
}

public enum SitemapPriority: Sendable {
    /// Priority of 1
    case highest
    /// Defaults to 0.5
    case `default`
    /// Priority of 0.4
    case low
    /// Indicates the location shouldn't be included in the sitemap
    case hidden
    
    var value: Double {
        switch self {
        case .highest:
            return 1
        case .default:
            return 0.5
        case .low:
            return 0.4
        case .hidden:
            return 0 // check if it's hidden before calling this property
        }
    }
}

/// API so pages can access the loaded content
public extension Context {
    func content<T: Content>(of type: T.Type) -> [T] {
        // could memoize?
        allContent.compactMap { $0 as? T }
    }
    
    // for when you want to filter to a protocol
    // it should inherit from Content protocol, but not sure how to pull it off with the type system right now since constrainint it means that you can't pass the protocol.sself since that doesn't conform to the protocol.
    func content<T>(of type: T.Type) -> [T] {
        return allContent.compactMap { $0 as? T }
    }
}
