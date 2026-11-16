import SwiftUI

/// Fullscreen hard-interrupt frosted-glass overlay shown when a time block ends.
struct OverlayView: View {
    let block: TimeBlock
    let subsequentTaskCount: Int
    let onCompleted: () -> Void
    let onAdjust: () -> Void
    let onExtend: (TimeInterval, Bool) -> Void

    @State private var timeoutDeadline = Date().addingTimeInterval(300)
    @State private var cardAppeared = false
    @State private var customMinutes = ""
    @State private var showCustomField = false
    @State private var shiftAllSubsequent = false

    private let timeoutDuration: TimeInterval = 300

    var body: some View {
        ZStack {
            ZStack {
                VisualEffectBackdrop(material: .fullScreenUI, blendingMode: .behindWindow)
                BrandColors.overlayScrim
            }
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(BrandColors.accentSoft)
                        .frame(width: 68, height: 68)
                    Circle()
                        .strokeBorder(BrandColors.accentBorder, lineWidth: 1)
                        .frame(width: 68, height: 68)
                    Image(systemName: "bell")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(BrandColors.accentText)
                        .symbolEffect(.pulse, options: .repeating, value: cardAppeared)
                }

                VStack(spacing: 8) {
                    Text("「\(block.title)」已结束")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(BrandColors.textPrimary)

                    SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil(timeoutDeadline.timeIntervalSince(context.date))))
                        Text("\(formatCountdown(remaining)) 后自动记为未完成")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button(action: onAdjust) {
                        Text("调整排程")
                            .frame(width: 132)
                    }
                    .buttonStyle(MinimalSecondaryButtonStyle(cornerRadius: 10, verticalPadding: 10))

                    Button(action: onCompleted) {
                        Text("已完成")
                            .frame(width: 132)
                    }
                    .buttonStyle(MinimalPrimaryButtonStyle(cornerRadius: 10, verticalPadding: 10))
                }

                MinimalHairline()

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        extendButton("+5m", 300)
                        extendButton("+10m", 600)
                        Button {
                            withAnimation(.snappy(duration: 0.18)) { showCustomField.toggle() }
                        } label: {
                            Text("自定义")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(MinimalSecondaryButtonStyle(cornerRadius: 6, horizontalPadding: 12, verticalPadding: 6))
                    }

                    if showCustomField {
                        HStack(spacing: 8) {
                            TextField("分钟", text: $customMinutes)
                                .minimalInput(cornerRadius: 6)
                                .frame(width: 76)
                                .onSubmit { extendCustom() }

                            Button(action: extendCustom) {
                                Text("延长")
                                    .font(.caption.weight(.medium))
                            }
                            .buttonStyle(MinimalPrimaryButtonStyle(cornerRadius: 6, horizontalPadding: 12, verticalPadding: 7))
                            .disabled(parsedCustomMinutes == nil)
                        }
                    }

                    Toggle(isOn: $shiftAllSubsequent) {
                        Text("顺延后续任务\(subsequentTaskCount > 0 ? "（\(subsequentTaskCount)）" : "")")
                            .font(.caption)
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .padding(34)
            .frame(width: 400)
            .background {
                FrostedGlassBackground(
                    material: .hudWindow,
                    tint: BrandColors.panelGlass,
                    cornerRadius: 24,
                    showBorder: true
                )
            }
            .shadow(color: .black.opacity(0.32), radius: 44, y: 12)
        }
        .onAppear {
            timeoutDeadline = Date().addingTimeInterval(timeoutDuration)
            cardAppeared = true
        }
    }

    private var parsedCustomMinutes: Int? {
        guard let mins = Int(customMinutes.trimmingCharacters(in: .whitespaces)),
              (1...480).contains(mins)
        else { return nil }
        return mins
    }

    private func extendCustom() {
        guard let mins = parsedCustomMinutes else { return }
        doExtend(TimeInterval(mins * 60))
        customMinutes = ""
        showCustomField = false
    }

    private func doExtend(_ seconds: TimeInterval) {
        onExtend(seconds, shiftAllSubsequent)
    }

    private func extendButton(_ label: String, _ seconds: TimeInterval) -> some View {
        Button { doExtend(seconds) } label: {
            Text(label)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(BrandColors.accentText)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .minimalCard(cornerRadius: 6, fill: BrandColors.accentSoft, border: BrandColors.accentBorder)
        }
        .buttonStyle(.plain)
    }

    private func formatCountdown(_ remainingSeconds: Int) -> String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
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
        subsequentTaskCount: 2,
        onCompleted: {},
        onAdjust: {},
        onExtend: { _, _ in }
    )
}
#endif
