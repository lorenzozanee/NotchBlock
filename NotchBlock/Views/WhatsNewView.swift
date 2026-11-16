import SwiftUI

/// Shown on first launch after an update. Displays the changelog for the new version.
struct WhatsNewView: View {
    private struct ChangelogLine: Identifiable {
        let id: Int
        let text: String
    }

    let version: String
    let changelog: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(BrandColors.accentText)
                Text("NotchBlock \(version)")
                    .font(.headline)
                    .foregroundStyle(BrandColors.textPrimary)
                Spacer()
                Button("知道了") { onDismiss() }
                    .buttonStyle(MinimalPrimaryButtonStyle(horizontalPadding: 14, verticalPadding: 6))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 12)

            MinimalHairline()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(parsedLines) { line in
                        if line.text.hasPrefix("### ") {
                            Text(String(line.text.dropFirst(4)))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandColors.accentText)
                                .padding(.top, 6)
                        } else if line.text.hasPrefix("- ") {
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(BrandColors.accent)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)
                                markdownText(String(line.text.dropFirst(2)))
                                    .font(.subheadline)
                                    .foregroundStyle(BrandColors.textPrimary)
                            }
                        } else {
                            markdownText(line.text)
                                .font(.subheadline)
                                .foregroundStyle(BrandColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 480, height: 400)
        .background {
            FrostedGlassBackground(
                material: .hudWindow,
                tint: BrandColors.panelGlass
            )
            .ignoresSafeArea()
        }
    }

    private var parsedLines: [ChangelogLine] {
        changelog
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { ChangelogLine(id: $0.offset, text: $0.element) }
    }

    private func markdownText(_ source: String) -> Text {
        if let attributed = try? AttributedString(markdown: source) {
            return Text(attributed)
        }
        return Text(source)
    }
}
