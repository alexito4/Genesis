//
// String-AbsoluteLinks.swift
// Ignite
// https://www.github.com/twostraws/Ignite
// See LICENSE for license information.
//

import Foundation

public extension String {
    /// Converts links and image sources from relative links to absolute.
    /// - Parameter url: The base URL, which is usually your web domain.
    /// - Returns: The adjusted string, where all relative links are absolute.
    func makingAbsoluteLinks(
        relativeTo url: URL,
        root: URL
    ) -> String {
        var absolute = self
        
        // Fix images.
        absolute.replace(#/src="(?!http)(?!\/)/#, with: #"src="\#(url)/"#)

//        absolute.replace(#/src="(?!http)(?!\/)/#) { match in
//            let fullURL = url.appending(path: match.output.path).absoluteString
//            return "src=\"\(fullURL)"
//        }

        // Fix links.
        // Replace links that are full relative (without /)
        absolute.replace(#/href="(?!http)(?!\/)/#, with: #"href="\#(url)/"#)
        // Replace links that are root relative (with /)
        absolute.replace(#/href="(?!http)(\/)/#, with: #"href="\#(root)/"#)
        
//        absolute.replace(#/href="(?<path>\/[^"]+)/#) { match in
//            let fullURL = url.appending(path: match.output.path).absoluteString
//            return "href=\"\(fullURL)"
//        }

        return absolute
    }
}
