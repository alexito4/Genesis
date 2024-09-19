import Foundation
import Genesis

/// Conformance for Content Bundles, `
/// a.k.a content items that are not just a markdown file, but that also include resources in the same folder.
public protocol ContentWithResources: Content {
    var resourcesFolder: URL { get }
}

public extension Context {
    /// Copy the assets from each `ContentWithResources` to the output directory
    func copyContentResources() throws {
        let allContent = self.content(of: (any ContentWithResources).self)
        
        for content in allContent {
            let contentFolder = content.resourcesFolder
            
            let resources = try FileManager.default.contentsOfDirectory(at: contentFolder, includingPropertiesForKeys: nil)
                .filter { ![".DS_Store", "index.md"].contains($0.lastPathComponent) }
            
            let outputDirectory = buildDirectory.appending(path: content.path)

            for resource in resources {
                let destination = outputDirectory.appending(path: resource.lastPathComponent)
                try FileManager.default.copyItem(at: resource, to: destination)
            }
        }
    }
}
