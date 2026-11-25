# SwiftRichTextEditor

**English** | [日本語](README.ja.md)

A rich text editor for SwiftUI that aims to be the default choice: drop it in
with one line, and customize it the way you customize any other SwiftUI view.

> [!WARNING]
> **Status: early development.** Nothing here is usable yet. The API shown
> below is a design target, not a description of working code. Star or watch
> the repository to follow progress.

## Why

SwiftUI's built-in `TextEditor` covers character-level styling on recent OS
versions, but a real editor needs more than bold and italic. Apps that need
lists, links, attachments, or a document format they can store and exchange
still end up wrapping UIKit and AppKit themselves.

SwiftRichTextEditor fills that gap.

## Goals

- **One-line adoption.** A working editor with a sensible toolbar from a
  single view, with no UIKit or AppKit knowledge required.
- **SwiftUI-native customization.** Styles, toolbars, and behaviors are
  configured through view modifiers and the environment.
- **Block-level editing.** Headings, lists, and quotes, in addition to inline
  styles such as bold, italic, underline, and links.
- **A UI-independent document model.** The model is testable without a view,
  and converts to and from `AttributedString`, Markdown, and HTML.
- **Correct input handling for every language.** Composition-based input
  methods (Japanese, Chinese, Korean) are a first-class requirement, not an
  afterthought.
- **Accessibility.** VoiceOver and Dynamic Type work out of the box.

## Non-goals

- A code editor. Syntax highlighting and language tooling are out of scope.
- A WYSIWYG web editor. The editor is native and does not embed a web view.
- Real-time collaborative editing.

## Planned usage

This is the API the project is working toward. It is not implemented yet and
will change.

```swift
import SwiftUI
import SwiftRichTextEditor

struct NoteView: View {
    @State private var document = RichTextDocument()

    var body: some View {
        RichTextEditor(document: $document)
    }
}
```

## Requirements

- iOS 17+ / macOS 14+
- Swift 6.4+

## Installation

Add the package with Swift Package Manager once the first version is tagged:

```swift
dependencies: [
    .package(url: "https://github.com/Ryota-Kurokawa/swift-rich-text-editor.git", from: "0.1.0"),
]
```

No version has been released yet.

## Roadmap

1. **Technical validation** — choose the editing engine, and prove selection
   syncing and composition-based input in a prototype.
2. **MVP** — bold, italic, underline, lists, links, a default toolbar, and a
   sample app.
3. **0.1.0** — first tagged release, with DocC documentation.
4. **Later** — attachments, mentions, Markdown and HTML conversion.

## Contributing

The design is still being settled, so pull requests are premature. Issues
with use cases, requirements, and pain points from existing editors are very
welcome and will shape the design.

## License

MIT. See [LICENSE](LICENSE).
