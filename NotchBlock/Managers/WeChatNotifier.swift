import Foundation
import Security
import OSLog

private let wechatLogger = Logger(subsystem: "com.notchblock.app", category: "WeChat")

/// Sends time-block-end notifications via WeChat using WxPusher or Enterprise WeChat Webhook.
///
/// WxPusher (recommended): Free REST API, no server needed, messages arrive via WeChat Official Account.
/// Enterprise WeChat Webhook (fallback): Messages to Enterprise WeChat group bot.
///
/// Tokens stored in macOS Keychain for security (AC 5.0).
final class WeChatNotifier: ObservableObject {
    enum ServiceType: String, CaseIterable {
        case wxpusher = "WxPusher"
        case wecomWebhook = "企业微信 Webhook"
    }

    @Published var isEnabled = false
    @Published var serviceType: ServiceType = .wxpusher

    // MARK: - Keychain Keys

    enum KeychainKey {
        static let wxpusherToken = "com.notchblock.wxpusher.appToken"
        static let wxpusherUID = "com.notchblock.wxpusher.uid"
        static let wecomWebhook = "com.notchblock.wecom.webhook"
    }

    // MARK: - Configuration

    func loadConfiguration() {
        isEnabled = UserDefaults.standard.bool(forKey: "wechatNotifier.enabled")
        serviceType = ServiceType(rawValue: UserDefaults.standard.string(forKey: "wechatNotifier.serviceType") ?? "") ?? .wxpusher
    }

    func saveWxPusherConfig(appToken: String, uid: String) {
        _ = saveKeychain(key: KeychainKey.wxpusherToken, value: appToken)
        _ = saveKeychain(key: KeychainKey.wxpusherUID, value: uid)
        UserDefaults.standard.set(ServiceType.wxpusher.rawValue, forKey: "wechatNotifier.serviceType")
    }

    func saveWeComWebhook(url: String) {
        _ = saveKeychain(key: KeychainKey.wecomWebhook, value: url)
        UserDefaults.standard.set(ServiceType.wecomWebhook.rawValue, forKey: "wechatNotifier.serviceType")
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "wechatNotifier.enabled")
    }

    // MARK: - Send Notification

    func sendBlockEndedNotification(for block: TimeBlock) {
        guard isEnabled else { return }
        let message = "⏰ [NotchBlock]「\(block.title)」的时间到了！"
        switch serviceType {
        case .wxpusher:
            sendViaWxPusher(content: message, summary: "任务提醒")
        case .wecomWebhook:
            sendViaWeComWebhook(content: message)
        }
    }

    func sendMissedNotification(for block: TimeBlock) {
        guard isEnabled else { return }
        let message = "⚠️ [NotchBlock]「\(block.title)」已超时，自动标记为未完成。"
        switch serviceType {
        case .wxpusher:
            sendViaWxPusher(content: message, summary: "超时提醒")
        case .wecomWebhook:
            sendViaWeComWebhook(content: message)
        }
    }

    // MARK: - WxPusher

    private func sendViaWxPusher(content: String, summary: String) {
        guard let appToken = loadKeychain(key: KeychainKey.wxpusherToken),
              let uid = loadKeychain(key: KeychainKey.wxpusherUID),
              !appToken.isEmpty, !uid.isEmpty
        else { return }

        guard let url = URL(string: "https://wxpusher.zjiecode.com/api/send/message") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "appToken": appToken, "content": content,
            "summary": summary, "contentType": 1, "uids": [uid]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            wechatLogger.error("Failed to serialize request body")
            return
        }
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                wechatLogger.error("WxPusher send failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Enterprise WeChat Webhook

    private func sendViaWeComWebhook(content: String) {
        guard let webhookURL = loadKeychain(key: KeychainKey.wecomWebhook),
              !webhookURL.isEmpty, let url = URL(string: webhookURL)
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["msgtype": "text", "text": ["content": content]]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            wechatLogger.error("Failed to serialize request body")
            return
        }
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                wechatLogger.error("WeCom send failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Keychain

    private func saveKeychain(key: String, value: String) -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8)
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    func loadKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
