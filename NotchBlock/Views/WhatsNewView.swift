import SwiftUI

/// Shown on first launch after an update. Displays the changelog for the new version.
struct WhatsNewView: View {
    let version: String
    let changelog: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2).foregroundStyle(BrandColors.accent)
                Text("NotchBlock \(version) 更新内容")
                    .font(.title2.weight(.bold))
                Spacer()
                Button("知道了") { onDismiss() }
                    .buttonStyle(.borderedProminent).tint(BrandColors.accent)
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(parseSections(), id: \.self) { section in
                        if section.hasPrefix("###") {
                            Text(section.replacingOccurrences(of: "### ", with: ""))
                                .font(.headline).foregroundStyle(BrandColors.accent).padding(.top, 6)
                        } else if section.hasPrefix("-") {
                            HStack(alignment: .top, spacing: 6) {
                                Circle().fill(BrandColors.accent).frame(width: 6, height: 6).padding(.top, 6)
                                Text(section.replacingOccurrences(of: "- ", with: ""))
                                    .font(.body)
                            }
                        } else if !section.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(section).font(.body).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
            }

            Divider()
            HStack {
                Text("感谢使用 NotchBlock ❤️").font(.caption).foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.vertical, 10)
        }
        .frame(width: 500, height: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func parseSections() -> [String] {
        changelog.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
