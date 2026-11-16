import Foundation
import Observation
import OSLog
import Security

private let wechatLogger = Logger(subsystem: "com.notchblock.app", category: "WeChat")

/// Sends time-block alerts via WeChat using WxPusher or Enterprise WeChat Webhook.
/// Tokens are stored in macOS Keychain; preferences are stored in UserDefaults.
@Observable
@MainActor
final class WeChatNotifier {
    enum ServiceType: String, CaseIterable, Equatable, Sendable {
        case wxpusher = "WxPusher"
        case wecomWebhook = "企业微信 Webhook"
    }

    enum NotifierError: LocalizedError {
        case missingCredentials
        case invalidEndpoint
        case serverRejected(String)

        var errorDescription: String? {
            switch self {
            case .missingCredentials: return "请先填写完整的推送凭证"
            case .invalidEndpoint: return "Webhook URL 格式无效，请使用 https:// 开头"
            case .serverRejected(let message): return "发送失败：\(message)"
            }
        }
    }

    var isEnabled = false
    var serviceType: ServiceType = .wxpusher

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let enabledKey = "wechatNotifier.enabled"
    @ObservationIgnored private let serviceTypeKey = "wechatNotifier.serviceType"

    // MARK: - Keychain Keys

    enum KeychainKey {
        static let wxpusherToken = "com.notchblock.wxpusher.appToken"
        static let wxpusherUID = "com.notchblock.wxpusher.uid"
        static let wecomWebhook = "com.notchblock.wecom.webhook"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadConfiguration()
    }

    // MARK: - Configuration

    func loadConfiguration() {
        isEnabled = userDefaults.bool(forKey: enabledKey)
        serviceType = ServiceType(rawValue: userDefaults.string(forKey: serviceTypeKey) ?? "") ?? .wxpusher
    }

    func saveWxPusherConfig(appToken: String, uid: String) {
        _ = saveKeychain(key: KeychainKey.wxpusherToken, value: appToken)
        _ = saveKeychain(key: KeychainKey.wxpusherUID, value: uid)
        setServiceType(.wxpusher)
    }

    func saveWeComWebhook(url: String) {
        _ = saveKeychain(key: KeychainKey.wecomWebhook, value: url)
        setServiceType(.wecomWebhook)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: enabledKey)
    }

    func setServiceType(_ type: ServiceType) {
        serviceType = type
        userDefaults.set(type.rawValue, forKey: serviceTypeKey)
    }

    // MARK: - Send Notifications

    func sendBlockEndedNotification(for block: TimeBlock) {
        guard isEnabled else { return }
        let message = "⏰ [NotchBlock]「\(block.title)」的时间到了！"
        let currentService = serviceType
        Task {
            do {
                try await dispatchMessage(message, summary: "任务提醒", service: currentService)
            } catch {
                wechatLogger.error("Block ended push failed: \(error.localizedDescription)")
            }
        }
    }

    func sendMissedNotification(for block: TimeBlock) {
        guard isEnabled else { return }
        let message = "⚠️ [NotchBlock]「\(block.title)」已超时，自动标记为未完成。"
        let currentService = serviceType
        Task {
            do {
                try await dispatchMessage(message, summary: "超时提醒", service: currentService)
            } catch {
                wechatLogger.error("Missed block push failed: \(error.localizedDescription)")
            }
        }
    }

    func sendTestNotification() async throws {
        try await dispatchMessage(
            "✅ [NotchBlock] 微信通知测试成功，任务提醒将推送到这里。",
            summary: "测试通知",
            service: serviceType
        )
    }

    private func dispatchMessage(_ content: String, summary: String, service: ServiceType) async throws {
        switch service {
        case .wxpusher:
            try await sendViaWxPusher(content: content, summary: summary)
        case .wecomWebhook:
            try await sendViaWeComWebhook(content: content)
        }
    }

    // MARK: - WxPusher

    private func sendViaWxPusher(content: String, summary: String) async throws {
        guard let appToken = loadKeychain(key: KeychainKey.wxpusherToken),
              let uid = loadKeychain(key: KeychainKey.wxpusherUID),
              !appToken.isEmpty, !uid.isEmpty
        else { throw NotifierError.missingCredentials }

        guard let url = URL(string: "https://wxpusher.zjiecode.com/api/send/message") else {
            throw NotifierError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "appToken": appToken,
            "content": content,
            "summary": summary,
            "contentType": 1,
            "uids": [uid],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NotifierError.serverRejected("HTTP 请求异常")
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["code"] as? Int, code != 1000 {
            let msg = (json["msg"] as? String) ?? "code \(code)"
            wechatLogger.error("WxPusher rejected: \(msg)")
            throw NotifierError.serverRejected(msg)
        }
    }

    // MARK: - Enterprise WeChat Webhook

    private func sendViaWeComWebhook(content: String) async throws {
        guard let webhookURL = loadKeychain(key: KeychainKey.wecomWebhook),
              !webhookURL.isEmpty
        else { throw NotifierError.missingCredentials }

        guard let url = URL(string: webhookURL), url.scheme?.lowercased() == "https" else {
            throw NotifierError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["msgtype": "text", "text": ["content": content]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NotifierError.serverRejected("HTTP 请求异常")
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errcode = json["errcode"] as? Int, errcode != 0 {
            let errmsg = (json["errmsg"] as? String) ?? "errcode \(errcode)"
            wechatLogger.error("WeCom rejected: \(errmsg)")
            throw NotifierError.serverRejected(errmsg)
        }
    }

    // MARK: - Keychain

    private func saveKeychain(key: String, value: String) -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard !value.isEmpty else { return true }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    func loadKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
