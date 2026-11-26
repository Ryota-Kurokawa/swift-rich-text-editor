#if os(iOS)
import Observation
import UIKit

/// Drives a `UITextView` for the technical-validation prototype.
///
/// This is not public API. It exists to test three hypotheses before the real
/// editor is designed:
///
/// 1. While editing, the text view's storage is the source of truth, and the
///    document is a snapshot written back from it.
/// 2. Nothing is pushed from the document into the text view while the input
///    method is composing (marked text exists).
/// 3. Formatting is sent to the text view as a command that edits attributes
///    in place, instead of replacing the document.
@MainActor
@Observable
public final class EditorController {
    // MARK: Observable state

    public private(set) var selectedRange = NSRange(location: 0, length: 0)
    /// The range of the text being composed by the input method, if any.
    public private(set) var markedRange: NSRange?
    public private(set) var isBoldActive = false
    public private(set) var isListActive = false

    public var isComposing: Bool { markedRange != nil }

    // MARK: Wiring

    @ObservationIgnored public private(set) weak var textView: UITextView?
    /// Called with an immutable snapshot whenever committed content changes.
    /// It is never called while the input method is composing.
    @ObservationIgnored public var onDocumentChange: ((NSAttributedString) -> Void)?
    @ObservationIgnored private var delegateProxy: DelegateProxy?

    public init() {}

    public static var baseFont: UIFont { .preferredFont(forTextStyle: .body) }

    private static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: UIColor.label]
    }

    public func attach(to textView: UITextView) {
        let proxy = DelegateProxy()
        proxy.controller = self
        delegateProxy = proxy
        textView.delegate = proxy
        textView.font = Self.baseFont
        textView.adjustsFontForContentSizeCategory = true
        textView.typingAttributes = Self.baseAttributes
        self.textView = textView
        refreshState()
    }

    // MARK: Document -> view

    /// Replaces the text view's content with `document`, keeping the caret
    /// where it was.
    ///
    /// Returns `false` without touching the text view while the input method
    /// is composing, because replacing the storage would cancel composition.
    @discardableResult
    public func replaceDocument(_ document: NSAttributedString) -> Bool {
        guard let textView else { return false }
        guard textView.markedTextRange == nil else { return false }
        guard !textView.textStorage.isEqual(to: document) else { return true }

        let selection = textView.selectedRange
        textView.attributedText = document
        if document.length == 0 {
            textView.typingAttributes = Self.baseAttributes
        }
        textView.selectedRange = clamped(selection, length: document.length)
        refreshState()
        return true
    }

    /// Moves the selection from outside the text view.
    ///
    /// Returns `false` while the input method is composing.
    @discardableResult
    public func select(_ range: NSRange) -> Bool {
        guard let textView, textView.markedTextRange == nil else { return false }
        textView.selectedRange = clamped(range, length: textView.textStorage.length)
        refreshState()
        return true
    }

    // MARK: Commands

    public func toggleBold() {
        guard let textView else { return }
        let enable = !isBold(in: textView)

        // While composing, the marked text is what the user is looking at, so
        // style all of it. This edits attributes only: the characters and the
        // selection stay untouched, which keeps the composition alive.
        let target = markedNSRange(in: textView) ?? textView.selectedRange
        if target.length > 0 {
            editAttributes(in: target, actionName: "Bold") { storage in
                storage.enumerateAttribute(.font, in: target) { value, range, _ in
                    let font = (value as? UIFont) ?? Self.baseFont
                    storage.addAttribute(.font, value: font.settingBold(enable), range: range)
                }
            }
        }

        var typing = textView.typingAttributes
        typing[.font] = ((typing[.font] as? UIFont) ?? Self.baseFont).settingBold(enable)
        textView.typingAttributes = typing
        didEdit()
    }

    public func toggleList() {
        guard let textView else { return }
        let string = textView.textStorage.string as NSString
        let paragraphs = string.paragraphRange(for: textView.selectedRange)
        let enable = !isList(at: textView.selectedRange.location, in: textView)
        setList(enable, in: paragraphs)
    }

    // MARK: Editing rules for lists

    /// Decides what Backspace does at the start of a list item.
    ///
    /// Returns `false` when the change was handled here and the text view must
    /// not apply it.
    ///
    /// Return is deliberately left to `UITextView`. On iOS 26 it continues the
    /// list on a non-empty item and leaves the list on an empty one by itself;
    /// `PrototypeTests` pins that behaviour so a different OS version shows up
    /// as a failing test.
    func shouldChangeText(in range: NSRange, replacementText text: String) -> Bool {
        guard let textView, textView.markedTextRange == nil else { return true }
        let caret = NSMaxRange(range)
        guard isList(at: caret, in: textView) else { return true }

        let string = textView.textStorage.string as NSString
        let paragraph = string.paragraphRange(for: NSRange(location: caret, length: 0))

        // Backspace at the start of an item removes the marker first, instead
        // of merging the item into the previous one as UITextView would.
        let isBackspace = text.isEmpty && range.length <= 1 && textView.selectedRange.length == 0
        if isBackspace, caret == paragraph.location {
            setList(false, in: paragraph)
            return false
        }
        return true
    }

    private func setList(_ enabled: Bool, in paragraphs: NSRange) {
        guard let textView else { return }
        // The empty paragraph at the end of the document has no characters to
        // carry a paragraph style, so it only lives in the typing attributes.
        if paragraphs.length > 0 {
            editAttributes(in: paragraphs, actionName: "List") { storage in
                storage.enumerateAttribute(.paragraphStyle, in: paragraphs) { value, range, _ in
                    let style = Self.paragraphStyle(from: value as? NSParagraphStyle, list: enabled)
                    storage.addAttribute(.paragraphStyle, value: style, range: range)
                }
            }
        }
        var typing = textView.typingAttributes
        typing[.paragraphStyle] = Self.paragraphStyle(
            from: typing[.paragraphStyle] as? NSParagraphStyle, list: enabled)
        textView.typingAttributes = typing
        didEdit()
    }

    private static func paragraphStyle(from style: NSParagraphStyle?, list: Bool) -> NSParagraphStyle {
        let result = (style?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        result.textLists = list ? [NSTextList(markerFormat: .disc, options: 0)] : []
        return result
    }

    // MARK: Attribute edits and undo

    private func editAttributes(in range: NSRange, actionName: String, _ edit: (NSTextStorage) -> Void) {
        guard let textView else { return }
        let storage = textView.textStorage
        let before = storage.attributedSubstring(from: range)
        storage.beginEditing()
        edit(storage)
        storage.endEditing()
        // The input method owns undo for the text it is composing.
        if textView.markedTextRange == nil {
            registerUndo(restoring: before, at: range, actionName: actionName)
        }
    }

    private func registerUndo(restoring attributes: NSAttributedString, at range: NSRange, actionName: String) {
        guard let undoManager = textView?.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { controller in
            MainActor.assumeIsolated {
                controller.restoreAttributes(attributes, at: range, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
    }

    private func restoreAttributes(_ attributes: NSAttributedString, at range: NSRange, actionName: String) {
        guard let textView, NSMaxRange(range) <= textView.textStorage.length else { return }
        let storage = textView.textStorage
        let current = storage.attributedSubstring(from: range)
        storage.beginEditing()
        attributes.enumerateAttributes(in: NSRange(location: 0, length: attributes.length)) { values, sub, _ in
            storage.setAttributes(values, range: NSRange(location: range.location + sub.location, length: sub.length))
        }
        storage.endEditing()
        registerUndo(restoring: current, at: range, actionName: actionName)
        didEdit()
    }

    // MARK: View -> document

    fileprivate func didEdit() {
        refreshState()
        guard let textView, textView.markedTextRange == nil else { return }
        onDocumentChange?(NSAttributedString(attributedString: textView.textStorage))
    }

    fileprivate func refreshState() {
        guard let textView else { return }
        // Assign only on change so observers are not invalidated needlessly.
        let selection = textView.selectedRange
        if selectedRange != selection { selectedRange = selection }
        let marked = markedNSRange(in: textView)
        if markedRange != marked { markedRange = marked }
        let bold = isBold(in: textView)
        if isBoldActive != bold { isBoldActive = bold }
        let list = isList(at: selection.location, in: textView)
        if isListActive != list { isListActive = list }
    }

    // MARK: Queries

    private func isBold(in textView: UITextView) -> Bool {
        let selection = textView.selectedRange
        guard selection.length > 0 else {
            return (textView.typingAttributes[.font] as? UIFont)?.isBold ?? false
        }
        var allBold = true
        textView.textStorage.enumerateAttribute(.font, in: selection) { value, _, stop in
            if (value as? UIFont)?.isBold != true {
                allBold = false
                stop.pointee = true
            }
        }
        return allBold
    }

    private func isList(at location: Int, in textView: UITextView) -> Bool {
        let storage = textView.textStorage
        let paragraph = (storage.string as NSString)
            .paragraphRange(for: NSRange(location: min(location, storage.length), length: 0))
        let style: NSParagraphStyle?
        if paragraph.length > 0 {
            style = storage.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
        } else {
            style = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        }
        return style?.textLists.isEmpty == false
    }

    private func markedNSRange(in textView: UITextView) -> NSRange? {
        guard let marked = textView.markedTextRange else { return nil }
        let location = textView.offset(from: textView.beginningOfDocument, to: marked.start)
        let length = textView.offset(from: marked.start, to: marked.end)
        return NSRange(location: location, length: length)
    }

    private func clamped(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(range.location, 0), length)
        return NSRange(location: location, length: min(range.length, length - location))
    }
}

private final class DelegateProxy: NSObject, UITextViewDelegate {
    weak var controller: EditorController?

    func textViewDidChange(_ textView: UITextView) {
        controller?.didEdit()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        controller?.refreshState()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        controller?.shouldChangeText(in: range, replacementText: text) ?? true
    }
}

extension UIFont {
    var isBold: Bool { fontDescriptor.symbolicTraits.contains(.traitBold) }

    func settingBold(_ bold: Bool) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        if bold { traits.insert(.traitBold) } else { traits.remove(.traitBold) }
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
#endif
