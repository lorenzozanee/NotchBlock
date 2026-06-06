import SwiftUI

/// Onboarding view for the desktop pet feature.
///
/// Shows a preview of the Elysia pet and lets the user enable or skip it.
/// Choice is persisted to PetPreferences.isEnabled.
struct PetOnboardingView: View {
    let onComplete: () -> Void

    @State private var previewImage: NSImage?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("你的桌面伙伴")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Elysia 会在你专注时为你加油，\n在任务完成时为你庆祝。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Pet preview area
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 140, height: 140)

                if let preview = previewImage {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.accentColor)
                        Text("Elysia")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                loadPreview()
            }

            // Action buttons
            VStack(spacing: 12) {
                Button(action: enablePet) {
                    Text("启用 Elysia")
                        .fontWeight(.semibold)
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: skipPet) {
                    Text("暂不启用")
                        .frame(width: 200)
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
            }

            Text("你可以随时在宠物设置中更改此选项")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(width: 380, height: 400)
    }

    // MARK: - Actions

    private func enablePet() {
        var prefs = PetPreferences()
        prefs.isEnabled = true
        onComplete()
    }

    private func skipPet() {
        var prefs = PetPreferences()
        prefs.isEnabled = false
        onComplete()
    }

    // MARK: - Preview Image

    private func loadPreview() {
        // Try to load the idle GIF's first frame as a static preview
        let subpath = "Pets/elysia/waving.gif"
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent(subpath),
           let image = NSImage(contentsOf: bundleURL) {
            previewImage = image
            return
        }
        // Development fallback
#if DEBUG
        let devPath = "/Users/\(NSUserName())/projects/ccprojects/NotchBlock/NotchBlock/Resources/\(subpath)"
        if let image = NSImage(contentsOfFile: devPath) {
            previewImage = image
        }
#endif
    }
}

// MARK: - Preview

#if DEBUG
struct PetOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        PetOnboardingView(onComplete: {})
    }
}
#endif
