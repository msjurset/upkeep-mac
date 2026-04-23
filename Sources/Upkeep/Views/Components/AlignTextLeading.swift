import SwiftUI

/// Left-aligned NSTextField with a caption label stacked above. Bypasses macOS Form's
/// forced right-alignment for custom text fields (which otherwise render labelless).
struct LeadingTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var isFocused: Binding<Bool>?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            LeadingTextFieldCore(text: $text, prompt: prompt.isEmpty ? label : prompt, isFocused: isFocused)
        }
    }
}

/// The NSTextField wrapper — separated from the labeled wrapper so nested uses
/// (e.g. inside TagSuggestField) can compose it without duplicating the label.
struct LeadingTextFieldCore: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
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
        tf.placeholderString = prompt
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
