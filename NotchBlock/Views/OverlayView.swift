import SwiftUI

/// Fullscreen hard-interrupt overlay at time block end (AC 3.1, 3.2).
///
/// 70% opacity black backdrop with centered card showing task name,
/// [已完成] / [去调整计划] buttons, and a live 5-minute countdown.
struct OverlayView: View {
    let block: TimeBlock
    let onCompleted: () -> Void
    let onAdjust: () -> Void
    let onExtend: (TimeInterval) -> Void

    @State private var elapsedSeconds: Int = 0
    @State private var cardAppeared = false
    @State private var customMinutes = ""
    @State private var showCustomField = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeoutSeconds = 300

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                .overlay(
                    RadialGradient(
                        colors: [.black.opacity(0.45), .black.opacity(0.55), .black.opacity(0.7)],
                        center: .center, startRadius: 200, endRadius: 800
                    ).ignoresSafeArea()
                )

            VStack(spacing: 32) {
                Image(systemName: "bell.and.waves.left.and.right")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating, value: cardAppeared)

                VStack(spacing: 10) {
                    Text("「\(block.title)」的时间到了！")
                        .font(.title.weight(.semibold)).foregroundStyle(.primary)
                    Text("你完成了这项任务吗？")
                        .font(.title3).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "timer").font(.caption)
                        Text("\(remainingFormatted) 后自动标记为未完成")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                    }.foregroundStyle(.tertiary).padding(.top, 6)
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

                VStack(spacing: 10) {
                    Text("延长时间").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        extendButton("+5 分钟", 300)
                        extendButton("+10 分钟", 600)
                        Button("自定义") {
                            withAnimation(.snappy) { showCustomField.toggle() }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6).padding(.horizontal, 14)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        .font(.caption)
                    }
                    if showCustomField {
                        HStack(spacing: 8) {
                            TextField("分钟数", text: $customMinutes)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                                .padding(.vertical, 5).padding(.horizontal, 10)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                .font(.caption)
                            Button("延长") {
                                if let mins = Int(customMinutes), mins > 0 {
                                    onExtend(TimeInterval(mins * 60))
                                    customMinutes = ""
                                    showCustomField = false
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 5).padding(.horizontal, 12)
                            .background(BrandColors.accent, in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(.white).font(.caption)
                            .disabled(Int(customMinutes) == nil || (Int(customMinutes) ?? 0) <= 0)
                        }
                    }
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

    private func extendButton(_ label: String, _ seconds: TimeInterval) -> some View {
        Button(label) { onExtend(seconds) }
            .buttonStyle(.plain)
            .padding(.vertical, 6).padding(.horizontal, 14)
            .background(BrandColors.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(BrandColors.accent)
            .font(.caption.weight(.medium))
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
        onAdjust: {},
        onExtend: { _ in }
    )
}
#endif
