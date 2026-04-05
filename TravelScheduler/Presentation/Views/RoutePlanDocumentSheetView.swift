import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RoutePlanDocumentSheetView: View {
    private struct MarkdownLine: Identifiable {
        enum Style {
            case title
            case section
            case subsection
            case bullet(indentLevel: Int)
            case numbered(marker: String)
            case paragraph
            case spacer
        }

        let id: Int
        let style: Style
        let text: String
    }

    let markdown: String
    private let markdownLines: [MarkdownLine]

    @Environment(\.dismiss) private var dismiss
    @State private var hasCopied = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    init(markdown: String) {
        self.markdown = markdown
        markdownLines = Self.parseMarkdownLines(from: markdown)
    }

    private var hasContent: Bool {
        !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if hasContent {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(markdownLines) { line in
                            markdownLineView(line)
                        }
                    }
                    .padding(16)
                } else {
                    ContentUnavailableView(
                        L10n.routePlanDocumentEmptyTitle,
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(L10n.routePlanDocumentEmptyDescription)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.routePlanDocumentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.commonClose) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        copyMarkdown()
                    } label: {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(
                        hasCopied
                            ? L10n.routePlanDocumentCopiedAccessibility
                            : L10n.routePlanDocumentCopyAccessibility
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                if hasCopied {
                    Label(
                        L10n.routePlanDocumentCopiedToClipboard,
                        systemImage: "checkmark.circle.fill"
                    )
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 12)
                }
            }
            .onDisappear {
                copyFeedbackTask?.cancel()
            }
        }
    }

    private func copyMarkdown() {
        #if canImport(UIKit)
        UIPasteboard.general.string = markdown
        #endif

        copyFeedbackTask?.cancel()
        hasCopied = true
        copyFeedbackTask = Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                hasCopied = false
            }
        }
    }

    @ViewBuilder
    private func markdownLineView(_ line: MarkdownLine) -> some View {
        switch line.style {
        case .title:
            Text(line.text)
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
        case .section:
            Text(line.text)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        case .subsection:
            Text(line.text)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        case .bullet(let indentLevel):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body.weight(.semibold))
                Text(line.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(indentLevel) * 18)
        case .numbered(let marker):
            HStack(alignment: .top, spacing: 8) {
                Text(marker)
                    .font(.body.weight(.semibold))
                Text(line.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .paragraph:
            Text(line.text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .spacer:
            Color.clear
                .frame(height: 2)
        }
    }

    private static func parseMarkdownLines(from markdown: String) -> [MarkdownLine] {
        markdown
            .components(separatedBy: .newlines)
            .enumerated()
            .map { index, line in
                parseMarkdownLine(line, id: index)
            }
    }

    private static func parseMarkdownLine(_ rawLine: String, id: Int) -> MarkdownLine {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return MarkdownLine(id: id, style: .spacer, text: "")
        }

        if trimmed.hasPrefix("# ") {
            return MarkdownLine(id: id, style: .title, text: String(trimmed.dropFirst(2)))
        }

        if trimmed.hasPrefix("## ") {
            return MarkdownLine(id: id, style: .section, text: String(trimmed.dropFirst(3)))
        }

        if trimmed.hasPrefix("### ") {
            return MarkdownLine(id: id, style: .subsection, text: String(trimmed.dropFirst(4)))
        }

        if rawLine.hasBulletPrefix {
            return MarkdownLine(
                id: id,
                style: .bullet(indentLevel: rawLine.markdownIndentLevel),
                text: String(trimmed.dropFirst(2))
            )
        }

        if let numberedMarker = trimmed.markdownNumberedMarker {
            let textStartIndex = trimmed.index(trimmed.startIndex, offsetBy: numberedMarker.count + 1)
            let text = String(trimmed[textStartIndex...]).trimmingCharacters(in: .whitespaces)
            return MarkdownLine(id: id, style: .numbered(marker: numberedMarker), text: text)
        }

        return MarkdownLine(id: id, style: .paragraph, text: trimmed)
    }
}

private extension String {
    var hasBulletPrefix: Bool {
        trimmingCharacters(in: .whitespaces).hasPrefix("- ")
    }

    var markdownIndentLevel: Int {
        let leadingSpaces = prefix { $0 == " " }.count
        return leadingSpaces >= 2 ? 1 : 0
    }

    var markdownNumberedMarker: String? {
        let parts = split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let candidate = parts.first, candidate.last == "." else { return nil }

        let digits = candidate.dropLast()
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }

        return String(candidate)
    }
}
