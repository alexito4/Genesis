# Genesis

A static site generator written in Swift. The engine behind [Alejandro M. P.](https://alejandromp.com).

Read more about it in [Back to the basics with Genesis](https://alejandromp.com/development/blog/back-to-the-basics-with-genesis).

## By me, for me

This generator is tailored to my needs. Although is flexible and capable to solve your problems, it's not designed for being simple to quick start but for being simple to maintain. If you are looking for something that holds your hands more I recommend other projects from the community like [Ignite](https://github.com/twostraws/Ignite), [Publish](https://github.com/JohnSundell/Publish), [Toucan](https://github.com/toucansites/toucan) or [others](https://github.com/topics/static-site-generator?l=swift).

## Features and non-features

- The Core framework gives you APIs to load content and generate pages.
  - Simple function calls. No fancy declarative rules or steps systems.
  - Procedural. Not declared as part of the site, you call the functions however you want.
  - No hardcoded content or behaviour. You won't suffer if you want to customize anything after the first five minutes of excitement.
    - You add the RSS, Sitemap, Robots...
- You define `ContentLoader`s to load dynamic `Content`
  - You define what the `Content` is and can have as many types as you want
  - You can load the content however you want (from file, a DB, a CMS...)
  - Use any Markdown parser
    - `GenesisMarkdown` is a separate module that uses [apple/swift-markdown](apple/swift-markdown)
    - This allows you to keep the Markdown tree as part of your content until the last moment you want to generate the HTML, so various parts of the generation can inspect and even manipulate the tree.
  - And if you don't want this loader functionality, you can just create the pages directly.
- You can just give static single Page instances to the generator
  - Ideal for single pages like Home, About...
  - `Page` has access to the `Context`, so you in exactly the same way you can make Index pages trivially
- You can use `PageProvider` to instantiate dynamically other pages
  - This let's you instantiate every instance from loaded content. Like blog posts.
- Pages are very flexible
  - Just require a path to know where the page goes in the final site. Nothing else.
  - In the page you must return the `String`, usually HTML, to be saved to disk
  - Everything else depends on what you want. They are just Swift types so you can keep any data you want, use async, or pass the data you need in the inits, useful with the `PageProvider`
  - No hardcoded theme
  - No hardcoded web dependencies (css frameworks, js, etc)
- HTML generation is just to output strings
  - No fancy DSL for typed Swift HTML hardcoded into the library
  - This gives full flexibility on how you want to generate HTML
  - Go basic and return inlined Swift interpolated HTML strings
  - Or use templates from HTML files
  - Or use any typed Swift HTML library

## Example

Check the [Example](https://github.com/alexito4/Genesis/tree/main/Example) to see how the API can be used.

