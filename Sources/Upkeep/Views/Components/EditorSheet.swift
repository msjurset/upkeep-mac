import SwiftUI

struct EditorSheet<Content: View>: View {
    let title: String
    let isValid: Bool
    let saveLabel: String
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    init(title: String, isValid: Bool = true, saveLabel: String = "Save",
         onSave: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isValid = isValid
        self.saveLabel = saveLabel
        self.onSave = onSave
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            Form {
                content()
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(saveLabel) {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }
}
