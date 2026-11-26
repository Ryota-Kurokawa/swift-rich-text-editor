import SwiftRichTextEditor
import SwiftUI

/// One screen for trying the technical-validation prototype by hand.
///
/// The controls and the debug panel sit above the editor so the keyboard
/// never covers them.
struct ContentView: View {
    @State private var document = NSAttributedString(string: "")
    @State private var controller = EditorController()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            DebugPanel(document: document, controller: controller)
            Divider()
            PrototypeEditor(document: $document, controller: controller)
        }
    }

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Toggle(isOn: .init(get: { controller.isBoldActive }, set: { _ in controller.toggleBold() })) {
                    Label("Bold", systemImage: "bold")
                }
                .accessibilityIdentifier("bold")

                Toggle(isOn: .init(get: { controller.isListActive }, set: { _ in controller.toggleList() })) {
                    Label("List", systemImage: "list.bullet")
                }
                .accessibilityIdentifier("list")

                Divider().frame(height: 24)

                // SwiftUI -> text view: move the selection from outside.
                Button("Select start") {
                    controller.select(NSRange(location: 0, length: 0))
                }
                .accessibilityIdentifier("selectStart")

                // SwiftUI -> text view: replace the document through the binding.
                Button("Replace") {
                    document = NSAttributedString(
                        string: "Replaced from SwiftUI",
                        attributes: [.font: EditorController.baseFont, .foregroundColor: UIColor.label])
                }
                .accessibilityIdentifier("replace")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

private struct DebugPanel: View {
    let document: NSAttributedString
    let controller: EditorController

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row("selection", "\(controller.selectedRange.location), \(controller.selectedRange.length)")
            row("composing", controller.markedRange.map { "yes (\($0.location), \($0.length))" } ?? "no")
            row("document", "\(document.length) chars  \(visible(document.string))")
        }
        .font(.caption.monospaced())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .accessibilityIdentifier("debug")
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).foregroundStyle(.secondary).frame(width: 76, alignment: .leading)
            Text(value).lineLimit(2)
        }
    }

    /// Makes newlines and spaces visible, so stray characters can be spotted.
    private func visible(_ string: String) -> String {
        "\"" + string.replacingOccurrences(of: "\n", with: "⏎").replacingOccurrences(of: " ", with: "␣") + "\""
    }
}

#Preview {
    ContentView()
}
