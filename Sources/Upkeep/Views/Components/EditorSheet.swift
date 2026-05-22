import SwiftUI
import AppKit

struct EditorSheet<Content: View, Toolbar: View>: View {
    let title: String
    let isValid: Bool
    let saveLabel: String
    let onSave: () -> Void
    @ViewBuilder let toolbar: () -> Toolbar
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    init(title: String, isValid: Bool = true, saveLabel: String = "Save",
         onSave: @escaping () -> Void,
         @ViewBuilder toolbar: @escaping () -> Toolbar,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isValid = isValid
        self.saveLabel = saveLabel
        self.onSave = onSave
        self.toolbar = toolbar
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                Spacer()
                toolbar()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button(saveLabel) {
                    // Force any in-progress text/date field edits to commit
                    // before reading bindings. Without this, an unfinished
                    // edit in NSDatePicker (textFieldAndStepper style) leaves
                    // the binding holding the old value.
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}

extension EditorSheet where Toolbar == EmptyView {
    init(title: String, isValid: Bool = true, saveLabel: String = "Save",
         onSave: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, isValid: isValid, saveLabel: saveLabel,
                  onSave: onSave, toolbar: { EmptyView() }, content: content)
    }
}
