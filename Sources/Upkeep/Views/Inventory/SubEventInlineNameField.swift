import SwiftUI
import AppKit

/// Inline-editable name field for a sub-event. Auto-focuses on appear, commits
/// on Enter or click-anywhere-else, and shows a trailing X to clear (without
/// exiting edit mode — clearing leaves the field focused for retyping).
///
/// Wraps NSTextField directly because SwiftUI's `@FocusState` on macOS does NOT
/// fire when the user clicks empty space — only when they click another
/// focusable control. To get commit-on-outside-click we need to install an
/// NSEvent monitor and explicitly resign first responder.
struct SubEventInlineNameField: View {
    @Binding var text: String
    let onCommit: () -> Void

    var body: some View {
        InlineTextFieldCore(text: $text, onCommit: onCommit)
            .overlay(alignment: .trailing) {
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 5)
                    .help("Clear")
                }
            }
    }
}

private struct InlineTextFieldCore: NSViewRepresentable {
    @Binding var text: String
    let onCommit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.alignment = .left
        tf.isBordered = true
        tf.isBezeled = true
        tf.bezelStyle = .roundedBezel
        tf.drawsBackground = true
        tf.font = .systemFont(ofSize: NSFont.systemFontSize)
        tf.delegate = context.coordinator
        tf.stringValue = text

        DispatchQueue.main.async { [weak tf] in
            guard let tf else { return }
            tf.window?.makeFirstResponder(tf)
            context.coordinator.startOutsideClickMonitoring(textField: tf)
        }
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text {
            tf.stringValue = text
        }
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ tf: NSTextField, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InlineTextFieldCore
        private var monitor: Any?
        private var hasCommitted = false

        init(_ parent: InlineTextFieldCore) { self.parent = parent }

        deinit { stopMonitoring() }

        func startOutsideClickMonitoring(textField: NSTextField) {
            stopMonitoring()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak textField] event in
                guard let textField, let window = textField.window else { return event }
                if event.window != window { return event }
                let locationInWindow = event.locationInWindow
                let frameInWindow = textField.convert(textField.bounds, to: nil)
                if !frameInWindow.contains(locationInWindow) {
                    window.makeFirstResponder(nil)
                }
                return event
            }
        }

        func stopMonitoring() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard !hasCommitted else { return }
            hasCommitted = true
            parent.onCommit()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}
