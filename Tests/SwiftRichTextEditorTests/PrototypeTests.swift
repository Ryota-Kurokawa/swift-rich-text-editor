#if os(iOS)
import Testing
import UIKit
@testable import SwiftRichTextEditor

/// Regression tests for the technical-validation prototype.
///
/// Composition is simulated with `setMarkedText` / `unmarkText` / `insertText`,
/// the same `UITextInput` calls the keyboard makes.
@MainActor
struct PrototypeTests {
    let controller = EditorController()
    let textView = UITextView(usingTextLayoutManager: true)

    init() {
        controller.attach(to: textView)
    }

    private func isBold(at index: Int) -> Bool {
        (textView.textStorage.attribute(.font, at: index, effectiveRange: nil) as? UIFont)?.isBold == true
    }

    private func isList(at index: Int) -> Bool {
        let style = textView.textStorage.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
        return style?.textLists.isEmpty == false
    }

    // MARK: Composition

    @Test func boldToggleKeepsComposition() {
        textView.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0))
        #expect(controller.isComposing)

        controller.toggleBold()

        #expect(textView.markedTextRange != nil)
        #expect(controller.markedRange == NSRange(location: 0, length: 4))
        #expect(textView.text == "にほんご")
        #expect(isBold(at: 0))
        #expect(isBold(at: 3))
    }

    @Test func textCommittedAfterBoldToggleIsBold() {
        textView.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0))
        controller.toggleBold()
        // The input method replaces the marked text as conversion proceeds,
        // then commits it.
        textView.setMarkedText("日本語", selectedRange: NSRange(location: 3, length: 0))
        textView.insertText("日本語")

        #expect(textView.markedTextRange == nil)
        #expect(textView.text == "日本語")
        #expect(isBold(at: 0))
        #expect(isBold(at: 2))
    }

    @Test func documentIsNotWrittenBackWhileComposing() {
        var snapshots: [String] = []
        controller.onDocumentChange = { snapshots.append($0.string) }

        textView.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0))
        controller.toggleBold()
        #expect(snapshots.isEmpty)

        textView.insertText("日本語")
        #expect(snapshots.last == "日本語")
    }

    @Test func externalChangesAreRefusedWhileComposing() {
        textView.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0))

        let replaced = controller.replaceDocument(NSAttributedString(string: "replaced"))
        let selected = controller.select(NSRange(location: 0, length: 0))

        #expect(!replaced)
        #expect(!selected)
        #expect(textView.markedTextRange != nil)
        #expect(textView.text == "にほんご")
    }

    // MARK: Selection

    @Test func typingInTheMiddleKeepsTheCaret() {
        textView.insertText("Hello world")
        // Feed every snapshot straight back, as a SwiftUI binding would.
        controller.onDocumentChange = { [controller] in controller.replaceDocument($0) }

        controller.select(NSRange(location: 5, length: 0))
        textView.insertText(",")

        #expect(textView.text == "Hello, world")
        #expect(textView.selectedRange == NSRange(location: 6, length: 0))
        #expect(controller.selectedRange == NSRange(location: 6, length: 0))
    }

    @Test func replacingTheDocumentKeepsTheCaret() {
        textView.insertText("Hello world")
        controller.select(NSRange(location: 5, length: 0))

        let restyled = NSMutableAttributedString(attributedString: textView.attributedText)
        restyled.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: 5))
        controller.replaceDocument(restyled)

        #expect(textView.selectedRange == NSRange(location: 5, length: 0))
    }

    @Test func selectionIsClampedToTheDocument() {
        textView.insertText("abc")
        controller.select(NSRange(location: 10, length: 5))
        #expect(textView.selectedRange == NSRange(location: 3, length: 0))
    }

    // MARK: Bold

    @Test func boldAppliesToTheSelectionAndUndoes() throws {
        // Loading a document registers no undo, unlike typing. Typing here
        // would share an undo group with the bold command, because a test has
        // no run-loop turn between the two.
        controller.replaceDocument(
            NSAttributedString(string: "Hello world", attributes: [.font: EditorController.baseFont]))
        controller.select(NSRange(location: 0, length: 5))

        controller.toggleBold()
        #expect(isBold(at: 0))
        #expect(isBold(at: 4))
        #expect(!isBold(at: 6))
        #expect(controller.isBoldActive)

        let undoManager = try #require(textView.undoManager)
        undoManager.undo()
        #expect(!isBold(at: 0))
        #expect(textView.text == "Hello world")

        undoManager.redo()
        #expect(isBold(at: 0))
    }

    @Test func boldWithoutSelectionAppliesToTypedText() {
        textView.insertText("a")
        controller.toggleBold()
        textView.insertText("b")

        #expect(!isBold(at: 0))
        #expect(isBold(at: 1))
    }

    // MARK: Lists

    @Test func listToggleCoversEverySelectedParagraph() {
        textView.insertText("one\ntwo\nthree")
        controller.select(NSRange(location: 1, length: 5))

        controller.toggleList()

        #expect(isList(at: 0))
        #expect(isList(at: 4))
        #expect(!isList(at: 8))
        #expect(controller.isListActive)
    }

    // The next three tests pin what UITextView does by itself (observed on
    // iOS 26.3). The prototype relies on it, so a different OS version must
    // show up here as a failure.

    @Test func returnOnANonEmptyItemContinuesTheList() {
        textView.insertText("one")
        controller.toggleList()

        textView.insertText("\n")
        textView.insertText("two")

        #expect(isList(at: 0))
        #expect(isList(at: 4))
        #expect(controller.isListActive)
    }

    @Test func returnOnAnEmptyItemLeavesTheList() {
        textView.insertText("one")
        controller.toggleList()

        textView.insertText("\n")
        textView.insertText("\n")

        #expect(textView.text == "one\n")
        #expect(isList(at: 0))
        #expect(!controller.isListActive)
    }

    /// UITextView keeps a space after the caret so that an empty last item has
    /// a character to carry its paragraph style. The space stays at the end of
    /// the storage, so the document model has to strip it.
    @Test func emptyTrailingItemIsHeldByAPlaceholderSpace() {
        textView.insertText("one")
        controller.toggleList()

        textView.insertText("\n")
        #expect(textView.text == "one\n ")
        #expect(textView.selectedRange == NSRange(location: 4, length: 0))

        textView.insertText("two")
        #expect(textView.text == "one\ntwo ")
    }

    @Test func backspaceAtTheStartOfAnItemRemovesTheMarker() {
        textView.insertText("one\ntwo")
        controller.select(NSRange(location: 0, length: 7))
        controller.toggleList()
        controller.select(NSRange(location: 4, length: 0))

        let allowed = controller.shouldChangeText(in: NSRange(location: 3, length: 1), replacementText: "")

        #expect(!allowed)
        #expect(textView.text == "one\ntwo")
        #expect(isList(at: 0))
        #expect(!isList(at: 4))
    }
}
#endif
