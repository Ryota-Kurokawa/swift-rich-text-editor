#if os(iOS)
import SwiftUI
import UIKit

/// A SwiftUI wrapper around `UITextView` for the technical-validation
/// prototype. Not public API.
///
/// The binding is the shape the real editor aims for
/// (`RichTextEditor(document: $document)`). The wrapper proves that a binding
/// can coexist with a text view that owns the text while it is being edited.
public struct PrototypeEditor: UIViewRepresentable {
    @Binding private var document: NSAttributedString
    private let controller: EditorController

    public init(document: Binding<NSAttributedString>, controller: EditorController) {
        _document = document
        self.controller = controller
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: true)
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        controller.attach(to: textView)
        return textView
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        let binding = $document
        controller.onDocumentChange = { snapshot in
            // Remember what the view itself wrote, so the update that follows
            // is recognised as an echo and not pushed back into the view.
            coordinator.lastSynced = snapshot
            binding.wrappedValue = snapshot
        }

        // An identity check keeps the common path O(1).
        guard document !== coordinator.lastSynced else { return }
        if controller.replaceDocument(document) {
            coordinator.lastSynced = document
        }
    }

    public final class Coordinator {
        var lastSynced: NSAttributedString?
    }
}
#endif
