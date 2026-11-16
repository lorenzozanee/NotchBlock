import AppKit
import SwiftUI

/// Native macOS Settings window with General, WeChat Notifications, and Updates tabs.
struct SettingsView: View {
    let weChatNotifier: WeChatNotifier
    let updateChecker: UpdateChecker

    @State private var selectedTab: SettingsTab = .general

    private enum SettingsTab: String, CaseIterable, Hashable {
        case general = "通用"
        case wechat = "微信通知"
        case updates = "更新"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("偏好设置")
                    .font(.headline)
                    .foregroundStyle(BrandColors.textPrimary)
                Spacer()
                MinimalSegmentedControl(
                    options: SettingsTab.allCases.map { ($0, $0.rawValue) },
                    selection: $selectedTab
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            MinimalHairline()

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab()
                case .wechat:
                    WeChatSettingsView(notifier: weChatNotifier)
                case .updates:
                    UpdatesSettingsTab(updateChecker: updateChecker)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 460, height: 420)
        .background {
            FrostedGlassBackground(
                material: .underWindowBackground,
                tint: BrandColors.canvasGlass
            )
            .ignoresSafeArea()
        }
        .tint(BrandColors.accentText)
        .onDisappear {
            Task { @MainActor in
                await Task.yield()
                let hasVisibleMainWindow = NSApp.windows.contains { window in
                    window.isVisible && window.canBecomeMain
                }
                if !hasVisibleMainWindow {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @AppStorage("menuBarIconStyle") private var iconStyle = MenuBarIconStyle.timer.rawValue
    @AppStorage("showTimeInMenuBar") private var showTimeInMenuBar = true
    @AppStorage("alertSoundName") private var alertSoundName = "Glass"
    @AppStorage("focusStartHour") private var focusStartHour = 9
    @AppStorage("focusEndHour") private var focusEndHour = 18

    @State private var launchAtLogin = false
    @State private var loginErrorMessage: String?

    var body: some View {
        Form {
            Section("启动与菜单栏") {
                Toggle("开机自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchManager.setLoginItemEnabled(enabled)
                            loginErrorMessage = nil
                        } catch {
                            loginErrorMessage = "无法更新开机启动：\(error.localizedDescription)"
                            launchAtLogin = LaunchManager.isLoginItemEnabled
                        }
                    }

                if let loginErrorMessage {
                    Text(loginErrorMessage)
                        .font(.caption)
                        .foregroundStyle(BrandColors.missed)
                }

                Picker("菜单栏图标", selection: $iconStyle) {
                    ForEach(MenuBarIconStyle.allCases, id: \.rawValue) { style in
                        Label(style.label, systemImage: style.systemImage)
                            .tag(style.rawValue)
                    }
                }

                Toggle("菜单栏显示剩余时间", isOn: $showTimeInMenuBar)
            }

            Section("专注与提醒") {
                Picker("每日开始时间", selection: $focusStartHour) {
                    ForEach(0..<23, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .onChange(of: focusStartHour) { _, newStart in
                    if focusEndHour <= newStart {
                        focusEndHour = min(24, newStart + 1)
                    }
                }

                Picker("每日结束时间", selection: $focusEndHour) {
                    ForEach(1...24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .onChange(of: focusEndHour) { _, newEnd in
                    if newEnd <= focusStartHour {
                        focusStartHour = max(0, newEnd - 1)
                    }
                }

                HStack {
                    Picker("提醒声音", selection: $alertSoundName) {
                        ForEach(OverlayWindowController.availableSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Button("试听") {
                        NSSound(named: alertSoundName)?.play()
                    }
                    .buttonStyle(MinimalSecondaryButtonStyle(horizontalPadding: 10, verticalPadding: 4))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            launchAtLogin = LaunchManager.isLoginItemEnabled
        }
    }
}

// MARK: - Updates

private struct UpdatesSettingsTab: View {
    let updateChecker: UpdateChecker

    var body: some View {
        Form {
            Section("版本信息") {
                LabeledContent("当前版本") {
                    Text("v\(updateChecker.currentVersion)")
                        .monospacedDigit()
                        .foregroundStyle(BrandColors.textSecondary)
                }

                if let latest = updateChecker.latestVersion, updateChecker.updateAvailable {
                    LabeledContent("可用版本") {
                        Text(latest)
                            .foregroundStyle(BrandColors.accentText)
                            .monospacedDigit()
                    }
                }
            }

            Section("软件更新") {
                if updateChecker.isDownloading || updateChecker.isInstalling {
                    VStack(alignment: .leading, spacing: 6) {
                        if updateChecker.isInstalling {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在安装更新...")
                                .font(.caption)
                                .foregroundStyle(BrandColors.textSecondary)
                        } else {
                            ProgressView(value: updateChecker.downloadProgress)
                            Text("正在下载更新 \(Int(updateChecker.downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(BrandColors.textSecondary)
                        }
                    }
                } else {
                    HStack {
                        Button(updateChecker.updateAvailable ? "下载并安装" : "检查更新") {
                            if updateChecker.updateAvailable {
                                updateChecker.downloadAndInstall()
                            } else {
                                updateChecker.checkForUpdates(showNoUpdateAlert: true)
                            }
                        }
                        .buttonStyle(MinimalPrimaryButtonStyle(horizontalPadding: 12, verticalPadding: 5))
                        .disabled(updateChecker.isChecking)

                        if updateChecker.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Spacer()

                        Button("Releases") {
                            updateChecker.openReleasesPage()
                        }
                        .buttonStyle(MinimalSecondaryButtonStyle(horizontalPadding: 12, verticalPadding: 5))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

#if DEBUG
#Preview {
    SettingsView(weChatNotifier: WeChatNotifier(), updateChecker: UpdateChecker())
}
#endif
