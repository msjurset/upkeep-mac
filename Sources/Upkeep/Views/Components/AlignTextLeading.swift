import SwiftUI

/// A text field that always left-aligns its text, bypassing macOS Form's forced right-alignment.
struct LeadingTextField: NSViewRepresentable {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var isFocused: Binding<Bool>?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: isFocused)
    }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.alignment = .left
        tf.isBordered = true
        tf.isBezeled = true
        tf.bezelStyle = .roundedBezel
        tf.drawsBackground = true
        tf.font = .systemFont(ofSize: NSFont.systemFontSize)
        tf.placeholderString = prompt.isEmpty ? label : prompt
        tf.delegate = context.coordinator
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.truncatesLastVisibleLine = true
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text {
            tf.stringValue = text
        }
        tf.alignment = .left
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>?

        init(text: Binding<String>, isFocused: Binding<Bool>?) {
            self.text = text
            self.isFocused = isFocused
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            text.wrappedValue = tf.stringValue
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isFocused?.wrappedValue = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isFocused?.wrappedValue = false
        }
    }
}
