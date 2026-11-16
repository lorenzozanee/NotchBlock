import SwiftUI

/// Configuration form for WeChat notification integration (WxPusher / Enterprise WeChat Webhook).
struct WeChatSettingsView: View {
    @Bindable var notifier: WeChatNotifier

    @State private var appToken = ""
    @State private var uid = ""
    @State private var webhookURL = ""
    @State private var statusMessage: String?
    @State private var isStatusError = false
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                Toggle("启用微信通知", isOn: Binding(
                    get: { notifier.isEnabled },
                    set: { notifier.setEnabled($0) }
                ))

                Picker("推送服务", selection: Binding(
                    get: { notifier.serviceType },
                    set: { notifier.setServiceType($0) }
                )) {
                    ForEach(WeChatNotifier.ServiceType.allCases, id: \.self) { service in
                        Text(service.rawValue).tag(service)
                    }
                }
            }

            Section("凭证配置") {
                if notifier.serviceType == .wxpusher {
                    SecureField("AppToken (AT_xxx)", text: $appToken)
                    TextField("UID (UID_xxx)", text: $uid)
                } else {
                    TextField("Webhook URL (https://...)", text: $webhookURL)
                }

                HStack {
                    Button("发送测试") {
                        Task { await sendTest() }
                    }
                    .buttonStyle(MinimalSecondaryButtonStyle(horizontalPadding: 12, verticalPadding: 5))
                    .disabled(!isInputValid || isTesting)

                    Spacer()

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(isStatusError ? BrandColors.missed : BrandColors.accentText)
                    }

                    Button("保存凭证") {
                        save()
                    }
                    .buttonStyle(MinimalPrimaryButtonStyle(horizontalPadding: 12, verticalPadding: 5))
                    .disabled(!isInputValid)
                }
            }

            Section("获取指引") {
                if notifier.serviceType == .wxpusher {
                    Text("1. 访问 wxpusher.zjiecode.com 创建应用获取 AppToken\n2. 扫描关注二维码获取个人 UID")
                        .font(.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                } else {
                    Text("在企业微信群聊中添加群机器人，复制 HTTPS Webhook 地址。")
                        .font(.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear(perform: loadExisting)
        .task(id: statusMessage) {
            guard statusMessage != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            statusMessage = nil
        }
    }

    private var isInputValid: Bool {
        switch notifier.serviceType {
        case .wxpusher:
            return !appToken.trimmingCharacters(in: .whitespaces).isEmpty
                && !uid.trimmingCharacters(in: .whitespaces).isEmpty
        case .wecomWebhook:
            let trimmed = webhookURL.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("https://") && URL(string: trimmed) != nil
        }
    }

    private func loadExisting() {
        appToken = notifier.loadKeychain(key: WeChatNotifier.KeychainKey.wxpusherToken) ?? ""
        uid = notifier.loadKeychain(key: WeChatNotifier.KeychainKey.wxpusherUID) ?? ""
        webhookURL = notifier.loadKeychain(key: WeChatNotifier.KeychainKey.wecomWebhook) ?? ""
    }

    private func save() {
        switch notifier.serviceType {
        case .wxpusher:
            notifier.saveWxPusherConfig(
                appToken: appToken.trimmingCharacters(in: .whitespaces),
                uid: uid.trimmingCharacters(in: .whitespaces)
            )
        case .wecomWebhook:
            notifier.saveWeComWebhook(url: webhookURL.trimmingCharacters(in: .whitespaces))
        }
        showFeedback("已保存到钥匙串", isError: false)
    }

    private func sendTest() async {
        save()
        isTesting = true
        defer { isTesting = false }
        do {
            try await notifier.sendTestNotification()
            showFeedback("测试消息已发送", isError: false)
        } catch {
            showFeedback(error.localizedDescription, isError: true)
        }
    }

    private func showFeedback(_ message: String, isError: Bool) {
        statusMessage = message
        isStatusError = isError
    }
}

#if DEBUG
#Preview {
    WeChatSettingsView(notifier: WeChatNotifier())
        .frame(width: 440, height: 360)
}
#endif
