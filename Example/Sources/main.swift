import Genesis
import GenesisMarkdown
import Foundation

// 1. Define a `Site`
struct ExampleSite: Site {
    var name = "Example"
    var description: String? = "An example site built with Genesis"
    var author = "Alejandro M. P."
    var url = URL(string: "127.0.0.1")!
    var language: Language = .english
}

// 2. Instantiate the site and take the context from it
let site = ExampleSite()
let context = try site.context()

// 3. And just call the functions you want. The Genesis Context is just here to help you, but you are in full control of how your site generation works.

// You might want to clear the build folder on every generation...
// or not? Maybe you want to skip the cleaning while drafting.
try await context.clearBuildFolder()

// You might want to copy all the assets from the default Asset folder into the final output
// Or you might have a more sophisticated asset pipeline that you prefer instead of this
//try await context.copyAssets()

// If your site has content defined by files like markdown blog posts, you can load that into the context.
// For that define a `ContentLoader` conforming type
struct BlogLoader: ContentLoader {
    // Implement a load function that returns the content
    func load(context: Context) async throws -> sending [any Content] {
        // Just load the files from the directory you keep them.
        // This let's you structure your site however you want.
        // In this example we just have posts in the Content folder directly
        let contentDirectory = await context.contentDirectory
        let contents: [URL] = try FileManager.default.contentsOfDirectory(
            at: contentDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        )
        return try contents
            // Perform any logic you want with your content. You may want to exclude some files, or posts based on some rules
            .filter { $0.lastPathComponent != ".DS_Store" }
            // Map to a specific type conforming to `Content`
            .map { fileURL in
                // GenesisMarkdown gives you the capability to load and parse markdown files
                // But it's just a thin wrapper on top of swift-markdown so feel free to write your own!
                // You can even use any other markdown library if you prefer.
                let markdown = try ParsedMarkdown(parsing: fileURL)
                
                // The only requirement for any Content is to specify the path in the website
                // Here we take it from the markdown file, but you can use your own strategy, like using
                // file dates, using the markdown front matter, etc.
                let path = fileURL
                    .relative(to: contentDirectory)
                
                // Genesis comes with some extra batteries, like a way to estimate the reading time.
                let readingTime = EstimatedReadingTime(for: markdown.body)
                
                return BlogPost(
                    // The only mandatory part of the Content is the path
                    path: path,
                    readingTime: readingTime,
                    // You control your own content type and loading, so for example you can keep the markdown AST in the content for later modification or analysis
                    markdown: markdown,
                    // or just store the parsed HTML string
                    htmlBody: markdown.body
                )
            }
    }
}
struct BlogPost: Content {
    var path: String
    var readingTime: EstimatedReadingTime
    var markdown: ParsedMarkdown
    var htmlBody: String
}
// Load content on the context so it can be retrieved by later steps
try await context.loadContent(from: [
    BlogLoader()
])

// Generate static single pages
// Implement any type that conforms to `Page`
struct HomePage: Page {
    // A Page, just like the Content, requires a path to know where it goes in the final output
    var path: String = ""
    
    // A page just has a render method that gives you the context and expects a String to save into a file.
    // That's it! You can implement this however you want.
    func render(context: Context) async throws -> String {
        // you could load pre-made HTML templates from the file system...
        // or use a Swift HTML DSL library...
        // or just use Swift string interpolation
        """
        <html>
        <body>
        <h1>Home page of your site</h1>
        <ul>
            \(await postsListItems(context: context))
        </ul>
        </body>
        </html>
        """
    }
    
    // Is all just normal Swift code, with very little enforced by Genesis.
    private func postsListItems(context: Context) async -> String {
        // You have access to the loaded content in the context, so you can list it in any page you want
        await context.content(of: BlogPost.self)
            .map {
                """
                <li><a href="\($0.path)">\($0.markdown.title)</a></li>
                """
            }
            .joined()
    }
}
// Use Genesis to generate the pages
try await context.generateStaticPages(pages: [
    HomePage()
])

// Other pages are not a single static page, but a templated page instantiated from a set of data
// We can create providers to create as many pages as needed dynamically
// For example we can make a `PageProvider` that create a `Page` for each loaded `BlogPost`
struct BlogPostProvider: PageProvider {
    func source(context: Genesis.Context) async throws -> [any Page] {
        // The context has a few helpers to find the content you want
        let blogPosts = await context.content(of: BlogPost.self)
        return blogPosts.map { BlogPostPage(path: $0.path, post: $0) }
    }
}
// Giving providers to the context so it calls each of them, and generates all the pages provided
try await context.generateContentPages(providers: [
    BlogPostProvider()
])
// A blog post page is just like any other page, but since a provider creates an instance for each content
// you can have properties that are specific for each instance of the content.
struct BlogPostPage: Page {
    var path: String
    
    // In this case we keep the blog post around so we can use it for rendering the page
    var post: BlogPost
    
    func render(context: Genesis.Context) async throws -> String {
        """
        <html>
        <body>
        <h1>\(post.markdown.title)</h1>
        \(post.htmlBody)
        </body>
        </html>
        """
    }
}

// In the end you can generate some standard extra pages.
// As you can see you can call multiple times the functions on the context, they are just here to help, not to enforce a structure
try await context.generateStaticPages(pages: [
//    NotFoundPage(),
//    SiteMap(),
//    Robots(site: site),
])

print("Site generated.")
