import SwiftUI

struct MarkdownNotesView: View {
    let text: String

    private var blocks: [NoteBlock] {
        parseBlocks(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let content):
                    Text(markdown(content))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                case .bullet(let content):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(markdown(content))
                            .font(.body)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                case .blank:
                    Spacer().frame(height: 4)
                }
            }
        }
    }

    private func markdown(_ input: String) -> AttributedString {
        (try? AttributedString(markdown: input, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(input)
    }
}

private enum NoteBlock {
    case paragraph(String)
    case bullet(String)
    case blank
}

private func parseBlocks(_ text: String) -> [NoteBlock] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    var blocks: [NoteBlock] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Collapse consecutive blanks
            if case .blank = blocks.last {} else {
                blocks.append(.blank)
            }
        } else if let content = bulletContent(trimmed) {
            blocks.append(.bullet(content))
        } else {
            blocks.append(.paragraph(trimmed))
        }
    }

    // Remove leading/trailing blanks
    while blocks.first.map({ if case .blank = $0 { true } else { false } }) == true {
        blocks.removeFirst()
    }
    while blocks.last.map({ if case .blank = $0 { true } else { false } }) == true {
        blocks.removeLast()
    }

    return blocks
}

/// Detects bullet lines starting with •, -, *, or – and returns the content after the marker.
private func bulletContent(_ line: String) -> String? {
    let prefixes = ["• ", "- ", "* ", "– ", "— "]
    for prefix in prefixes {
        if line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count))
        }
    }
    return nil
}
