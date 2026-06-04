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
    @State private var cardAppeared = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeoutSeconds = 300

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                .overlay(Color.black.opacity(0.35).ignoresSafeArea())

            VStack(spacing: 28) {
                Image(systemName: "bell.and.waves.left.and.right")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating, value: cardAppeared)

                VStack(spacing: 8) {
                    Text("「\(block.title)」的时间到了！")
                        .font(.title.weight(.semibold)).foregroundStyle(.primary)
                    Text("你完成了这项任务吗？")
                        .font(.title3).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "timer").font(.caption)
                        Text("\(remainingFormatted) 后自动标记为未完成").font(.caption)
                    }.foregroundStyle(.tertiary).padding(.top, 4)
                }.multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button(action: onAdjust) {
                        Text("去调整计划").frame(width: 140)
                    }.buttonStyle(.plain).padding(.vertical, 10)
                     .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                    Button(action: onCompleted) {
                        Text("已完成").frame(width: 140)
                    }.buttonStyle(.plain).padding(.vertical, 10)
                     .background(.white, in: RoundedRectangle(cornerRadius: 8))
                     .foregroundStyle(.black).fontWeight(.semibold)
                }
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(
                LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 48, y: 8)
            .scaleEffect(cardAppeared ? 1 : 0.9)
            .opacity(cardAppeared ? 1 : 0)
        }
        .onReceive(timer) { _ in elapsedSeconds += 1 }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { cardAppeared = true }
        }
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
