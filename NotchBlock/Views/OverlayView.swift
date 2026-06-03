import SwiftUI

/// Fullscreen hard-interrupt overlay at time block end (AC 3.1, 3.2).
///
/// 70% opacity black backdrop with centered card showing task name,
/// [已完成] / [去调整计划] buttons, and a live 5-minute countdown.
struct OverlayView: View {
    let block: TimeBlock
    let onCompleted: () -> Void
    let onAdjust: () -> Void

    @State private var elapsedSeconds: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeoutSeconds = 300

    var body: some View {
        ZStack {
            // AC 3.1: 70% dimming, blocks clicks via NSPanel ignoresMouseEvents=false
            Color.black.opacity(0.7).ignoresSafeArea()

            // AC 3.2: Central card
            VStack(spacing: 28) {
                Image(systemName: "bell.and.waves.left.and.right")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text("「\(block.title)」的时间到了！")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("你完成了这项任务吗？")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Image(systemName: "timer").font(.caption)
                        Text("\(remainingFormatted) 后自动标记为未完成")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button(action: onAdjust) {
                        Text("去调整计划").frame(width: 140)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)

                    Button(action: onCompleted) {
                        Text("已完成").frame(width: 140)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.black)
                    .fontWeight(.semibold)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 32)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .onReceive(timer) { _ in elapsedSeconds += 1 }
    }

    private var remainingFormatted: String {
        let remaining = max(0, timeoutSeconds - elapsedSeconds)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#if DEBUG
#Preview {
    OverlayView(
        block: TimeBlock(
            title: "深度工作",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            status: .pending
        ),
        onCompleted: {},
        onAdjust: {}
    )
}
#endif
