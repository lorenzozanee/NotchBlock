import Foundation
import AppKit
import UserNotifications
import OSLog

private let log = Logger(subsystem: "com.notchblock.app", category: "Update")

/// Auto-update checker via GitHub Releases API. No Sparkle dependency.
/// Checks every 6h. Shows "What's New" on first launch after version change.
final class UpdateChecker {
    private let repo = "lorenzozanee/NotchBlock"
    private let session = URLSession.shared
    private var autoCheckTimer: Timer?

    @Published var updateAvailable = false
    @Published var latestVersion: String?

    private let lastVersionKey = "lastLaunchedVersion"

    // MARK: - Auto Check

    func startAutoCheck(interval: TimeInterval = 21600) {
        checkForUpdates(showNoUpdateAlert: false)
        autoCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpdates(showNoUpdateAlert: false)
        }
    }

    /// Returns changelog text if version changed since last launch, nil otherwise.
    func checkWhatsNew() -> String? {
        let current = currentVersion
        let last = UserDefaults.standard.string(forKey: lastVersionKey) ?? ""
        UserDefaults.standard.set(current, forKey: lastVersionKey)
        if last.isEmpty || last == current { return nil }
        return changelogForVersion(current)
    }

    // MARK: - GitHub API

    func checkForUpdates(showNoUpdateAlert: Bool = false) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.timeoutInterval = 10

        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self, let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String
            else {
                if showNoUpdateAlert { DispatchQueue.main.async { self?.showNoUpdate() } }
                return
            }
            let remote = tag.replacingOccurrences(of: "v", with: "")
            DispatchQueue.main.async {
                if self.isNewer(remote, than: self.currentVersion) {
                    self.updateAvailable = true
                    self.latestVersion = tag
                    self.showUpdateFound(tag: tag, url: htmlURL, body: json["body"] as? String)
                } else if showNoUpdateAlert {
                    self.showNoUpdate()
                }
            }
        }.resume()
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(URL(string: "https://github.com/\(repo)/releases")!)
    }

    // MARK: - Version

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private func isNewer(_ a: String, than b: String) -> Bool {
        let aP = a.split(separator: ".").compactMap { Int($0) }
        let bP = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aP.count, bP.count) {
            let av = i < aP.count ? aP[i] : 0
            let bv = i < bP.count ? bP[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }

    // MARK: - Changelog

    private func changelogForVersion(_ version: String) -> String? {
        guard let path = Bundle.main.path(forResource: "CHANGELOG", ofType: "md"),
              let content = try? String(contentsOfFile: path, encoding: .utf8)
        else { return nil }
        // Extract section for this version: "## [X.Y.Z]" until next "## ["
        let marker = "## [\(version)]"
        guard let start = content.range(of: marker) else { return nil }
        let tail = content[start.upperBound...]
        if let end = tail.range(of: "\n## [") {
            return String(tail[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - UI

    private func showUpdateFound(tag: String, url: String, body: String?) {
        log.info("Update available: \(tag) (current: v\(self.currentVersion))")
        let c = UNMutableNotificationContent()
        c.title = "NotchBlock \(tag) 可用"
        c.body = body?.split(separator: "\n").prefix(2).joined(separator: " ") ?? "新版本已发布"
        c.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "update-\(tag)", content: c,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)))
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = "发现新版本 \(tag)"
            a.informativeText = "当前: v\(self.currentVersion)\n前往 GitHub 下载？"
            a.alertStyle = .informational
            a.addButton(withTitle: "前往下载")
            a.addButton(withTitle: "稍后提醒")
            if a.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: url)!)
            }
        }
    }

    private func showNoUpdate() {
        let a = NSAlert()
        a.messageText = "已是最新版本"
        a.informativeText = "NotchBlock v\(currentVersion)"
        a.alertStyle = .informational
        a.addButton(withTitle: "确定")
        a.runModal()
    }
}
