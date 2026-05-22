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
                case .numbered(let marker, let content):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(marker).")
                            .font(.body.monospacedDigit())
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
    case numbered(String, String)  // marker (e.g. "1", "10"), content
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
        } else if let (marker, content) = numberedContent(trimmed) {
            blocks.append(.numbered(marker, content))
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

/// Detects numbered list lines like "1. step", "10. step", "2) step" and returns
/// (marker, content). The original number is preserved so a list starting at "5."
/// renders as "5." rather than being renumbered.
private func numberedContent(_ line: String) -> (String, String)? {
    var idx = line.startIndex
    while idx < line.endIndex, line[idx].isNumber { idx = line.index(after: idx) }
    guard idx > line.startIndex, idx < line.endIndex else { return nil }
    let punct = line[idx]
    guard punct == "." || punct == ")" else { return nil }
    let afterPunct = line.index(after: idx)
    guard afterPunct < line.endIndex, line[afterPunct] == " " else { return nil }
    let marker = String(line[line.startIndex..<idx])
    let content = String(line[line.index(after: afterPunct)...])
    return (marker, content)
}
