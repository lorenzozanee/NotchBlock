import SwiftUI

/// First-launch setup wizard. 3-step TabView with skip.
/// Replaces the old `sendWelcomeNotification()` flow.
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
            HStack {
                HStack(spacing: 8) {
                    ForEach(0..<pages, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? BrandColors.accent : .secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.smooth, value: currentPage)
                    }
                }
                Spacer()
                Button("跳过") { finish() }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28).padding(.top, 20)

            Group {
                switch currentPage {
                case 0: welcomePage
                case 1: preferencesPage
                default: completionPage
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            .animation(.smooth(duration: 0.3), value: currentPage)
            .frame(minHeight: 360)

            HStack {
                if currentPage > 0 {
                    Button("上一步") { withAnimation { currentPage -= 1 } }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Spacer()
                Button(currentPage < pages - 1 ? "下一步" : "开始使用") {
                    if currentPage < pages - 1 {
                        withAnimation { currentPage += 1 }
                    } else { finish() }
                }
                .buttonStyle(.borderedProminent).tint(BrandColors.accent)
            }
            .padding(.horizontal, 28).padding(.bottom, 20)
        }
        .frame(width: 480, height: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Page 1

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Image(systemName: "timer.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(BrandColors.accent)
                .symbolEffect(.pulse, options: .repeating)

            Text("欢迎使用 NotchBlock")
                .font(.title.weight(.bold))

            Text("利用 Mac 刘海，轻松管理你的时间块")
                .font(.body).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                row(icon: "rectangle.and.hand.point.up.left", title: "刘海预览", desc: "鼠标悬停 Mac 刘海，快速查看今日任务")
                row(icon: "square.grid.3x3.fill", title: "时间块排程", desc: "将一天划分为专注时间块，菜单栏管理")
                row(icon: "eye.fill", title: "全屏专注", desc: "任务结束全屏遮罩提醒，保持节奏")
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 40).padding(.vertical, 20)
    }

    private func row(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3).foregroundStyle(BrandColors.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Page 2

    private var preferencesPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(BrandColors.accent)

            Text("快速设置").font(.title.weight(.bold))
            Text("配置你的专注时段，稍后可在菜单栏调整")
                .font(.body).foregroundStyle(.secondary)

            VStack(spacing: 16) {
                HStack {
                    Label("每日开始时间", systemImage: "sunrise")
                    Spacer()
                    Picker("", selection: $focusStartHour) {
                        ForEach(6..<18, id: \.self) { h in
                            Text(String(format: "%02d:00", h)).tag(h)
                        }
                    }.labelsHidden()
                }
                Divider()
                HStack {
                    Label("每日结束时间", systemImage: "sunset")
                    Spacer()
                    Picker("", selection: $focusEndHour) {
                        ForEach(12..<24, id: \.self) { h in
                            Text(String(format: "%02d:00", h)).tag(h)
                        }
                    }.labelsHidden()
                }
                Divider()
                Toggle(isOn: $launchAtLogin) {
                    Label("开机自动启动", systemImage: "power")
                }
                .onChange(of: launchAtLogin) { _, val in
                    do { try LaunchManager.setLoginItemEnabled(val) }
                    catch { launchAtLogin = !val }
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 40).padding(.vertical, 20)
    }

    // MARK: - Page 3

    private var completionPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.green)

            Text("准备就绪！").font(.title.weight(.bold))

            VStack(spacing: 8) {
                Text("• 点击菜单栏图标查看和管理排程")
                Text("• 鼠标悬停在 Mac 刘海快速预览任务")
                Text("• 任务结束时全屏提醒，保持专注")
            }
            .font(.body).foregroundStyle(.secondary)

            Text("现在开始安排你的一天吧 🎯")
                .font(.headline).foregroundStyle(BrandColors.accent)
        }
        .padding(.horizontal, 40).padding(.vertical, 20)
    }

    private func finish() {
        hasCompletedOnboarding = true
        if launchAtLogin { try? LaunchManager.setLoginItemEnabled(true) }
        onComplete()
    }
}

#if DEBUG
#Preview {
    OnboardingView(onComplete: {})
}
#endif
