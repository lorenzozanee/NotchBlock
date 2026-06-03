import SwiftUI

/// Configuration view for WeChat notification integration (WxPusher / Enterprise WeChat Webhook).
/// Tokens stored in macOS Keychain; enabled state + service type in UserDefaults.
struct WeChatSettingsView: View {
    @ObservedObject var notifier: WeChatNotifier
    @Environment(\.dismiss) private var dismiss

    @State private var appToken = ""
    @State private var uid = ""
    @State private var webhookURL = ""
    @State private var showSaved = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            formContent
            Divider()
            footerBar
        }
        .frame(width: 420)
        .onAppear { loadExisting() }
    }

    private var headerBar: some View {
        HStack {
            Text("微信通知设置").font(.headline)
            Spacer()
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(
                get: { notifier.isEnabled },
                set: { notifier.setEnabled($0) }
            )) { Text("启用微信通知").fontWeight(.medium) }

            Divider()

            Picker("推送服务", selection: $notifier.serviceType) {
                ForEach(WeChatNotifier.ServiceType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: notifier.serviceType) { _, _ in
                UserDefaults.standard.set(notifier.serviceType.rawValue, forKey: "wechatNotifier.serviceType")
            }

            Divider()

            if notifier.serviceType == .wxpusher {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AppToken").font(.caption).foregroundStyle(.secondary)
                        SecureField("AT_xxx", text: $appToken).textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UID").font(.caption).foregroundStyle(.secondary)
                        TextField("UID_xxx", text: $uid).textFieldStyle(.roundedBorder)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Webhook URL").font(.caption).foregroundStyle(.secondary)
                        TextField("https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=...", text: $webhookURL)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            helpSection
        }.padding(20)
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("如何获取?").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if notifier.serviceType == .wxpusher {
                Text("1. 访问 wxpusher.zjiecode.com\n2. 扫码创建应用 → 获取 AppToken\n3. 扫描关注二维码 → 获取 UID")
                    .font(.caption).foregroundStyle(.tertiary)
            } else {
                Text("1. 注册企业微信 → 创建群聊\n2. 添加群机器人 → 复制 Webhook URL")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var footerBar: some View {
        HStack {
            if showSaved { Text("✅ 已保存").font(.caption).foregroundStyle(.green) }
            Spacer()
            Button("取消") { dismiss() }
            Button("保存") { save() }.buttonStyle(.borderedProminent)
        }.padding(.horizontal, 20).padding(.vertical, 12)
    }

    private func loadExisting() {
        appToken = notifier.loadKeychain(key: "com.notchblock.wxpusher.appToken") ?? ""
        uid = notifier.loadKeychain(key: "com.notchblock.wxpusher.uid") ?? ""
        webhookURL = notifier.loadKeychain(key: "com.notchblock.wecom.webhook") ?? ""
    }

    private func save() {
        switch notifier.serviceType {
        case .wxpusher:
            guard !appToken.isEmpty, !uid.isEmpty else { return }
            notifier.saveWxPusherConfig(appToken: appToken, uid: uid)
        case .wecomWebhook:
            guard !webhookURL.isEmpty else { return }
            notifier.saveWeComWebhook(url: webhookURL)
        }
        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSaved = false }
    }
}

#if DEBUG
#Preview { WeChatSettingsView(notifier: WeChatNotifier()) }
#endif
