import Foundation
import AppKit
import UserNotifications
import OSLog

private let log = Logger(subsystem: "com.notchblock.app", category: "Update")

/// Auto-update via GitHub Releases API. Detects new versions, downloads DMG,
/// mounts, copies .app to /Applications, and relaunches. No Sparkle dependency.
final class UpdateChecker {
    private let repo = "lorenzozanee/NotchBlock"
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        return URLSession(configuration: c)
    }()
    private var autoCheckTimer: Timer?
    private var downloadTask: URLSessionDownloadTask?

    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadProgress: Double = 0

    private let lastVersionKey = "lastLaunchedVersion"
    private let skipVersionKey = "skippedVersion"

    // MARK: - Auto Check

    func startAutoCheck(interval: TimeInterval = 21600) {
        checkForUpdates(showNoUpdateAlert: false)
        autoCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpdates(showNoUpdateAlert: false)
        }
    }

    func checkWhatsNew() -> String? {
        let current = currentVersion
        let last = UserDefaults.standard.string(forKey: lastVersionKey) ?? ""
        UserDefaults.standard.set(current, forKey: lastVersionKey)
        if last.isEmpty || last == current { return nil }
        return changelogForVersion(current)
    }

    // MARK: - GitHub API

    /// Returns (tag, htmlURL, dmgURL) if update available
    private var latestReleaseCache: (tag: String, htmlURL: String, dmgURL: String?)?

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
            let skipped = UserDefaults.standard.string(forKey: self.skipVersionKey) ?? ""

            // Extract DMG asset URL
            let dmgURL: String? = {
                guard let assets = json["assets"] as? [[String: Any]] else { return nil }
                return assets.first(where: {
                    ($0["name"] as? String)?.hasSuffix(".dmg") == true
                })?["browser_download_url"] as? String
            }()

            DispatchQueue.main.async {
                if self.isNewer(remote, than: self.currentVersion), remote != skipped {
                    self.updateAvailable = true
                    self.latestVersion = tag
                    self.latestReleaseCache = (tag, htmlURL, dmgURL)
                    self.showUpdateFound(tag: tag, dmgAvailable: dmgURL != nil)
                } else if showNoUpdateAlert {
                    self.showNoUpdate()
                }
            }
        }.resume()
    }

    // MARK: - Download & Install

    func downloadAndInstall() {
        guard let cache = latestReleaseCache, let dmgURL = cache.dmgURL,
              let url = URL(string: dmgURL) else {
            // Fallback: open releases page
            NSWorkspace.shared.open(URL(string: "https://github.com/\(repo)/releases")!)
            return
        }

        downloadProgress = 0
        let task = session.downloadTask(with: url) { [weak self] localURL, _, error in
            guard let self, let localURL = localURL, error == nil else {
                DispatchQueue.main.async { self?.showDownloadFailed() }
                return
            }
            self.installDMG(at: localURL, version: cache.tag)
        }
        downloadTask = task
        task.resume()
    }

    private func installDMG(at localURL: URL, version: String) {
        let mountPoint = "/Volumes/NotchBlock-\(version)"
        // Unmount if already mounted
        Process.launchedProcess(launchPath: "/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"]).waitUntilExit()

        // Mount DMG
        let mount = Process.launchedProcess(launchPath: "/usr/bin/hdiutil",
            arguments: ["attach", localURL.path, "-mountpoint", mountPoint, "-nobrowse", "-quiet"])
        mount.waitUntilExit()

        guard mount.terminationStatus == 0 else {
            DispatchQueue.main.async { self.showDownloadFailed() }
            return
        }

        // Find .app in mounted volume
        let fm = FileManager.default
        guard let appName = try? fm.contentsOfDirectory(atPath: mountPoint).first(where: { $0.hasSuffix(".app") }) else {
            Process.launchedProcess(launchPath: "/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"]).waitUntilExit()
            DispatchQueue.main.async { self.showDownloadFailed() }
            return
        }

        let sourceApp = "\(mountPoint)/\(appName)"
        let targetApp = "/Applications/\(appName)"

        // Replace existing app
        if fm.fileExists(atPath: targetApp) {
            try? fm.removeItem(atPath: targetApp)
        }
        do {
            try fm.copyItem(atPath: sourceApp, toPath: targetApp)
        } catch {
            Process.launchedProcess(launchPath: "/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"]).waitUntilExit()
            DispatchQueue.main.async { self.showDownloadFailed() }
            return
        }

        // Unmount
        Process.launchedProcess(launchPath: "/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"]).waitUntilExit()

        // Clean up downloaded DMG
        try? fm.removeItem(at: localURL)

        // Prompt relaunch
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = "更新已安装"
            a.informativeText = "NotchBlock \(version) 已安装到 /Applications。\n立即重启以使用新版本？"
            a.alertStyle = .informational
            a.addButton(withTitle: "立即重启")
            a.addButton(withTitle: "稍后")
            if a.runModal() == .alertFirstButtonReturn {
                self.relaunch(targetApp)
            }
        }
    }

    private func relaunch(_ appPath: String) {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [appPath]
        task.launch()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
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
        let marker = "## [\(version)]"
        guard let start = content.range(of: marker) else { return nil }
        let tail = content[start.upperBound...]
        if let end = tail.range(of: "\n## [") {
            return String(tail[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - UI

    private func showUpdateFound(tag: String, dmgAvailable: Bool) {
        log.info("Update available: \(tag) (current: v\(self.currentVersion))")

        let c = UNMutableNotificationContent()
        c.title = "NotchBlock \(tag) 可用"
        c.body = "新版本已发布，点击查看并安装。"
        c.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "update-\(tag)", content: c,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)))

        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = "发现新版本 \(tag)"
            a.informativeText = dmgAvailable
                ? "当前: v\(self.currentVersion)\n\n选择\"自动更新\"将自动下载并安装新版本。"
                : "当前: v\(self.currentVersion)\n\n无法获取自动更新包，是否前往 GitHub 手动下载？"
            a.alertStyle = .informational
            if dmgAvailable {
                a.addButton(withTitle: "自动更新")
                a.addButton(withTitle: "稍后提醒")
                a.addButton(withTitle: "跳过此版本")
            } else {
                a.addButton(withTitle: "前往下载")
                a.addButton(withTitle: "稍后提醒")
            }
            let result = a.runModal()
            if dmgAvailable {
                switch result {
                case .alertFirstButtonReturn: self.downloadAndInstall()
                case .alertThirdButtonReturn:
                    UserDefaults.standard.set(tag.replacingOccurrences(of: "v", with: ""), forKey: self.skipVersionKey)
                default: break
                }
            } else if result == .alertFirstButtonReturn {
                self.openReleasesPage()
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

    private func showDownloadFailed() {
        let a = NSAlert()
        a.messageText = "更新失败"
        a.informativeText = "自动下载失败，请前往 GitHub 手动下载。"
        a.alertStyle = .warning
        a.addButton(withTitle: "前往下载")
        a.addButton(withTitle: "取消")
        if a.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/\(repo)/releases")!)
        }
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(URL(string: "https://github.com/\(repo)/releases")!)
    }
}
