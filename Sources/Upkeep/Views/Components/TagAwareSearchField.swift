import AppKit
import SwiftUI

/// NSTextField wrapper that forwards Tab, arrows, and Enter to the parent via callbacks.
/// Pairs with `TagSuggestionMonitor` for Ctrl-J/K which don't map to standard AppKit selectors.
struct TagAwareSearchField: NSViewRepresentable {
    @Binding var query: String
    let placeholder: String
    let hasSuggestions: () -> Bool
    let onNavigate: (TagNavDirection) -> Void
    let onAccept: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.delegate = context.coordinator
        // Disable macOS field-editor autofill popups per project rules
        field.cell?.usesSingleLineMode = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != query {
            nsView.stringValue = query
            if let editor = nsView.currentEditor() {
                editor.selectedRange = NSRange(location: nsView.stringValue.count, length: 0)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TagAwareSearchField
        init(_ parent: TagAwareSearchField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.query = field.stringValue
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            suppressFieldEditorAutofeatures(in: obj)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let hasSuggestions = parent.hasSuggestions()
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)),
                 #selector(NSResponder.moveDown(_:)):
                if hasSuggestions {
                    parent.onNavigate(.down)
                    return true
                }
            case #selector(NSResponder.moveUp(_:)):
                if hasSuggestions {
                    parent.onNavigate(.up)
                    return true
                }
            case #selector(NSResponder.insertNewline(_:)):
                parent.onAccept()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                if hasSuggestions {
                    parent.onNavigate(.escape)
                    return true
                }
            default:
                break
            }
            return false
        }

        private func suppressFieldEditorAutofeatures(in notification: Notification) {
            guard let editor = (notification.object as? NSTextField)?.currentEditor() as? NSTextView else { return }
            editor.isAutomaticTextCompletionEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isContinuousSpellCheckingEnabled = false
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticDataDetectionEnabled = false
            editor.isAutomaticLinkDetectionEnabled = false
            // macOS 14+ added an inline-prediction bar that renders as a
            // large ghost popup beneath the field on focus. The auto-* flags
            // above don't suppress it; this trait does.
            if #available(macOS 14.0, *) {
                editor.inlinePredictionType = .no
            }
        }
    }
}

enum TagNavDirection { case down, up, escape }

/// Intercepts Ctrl-J/K at the NSEvent level (they don't map to standard AppKit command selectors).
struct TagSuggestionMonitor: NSViewRepresentable {
    let hasSuggestions: () -> Bool
    let onNavigate: (TagNavDirection) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MonitorView()
        view.hasSuggestions = hasSuggestions
        view.onNavigate = onNavigate
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? MonitorView else { return }
        view.hasSuggestions = hasSuggestions
        view.onNavigate = onNavigate
    }

    final class MonitorView: NSView {
        var hasSuggestions: (() -> Bool)?
        var onNavigate: ((TagNavDirection) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      self.hasSuggestions?() == true,
                      event.modifierFlags.contains(.control) else { return event }
                // e.code is not available; use charactersIgnoringModifiers for J/K
                let char = event.charactersIgnoringModifiers
                if char == "j" {
                    Task { @MainActor in self.onNavigate?(.down) }
                    return nil
                }
                if char == "k" {
                    Task { @MainActor in self.onNavigate?(.up) }
                    return nil
                }
                return event
            }
        }

        override func removeFromSuperview() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            super.removeFromSuperview()
        }
    }
}
