import Foundation
import Markdown

public struct ParsedMarkdown: Sendable {
    public enum Error: Swift.Error {
        case unopenableFile(String)
        case badMarkdown(URL)
    }

    /// A dictionary of metadata specified at the top of the file as YAML front matter.
    /// See https://jekyllrb.com/docs/front-matter/ for information.
    public var frontMatter = [String: String]()

    /// The title of this document.
    public var title: String

    /// The description of this document, which is the first paragraph.
    public var description: String

    /// The body text of this file, which includes its title by default.
    public var body: String

    public var tags: [String] {
        guard let tagsString = frontMatter["tags"] else {
            return []
        }
        return tagsString.split(separator: "','").map(String.init)
    }

    /// Original Markdown document tree. Can be manipulated at any stage to recreate the body.
    public nonisolated(unsafe) let document: Document

    /// Parses Markdown provided from a filesystem URL.
    /// - Parameters:
    ///   - url: The filesystem URL to load.
    public init(
        parsing fileURL: URL
    ) throws(Error) {
        var markdown: String
        do {
            markdown = try String(contentsOf: fileURL)
        } catch {
            throw .unopenableFile(error.localizedDescription)
        }
        frontMatter = Self.processMetadata(for: &markdown)
        document = Document(parsing: markdown)
        let visitor = MarkdownToHTML(document: document, firstHeadingBehaviour: .removeIfNoExistingTitle(existingTitle: frontMatter["title"]))
        title = frontMatter["title"] ?? visitor.title
        description = visitor.description
        body = visitor.body
    }

    /// Looks for and parses any YAML front matter from this Markdown.
    /// - Parameter markdown: The Markdown string to process. The remaining Markdown, once front matter has been removed.
    /// - Returns: The front-matter
    private static func processMetadata(for markdown: inout String) -> [String: String] {
        var frontMatter = [String: String]()
        if markdown.starts(with: "---") {
            let parts = markdown.split(separator: "---", maxSplits: 1, omittingEmptySubsequences: true)

            let header = parts[0].split(separator: "\n", omittingEmptySubsequences: true)

            for entry in header {
                let entryParts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                guard entryParts.count == 2 else { continue }

                let key = entryParts[0].trimmingCharacters(in: .whitespaces)
                var value = entryParts[1].trimmingCharacters(in: .whitespaces)

                if key == "tags" {
//                    print(key, value)

//                    let prevValue = value
                    // Poor way of supporting tag arrays
                    value = value.replacingOccurrences(of: "['", with: "")
                        .replacingOccurrences(of: "']", with: "")
                        // keep ',' to split them later
                        .replacingOccurrences(of: "', '", with: "','")
//                        .replacingOccurrences(of: "','", with: ", ")
//                        .replacingOccurrences(of: "'", with: "")

//                    print(">>\(prevValue)<<>>\(value)<<")
                }

                frontMatter[key] = value
            }

            markdown = String(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return frontMatter
    }
}

/// Controls how the first heading in a Markdown document is handled during rendering.
public enum FirstHeadingBehaviour {
    /// All headings are rendered into the body as normal.
    case nothing
    /// If `existingTitle` is nil or empty, the first heading is captured as the document
    /// title and stripped from the rendered body. If an existing title is provided,
    /// the heading is left in the body untouched.
    case removeIfNoExistingTitle(existingTitle: String?)
}

/// A simple Markdown to HTML parser powered by Apple's swift-markdown.
public struct MarkdownToHTML: MarkupVisitor {
    /// The title of this document.
    public var title = ""

    /// The description of this document, which is the first paragraph.
    public var description = ""

    /// The body text of this file, which includes its title by default.
    public var body = ""

    /// How to handle the first heading found in the document.
    public var firstHeadingBehaviour: FirstHeadingBehaviour

    /// Parses Markdown provided as a direct input string.
    /// - Parameters:
    ///   - document: The parsed Markdown document tree to render.
    ///   - firstHeadingBehaviour: Controls whether the first heading is captured as the
    ///     document title and removed from the body. Use `.removeIfNoExistingTitle` when
    ///     the document may define its title via a heading rather than front matter, and
    ///     pass the front matter title (if any) so the heading is preserved when one exists.
    public init(
        document: Document,
        firstHeadingBehaviour: FirstHeadingBehaviour = .nothing
    ) {
        self.firstHeadingBehaviour = firstHeadingBehaviour
        if case .removeIfNoExistingTitle(let existingTitle) = firstHeadingBehaviour {
            self.title = existingTitle ?? ""
        }
        body = visit(document)
    }

    /// Visit some markup when no other handler is suitable.
    /// - Parameter markup: The markup that is being processed.
    /// - Returns: A string to append to the output.
    public mutating func defaultVisit(_ markup: Markdown.Markup) -> String {
        var result = ""

        for child in markup.children {
            result += visit(child)
        }

        return result
    }

    /// Processes block quote markup.
    /// Supports Obsidian callout format: if the blockquote's first line starts with
    /// a recognised `[!TYPE]` tag, it is rendered as a specialised element instead
    /// of a plain `<blockquote>`.
    ///
    /// Supported types:
    /// - `[!NOTE]`, `[!NOTE]-`, `[!NOTE]+` — collapsible `<details>`/`<summary>`.
    ///   `-` collapses by default, `+` expands by default, no suffix collapses by default.
    /// - `[!PROMO]` — styled promotion box rendered as a `<div class="callout-promo">`.
    /// - `[!TIP]` — subtle hint box rendered as a `<div class="callout-tip">`.
    ///   Optional inline title on the first line; body is all remaining paragraphs.
    ///
    /// All other blockquotes fall through to standard `<blockquote>` rendering.
    /// - Parameter blockQuote: The block quote data to process.
    /// - Returns: A HTML element with the block quote's children inside.
    public mutating func visitBlockQuote(_ blockQuote: Markdown.BlockQuote) -> String {
        if let callout = tryRenderCallout(blockQuote) {
            return callout
        }
        var result = "<blockquote>"
        for child in blockQuote.children {
            result += visit(child)
        }
        result += "</blockquote>"
        return result
    }

    private mutating func tryRenderCallout(_ blockQuote: Markdown.BlockQuote) -> String? {
        let children = Array(blockQuote.children)
        guard let firstParagraph = children.first as? Markdown.Paragraph else { return nil }
        let inlines = Array(firstParagraph.children)
        guard let firstText = inlines.first as? Markdown.Text else { return nil }

        let raw = firstText.plainText

        if raw.hasPrefix("[!NOTE]") {
            return renderNoteCallout(raw: raw, inlines: inlines, children: children)
        } else if raw.hasPrefix("[!PROMO]") {
            return renderPromoCallout(raw: raw, inlines: inlines, children: children)
        } else if raw.hasPrefix("[!TIP]") {
            return renderTipCallout(raw: raw, inlines: inlines, children: children)
        }

        return nil
    }

    private mutating func renderNoteCallout(raw: String, inlines: [any Markup], children: [any Markup]) -> String {
        let rest = String(raw.dropFirst("[!NOTE]".count))
        let openAttr: String
        let titlePrefix: String

        if rest.hasPrefix("-") {
            openAttr = ""
            titlePrefix = String(rest.dropFirst().drop(while: { $0.isWhitespace }))
        } else if rest.hasPrefix("+") {
            openAttr = " open"
            titlePrefix = String(rest.dropFirst().drop(while: { $0.isWhitespace }))
        } else {
            openAttr = ""
            titlePrefix = String(rest.drop(while: { $0.isWhitespace }))
        }

        var titleHTML = titlePrefix.poorHtmlEncoded()
        for inline in inlines.dropFirst() {
            titleHTML += visit(inline)
        }

        var bodyHTML = ""
        for child in children.dropFirst() {
            bodyHTML += visit(child)
        }

        return "<details\(openAttr)><summary>\(titleHTML)</summary>\(bodyHTML)</details>"
    }

    private mutating func renderPromoCallout(raw: String, inlines: [any Markup], children: [any Markup]) -> String {
        let rest = String(raw.dropFirst("[!PROMO]".count))
        let titlePrefix = String(rest.drop(while: { $0.isWhitespace }))

        var titleHTML = titlePrefix.poorHtmlEncoded()
        for inline in inlines.dropFirst() {
            titleHTML += visit(inline)
        }

        var bodyHTML = ""
        for child in children.dropFirst() {
            bodyHTML += visit(child)
        }

        return #"<div class="callout-promo"><p class="callout-promo-label">\#(titleHTML)</p><div class="callout-promo-body">\#(bodyHTML)</div></div>"#
    }

    private mutating func renderTipCallout(raw: String, inlines: [any Markup], children: [any Markup]) -> String {
        let rest = String(raw.dropFirst("[!TIP]".count))
        let titlePrefix = String(rest.drop(while: { $0.isWhitespace }))

        var bodyHTML = ""
        if !titlePrefix.isEmpty || inlines.count > 1 {
            var firstParaHTML = titlePrefix.poorHtmlEncoded()
            for inline in inlines.dropFirst() {
                firstParaHTML += visit(inline)
            }
            bodyHTML += "<p>\(firstParaHTML)</p>"
        }
        for child in children.dropFirst() {
            bodyHTML += visit(child)
        }

        return #"<div class="callout-tip">\#(bodyHTML)</div>"#
    }

    /// Processes code block markup.
    /// - Parameter codeBlock: The code block to process.
    /// - Returns: A HTML <pre> element with <code> inside, marked with
    /// CSS to remember which language was used.
    public func visitCodeBlock(_ codeBlock: Markdown.CodeBlock) -> String {
        let escapedCode = codeBlock.code.poorHtmlEncoded()
        return if let language = codeBlock.language {
            #"<pre><code class="language-\#(language.lowercased())">\#(escapedCode)</code></pre>"#
        } else {
            #"<pre><code>\#(escapedCode)</code></pre>"#
        }
    }

    /// Processes emphasis markup.
    /// - Parameter emphasis: The emphasized content to process.
    /// - Returns: A HTML <em> element with the markup's children inside.
    public mutating func visitEmphasis(_ emphasis: Markdown.Emphasis) -> String {
        var result = "<em>"

        for child in emphasis.children {
            result += visit(child)
        }

        result.append("</em>")
        return result
    }

    /// Processes heading markup.
    /// - Parameter heading: The heading to process.
    /// - Returns: A HTML <h*> element with its children inside. The exact
    /// heading level depends on the markup. If this is our first heading, we use it
    /// for the document title.
    public mutating func visitHeading(_ heading: Markdown.Heading) -> String {
        var headingContent = ""

        for child in heading.children {
            headingContent += visit(child)
        }

        // If we have no title yet and are asked to capture one from headings, do so now.
        if case .removeIfNoExistingTitle = firstHeadingBehaviour, title.isEmpty {
            title = headingContent
            return ""
        }

        // Create a header identifier so content can link with #id
        let id = headingContent
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        return #"<h\#(heading.level) id="\#(id)">\#(headingContent)</h\#(heading.level)>"#
    }

    /// Processes a block of HTML markup.
    /// - Parameter html: The HTML to process.
    /// - Returns: The raw HTML as-is.
    public func visitHTMLBlock(_ html: Markdown.HTMLBlock) -> String {
        html.rawHTML
    }

    /// Process image markup.
    /// - Parameter image: The image markup to process.
    /// - Returns: A HTML <img> tag with its source set correctly. This also
    /// appends Bootstrap's `img-fluid` CSS class so that images resize.
    public func visitImage(_ image: Markdown.Image) -> String {
        if let source = image.source {
            let title = image.plainText
            return #"<img src="\#(source)" alt="\#(title)">"#
        } else {
            return ""
        }
    }

    /// Process inline code markup.
    /// - Parameter inlineCode: The inline code markup to process.
    /// - Returns: A HTML <code> tag containing the code.
    public mutating func visitInlineCode(_ inlineCode: Markdown.InlineCode) -> String {
        "<code>\(inlineCode.code)</code>"
    }

    /// Processes a chunk of inline HTML markup.
    /// - Parameter inlineHTML: The HTML markup to process.
    /// - Returns: The raw HTML as-is.
    public func visitInlineHTML(_ inlineHTML: Markdown.InlineHTML) -> String {
        inlineHTML.rawHTML
    }

    /// Processes hyperlink markup.
    /// - Parameter link: The link markup to process.
    /// - Returns: Returns a HTML <a> tag with the correct location and content.
    public mutating func visitLink(_ link: Markdown.Link) -> String {
        var result = #"<a href="\#(link.destination ?? "#")">"#

        for child in link.children {
            result += visit(child)
        }

        result += "</a>"
        return result
    }

    /// Processes one item from a list.
    /// - Parameter listItem: The list item markup to process.
    /// - Returns: A HTML <li> tag containing the list item's contents.
    public mutating func visitListItem(_ listItem: Markdown.ListItem) -> String {
        var result = "<li>"

        for child in listItem.children {
            result += visit(child)
        }

        result += "</li>"
        return result
    }

    /// Processes unordered list markup.
    /// - Parameter orderedList: The unordered list markup to process.
    /// - Returns: A HTML <ol> element with the correct contents.
    public mutating func visitOrderedList(_ orderedList: Markdown.OrderedList) -> String {
        var result = "<ol>"

        for listItem in orderedList.listItems {
            result += visit(listItem)
        }

        result += "</ol>"
        return result
    }

    /// Processes a paragraph of text.
    /// - Parameter paragraph: The paragraph markup to process.
    /// - Returns: If we're inside a list this sends back the paragraph's
    /// contents directly. Otherwise, it wraps the contents in a HTML <p> element.
    /// If this is the first paragraph of text in the document we use it for the
    /// description of this document.
    public mutating func visitParagraph(_ paragraph: Markdown.Paragraph) -> String {
        var result = ""
        var paragraphContents = ""

        if paragraph.isInsideList == false {
            result += "<p>"
        }

        for child in paragraph.children {
            paragraphContents += visit(child)
        }

        result += paragraphContents

        if description.isEmpty {
            description = paragraphContents
        }

        if paragraph.isInsideList == false {
            result += "</p>"
        }

        return result
    }

    /// Processes some strikethrough markup.
    /// - Parameter strikethrough: The strikethrough markup to process.
    /// - Returns: Content wrapped inside a HTML <s> element.
    public mutating func visitStrikethrough(_ strikethrough: Markdown.Strikethrough) -> String {
        var result = "<s>"

        for child in strikethrough.children {
            result += visit(child)
        }

        result += "</s>"

        return result
    }

    /// Processes some strong markup.
    /// - Parameter strong: The strong markup to process.
    /// - Returns: Content wrapped inside a HTML <strong> element.
    public mutating func visitStrong(_ strong: Markdown.Strong) -> String {
        var result = "<strong>"

        for child in strong.children {
            result += visit(child)
        }

        result += "</strong>"
        return result
    }

    /// Processes table markup.
    /// - Parameter table: The table markup to process.
    /// - Returns: A HTML <table> element, optionally with <thead> and
    /// <tbody> if they are provided.
    public mutating func visitTable(_ table: Markdown.Table) -> String {
        var output = "<table>"

        if table.head.childCount > 0 {
            output += "<thead>"
            output += visit(table.head)
            output += "</thead>"
        }

        if table.body.childCount > 0 {
            output += "<tbody>"
            output += visit(table.body)
            output += "</tbody>"
        }

        output += "</table>"
        return output
    }

    /// Processes table head markup.
    /// - Parameter tableHead: The table head markup to process.
    /// - Returns: A string containing zero or more HTML <th> elements
    /// representing the headers in this table.
    public mutating func visitTableHead(_ tableHead: Markdown.Table.Head) -> String {
        var output = ""

        for child in tableHead.children {
            output += "<th>"
            output += visit(child)
            output += "</th>"
        }

        return output
    }

    /// Processes table row markup.
    /// - Parameter tableRow: The table head markup to process.
    /// - Returns: A string containing zero or more HTML <tr> elements
    /// representing the rows in this table, with each row containing zero or
    /// more <td> elements for each column processed.
    public mutating func visitTableRow(_ tableRow: Markdown.Table.Row) -> String {
        var output = "<tr>"

        for child in tableRow.children {
            output += "<td>"
            output += visit(child)
            output += "</td>"
        }

        output += "</tr>"
        return output
    }

    /// Processes plain text markup.
    /// - Parameter text: The plain text markup to process.
    /// - Returns: The same text that was read as input.
    public mutating func visitText(_ text: Markdown.Text) -> String {
        text.plainText
    }

    /// Process thematic break markup. This is written as --- in Markdown.
    /// - Parameter thematicBreak: The thematic break markup to process.
    /// - Returns: A HTML <hr> element.
    public func visitThematicBreak(_ thematicBreak: Markdown.ThematicBreak) -> String {
        "<hr />"
    }

    /// Processes ordered list markup.
    /// - Parameter orderedList: The ordered list markup to process.
    /// - Returns: A HTML <ul> element with the correct contents.
    public mutating func visitUnorderedList(_ unorderedList: Markdown.UnorderedList) -> String {
        var result = "<ul>"

        for listItem in unorderedList.listItems {
            result += visit(listItem)
        }

        result += "</ul>"
        return result
    }
}

extension Markup {
    /// A small helper that determines whether this markup or any parent is a list.
    var isInsideList: Bool {
        self is ListItemContainer || parent?.isInsideList == true
    }
}

extension String {
    func poorHtmlEncoded() -> String {
        replacingOccurrences(of: "&", with: "&amp;") // Ampersand (&)
            .replacingOccurrences(of: "<", with: "&lt;") // Less than (<)
            .replacingOccurrences(of: ">", with: "&gt;") // Greater than (>)
            .replacingOccurrences(of: "\"", with: "&quot;") // Double quotes (")
            .replacingOccurrences(of: "'", with: "&#39;") // Single quote (')
    }
}
