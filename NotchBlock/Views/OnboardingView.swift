import SwiftUI

/// Minimalist frosted-glass 3-step onboarding wizard.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("focusStartHour") private var focusStartHour = 9
    @AppStorage("focusEndHour") private var focusEndHour = 18
    @State private var currentPage = 0
    @State private var launchAtLogin = false

    var onComplete: () -> Void

    private let pages = 3

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    ForEach(0..<pages, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? BrandColors.accentText : BrandColors.hairline)
                            .frame(width: index == currentPage ? 18 : 7, height: 7)
                            .animation(.smooth(duration: 0.25), value: currentPage)
                    }
                }
                HStack {
                    Spacer()
                    Button("跳过") { finish() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)

            Group {
                switch currentPage {
                case 0: welcomePage
                case 1: preferencesPage
                default: completionPage
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            .animation(.smooth(duration: 0.28), value: currentPage)
            .frame(maxHeight: .infinity)

            HStack {
                if currentPage > 0 {
                    Button("上一步") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(MinimalSecondaryButtonStyle(horizontalPadding: 14, verticalPadding: 7))
                }
                Spacer()
                Button(currentPage < pages - 1 ? "下一步" : "开始使用") {
                    if currentPage < pages - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        finish()
                    }
                }
                .buttonStyle(MinimalPrimaryButtonStyle(horizontalPadding: 18, verticalPadding: 7))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 22)
        }
        .frame(width: 460, height: 440)
        .background {
            FrostedGlassBackground(
                material: .hudWindow,
                tint: BrandColors.panelGlass,
                cornerRadius: 10,
                showBorder: true
            )
            .ignoresSafeArea()
        }
        .tint(BrandColors.accentText)
        .onAppear {
            launchAtLogin = LaunchManager.isLoginItemEnabled
        }
    }

    // MARK: - Page 1

    private var welcomePage: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(BrandColors.accentSoft)
                    .frame(width: 64, height: 64)
                Circle()
                    .strokeBorder(BrandColors.accentBorder, lineWidth: 1)
                    .frame(width: 64, height: 64)
                Image(systemName: "timer")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(BrandColors.accentText)
            }

            VStack(spacing: 6) {
                Text("NotchBlock")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BrandColors.textPrimary)
                Text("刘海时间块与全屏专注提醒")
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                featureRow(icon: "rectangle.and.hand.point.up.left", title: "刘海悬停预览")
                featureRow(icon: "square.grid.2x2", title: "菜单栏快捷排程")
                featureRow(icon: "bell", title: "全屏结束强提醒")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .minimalCard(cornerRadius: 12)
        }
        .padding(.horizontal, 34)
    }

    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(BrandColors.accentText)
                .frame(width: 22)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandColors.textPrimary)
        }
    }

    // MARK: - Page 2

    private var preferencesPage: some View {
        VStack(spacing: 20) {
            Text("专注时段")
                .font(.title3.weight(.semibold))
                .foregroundStyle(BrandColors.textPrimary)

            VStack(spacing: 14) {
                HStack {
                    Label("每日开始", systemImage: "sunrise")
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.textPrimary)
                    Spacer()
                    Picker("", selection: $focusStartHour) {
                        ForEach(6..<18, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: focusStartHour) { _, newStart in
                        if focusEndHour <= newStart {
                            focusEndHour = min(24, newStart + 1)
                        }
                    }
                }
                MinimalHairline()
                HStack {
                    Label("每日结束", systemImage: "sunset")
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.textPrimary)
                    Spacer()
                    Picker("", selection: $focusEndHour) {
                        ForEach(12..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: focusEndHour) { _, newEnd in
                        if newEnd <= focusStartHour {
                            focusStartHour = max(0, newEnd - 1)
                        }
                    }
                }
                MinimalHairline()
                Toggle(isOn: $launchAtLogin) {
                    Label("开机自动启动", systemImage: "power")
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.textPrimary)
                }
                .onChange(of: launchAtLogin) { _, enabled in
                    guard enabled != LaunchManager.isLoginItemEnabled else { return }
                    do {
                        try LaunchManager.setLoginItemEnabled(enabled)
                    } catch {
                        launchAtLogin = LaunchManager.isLoginItemEnabled
                    }
                }
            }
            .padding(18)
            .minimalCard(cornerRadius: 12)
        }
        .padding(.horizontal, 34)
    }

    // MARK: - Page 3

    private var completionPage: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(BrandColors.accentSoft)
                    .frame(width: 64, height: 64)
                Circle()
                    .strokeBorder(BrandColors.accentBorder, lineWidth: 1)
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(BrandColors.accentText)
            }

            Text("准备就绪")
                .font(.title3.weight(.semibold))
                .foregroundStyle(BrandColors.textPrimary)

            Text("已为你准备示例日程，可从菜单栏随时调整")
                .font(.caption)
                .foregroundStyle(BrandColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 34)
    }

    private func finish() {
        hasCompletedOnboarding = true
        onComplete()
    }
}

#if DEBUG
#Preview {
    OnboardingView(onComplete: {})
}
#endif
