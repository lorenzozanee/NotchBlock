import SwiftUI

/// SwiftUI view that renders the current pet animation frame.
///
/// Displays the CGImage published by PetAnimationPlayer as an Image.
/// Supports hover-driven alpha animation and displays a placeholder
/// when no frame is available yet.
struct PetView: View {
    @ObservedObject var animationPlayer: PetAnimationPlayer
    @ObservedObject var stateMachine: PetStateMachine

    @State private var hoverAlpha: CGFloat = 0.85

    var body: some View {
        ZStack {
            if let frame = animationPlayer.currentFrame {
                Image(nsImage: NSImage(cgImage: frame, size: .zero))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(hoverAlpha)
                    .animation(.easeOut(duration: 0.2), value: hoverAlpha)
            } else {
                // Placeholder while frames load
                placeholderView
            }
        }
        .frame(width: 120, height: 120)
        // Hover alpha is managed by PetInteractionHandler via NSTrackingArea
        // (no .onHover here — avoids conflicting with AppKit animation system)
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 120, height: 120)

            Text("?")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PetView_Previews: PreviewProvider {
    static var previews: some View {
        let player = PetAnimationPlayer()
        let stateMachine = PetStateMachine(
            store: TimeBlockStore(),
            preferences: PetPreferences()
        )
        PetView(animationPlayer: player, stateMachine: stateMachine)
            .frame(width: 120, height: 120)
            .padding()
    }
}
#endif
