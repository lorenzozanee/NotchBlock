import AppKit
import Foundation
import Observation
import OSLog
import UserNotifications

private let updateLog = Logger(subsystem: "com.notchblock.app", category: "Update")

/// Auto-update via GitHub Releases API. Detects new versions, downloads DMG,
/// verifies integrity, copies .app to /Applications, and relaunches.
@Observable
@MainActor
final class UpdateChecker {
    private let repo = "lorenzozanee/NotchBlock"
    private let userDefaults: UserDefaults
    private let lastVersionKey = "lastLaunchedVersion"
    private let skipVersionKey = "skippedVersion"

    private(set) var updateAvailable = false
    private(set) var latestVersion: String?
    private(set) var downloadProgress: Double = 0
    private(set) var isDownloading = false
    private(set) var isInstalling = false
    private(set) var isChecking = false

    @ObservationIgnored nonisolated(unsafe) private var autoCheckTask: Task<Void, Never>?
    @ObservationIgnored private var downloadSession: URLSession?
    @ObservationIgnored nonisolated(unsafe) private var downloadTask: URLSessionDownloadTask?
    @ObservationIgnored private var latestReleaseCache: (tag: String, htmlURL: String, dmgURL: String?)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    deinit {
        autoCheckTask?.cancel()
        downloadTask?.cancel()
    }

    // MARK: - Auto Check

    func startAutoCheck(interval: TimeInterval = 21600) {
        autoCheckTask?.cancel()
        autoCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performUpdateCheck(showNoUpdateAlert: false)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopAutoCheck() {
        autoCheckTask?.cancel()
        autoCheckTask = nil
    }

    func checkWhatsNew() -> String? {
        let current = currentVersion
        let last = userDefaults.string(forKey: lastVersionKey) ?? ""
        userDefaults.set(current, forKey: lastVersionKey)
        let cleanLast = Self.stripLeadingV(last)
        let cleanCurrent = Self.stripLeadingV(current)
        if cleanLast.isEmpty || cleanLast == cleanCurrent { return nil }
        return changelogForVersion(current)
    }

    // MARK: - GitHub API

    func checkForUpdates(showNoUpdateAlert: Bool = false) {
        Task { [weak self] in
            await self?.performUpdateCheck(showNoUpdateAlert: showNoUpdateAlert)
        }
    }

    func performUpdateCheck(showNoUpdateAlert: Bool = false) async {
        guard !isChecking else { return }
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        isChecking = true
        defer { isChecking = false }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 403 || http.statusCode == 429 {
                    updateLog.warning("GitHub API rate limited: HTTP \(http.statusCode)")
                    if showNoUpdateAlert { showRateLimited() }
                    return
                }
                guard http.statusCode == 200 else {
                    updateLog.warning("GitHub API returned HTTP \(http.statusCode)")
                    if showNoUpdateAlert { showNoUpdate() }
                    return
                }
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String
            else {
                if showNoUpdateAlert { showNoUpdate() }
                return
            }

            let remote = Self.stripLeadingV(tag)
            let skipped = userDefaults.string(forKey: skipVersionKey) ?? ""

            let dmgURL: String? = {
                guard let assets = json["assets"] as? [[String: Any]] else { return nil }
                return assets.compactMap { asset -> String? in
                    guard let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                          let rawURL = asset["browser_download_url"] as? String,
                          let parsed = URL(string: rawURL),
                          parsed.scheme?.lowercased() == "https"
                    else { return nil }
                    return rawURL
                }.first
            }()

            if Self.isNewer(remote, than: currentVersion), remote != skipped {
                updateAvailable = true
                latestVersion = tag
                latestReleaseCache = (tag, htmlURL, dmgURL)
                showUpdateFound(tag: tag, dmgAvailable: dmgURL != nil)
            } else if showNoUpdateAlert {
                showNoUpdate()
            }
        } catch {
            updateLog.debug("Update check failed: \(error.localizedDescription)")
            if showNoUpdateAlert { showNoUpdate() }
        }
    }

    // MARK: - Download & Install

    func downloadAndInstall() {
        guard !isDownloading, !isInstalling else { return }
        guard let cache = latestReleaseCache,
              let dmgURL = cache.dmgURL,
              let url = URL(string: dmgURL),
              url.scheme?.lowercased() == "https" else {
            openReleasesPage()
            return
        }

        isDownloading = true
        downloadProgress = 0
        downloadTask?.cancel()
        downloadSession?.invalidateAndCancel()

        let delegate = DownloadDelegate(
            onProgress: { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.downloadProgress = progress
                }
            },
            onComplete: { [weak self] localURL, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isDownloading = false
                    self.downloadSession?.finishTasksAndInvalidate()
                    self.downloadSession = nil
                    self.downloadTask = nil
                    guard let localURL, error == nil else {
                        if (error as? URLError)?.code != .cancelled {
                            self.showDownloadFailed()
                        }
                        return
                    }
                    await self.installDMG(at: localURL, version: cache.tag)
                }
            }
        )

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadSession = session
        let task = session.downloadTask(with: url)
        downloadTask = task
        task.resume()
    }

    private func installDMG(at localURL: URL, version: String) async {
        isInstalling = true
        defer { isInstalling = false }

        // Move downloaded temp file to a stable temporary path before async work
        let tempDMG = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchBlock-\(UUID().uuidString).dmg")
        do {
            try FileManager.default.moveItem(at: localURL, to: tempDMG)
        } catch {
            updateLog.error("Failed to stage downloaded DMG: \(error.localizedDescription)")
            showDownloadFailed()
            return
        }

        let installedAppPath: String? = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let mountPoint = "/Volumes/NotchBlock-Update-\(UUID().uuidString)"

            defer {
                _ = Self.runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"])
                try? fm.removeItem(at: tempDMG)
            }

            let verifyStatus = Self.runProcess("/usr/bin/hdiutil", arguments: ["verify", tempDMG.path])
            guard verifyStatus == 0 else {
                updateLog.warning("DMG integrity check failed for \(tempDMG.path)")
                return nil
            }

            let mountStatus = Self.runProcess(
                "/usr/bin/hdiutil",
                arguments: ["attach", tempDMG.path, "-mountpoint", mountPoint, "-nobrowse", "-quiet"]
            )
            guard mountStatus == 0 else { return nil }

            guard let appName = try? fm.contentsOfDirectory(atPath: mountPoint).first(where: { $0.hasSuffix(".app") }) else {
                return nil
            }

            let sourceApp = URL(fileURLWithPath: mountPoint).appendingPathComponent(appName)
            let targetApp = URL(fileURLWithPath: "/Applications").appendingPathComponent(appName)

            do {
                var trashedURL: NSURL?
                if fm.fileExists(atPath: targetApp.path) {
                    try fm.trashItem(at: targetApp, resultingItemURL: &trashedURL)
                }
                do {
                    try fm.copyItem(at: sourceApp, to: targetApp)
                } catch {
                    if let backup = trashedURL as URL? {
                        try? fm.moveItem(at: backup, to: targetApp)
                    }
                    throw error
                }
                return targetApp.path
            } catch {
                updateLog.error("Failed to install app update: \(error.localizedDescription)")
                return nil
            }
        }.value

        guard let targetApp = installedAppPath else {
            showDownloadFailed()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "更新已安装"
        alert.informativeText = "NotchBlock \(version) 已安装到 /Applications。\n立即重启以使用新版本？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "立即重启")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            relaunch(targetApp)
        }
    }

    nonisolated private static func runProcess(_ executable: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    private func relaunch(_ appPath: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appPath]
        try? process.run()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            NSApp.terminate(nil)
        }
    }

    // MARK: - Version

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    nonisolated static func stripLeadingV(_ version: String) -> String {
        var s = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") {
            s.removeFirst()
        }
        return s
    }

    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = numericVersionParts(a)
        let bParts = numericVersionParts(b)
        for i in 0..<max(aParts.count, bParts.count) {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }

    nonisolated private static func numericVersionParts(_ version: String) -> [Int] {
        let clean = stripLeadingV(version)
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        return clean
            .split(separator: "+", maxSplits: 1)
            .first?
            .split(separator: ".")
            .compactMap { Int($0) } ?? []
    }

    // MARK: - Changelog

    private func changelogForVersion(_ version: String) -> String? {
        guard let path = Bundle.main.path(forResource: "CHANGELOG", ofType: "md"),
              let content = try? String(contentsOfFile: path, encoding: .utf8)
        else { return nil }
        return Self.extractChangelog(for: version, from: content)
    }

    nonisolated static func extractChangelog(for version: String, from content: String) -> String? {
        let clean = stripLeadingV(version)
        let marker = "## [\(clean)]"
        guard let start = content.range(of: marker) else { return nil }
        let tail = content[start.upperBound...]
        // Skip rest of heading line (e.g. " — 2026-06-07")
        let bodyStart = tail.firstIndex(of: "\n").map { tail.index(after: $0) } ?? tail.startIndex
        let body = tail[bodyStart...]
        if let end = body.range(of: "\n## [") {
            return String(body[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(body).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - UI

    private func showUpdateFound(tag: String, dmgAvailable: Bool) {
        updateLog.info("Update available: \(tag) (current: v\(self.currentVersion))")

        let content = UNMutableNotificationContent()
        content.title = "NotchBlock \(tag) 可用"
        content.body = "新版本已发布，点击查看并安装。"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "update-\(tag)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            )
        )

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(tag)"
        alert.informativeText = dmgAvailable
            ? "当前: v\(currentVersion)\n\n选择\"自动更新\"将自动下载并安装新版本。"
            : "当前: v\(currentVersion)\n\n无法获取自动更新包，是否前往 GitHub 手动下载？"
        alert.alertStyle = .informational
        if dmgAvailable {
            alert.addButton(withTitle: "自动更新")
            alert.addButton(withTitle: "稍后提醒")
            alert.addButton(withTitle: "跳过此版本")
        } else {
            alert.addButton(withTitle: "前往下载")
            alert.addButton(withTitle: "稍后提醒")
        }

        let result = alert.runModal()
        if dmgAvailable {
            switch result {
            case .alertFirstButtonReturn:
                downloadAndInstall()
            case .alertThirdButtonReturn:
                userDefaults.set(Self.stripLeadingV(tag), forKey: skipVersionKey)
            default:
                break
            }
        } else if result == .alertFirstButtonReturn {
            openReleasesPage()
        }
    }

    private func showNoUpdate() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "NotchBlock v\(currentVersion)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    private func showDownloadFailed() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "更新失败"
        alert.informativeText = "自动下载或安装失败，请前往 GitHub 手动下载。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            openReleasesPage()
        }
    }

    func openReleasesPage() {
        if let url = URL(string: "https://github.com/\(repo)/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showRateLimited() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "检查更新受限"
        alert.informativeText = "GitHub API 请求次数已达上限，请稍后再试或前往 GitHub 手动检查更新。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "确定")
        if alert.runModal() == .alertFirstButtonReturn {
            openReleasesPage()
        }
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    private let onProgress: @Sendable (Double) -> Void
    private let onComplete: @Sendable (URL?, Error?) -> Void

    init(
        onProgress: @escaping @Sendable (Double) -> Void,
        onComplete: @escaping @Sendable (URL?, Error?) -> Void
    ) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            onComplete(nil, URLError(.badServerResponse))
            return
        }
        // Copy before URLSession deletes `location` upon delegate return
        let copyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchBlock-dl-\(UUID().uuidString).dmg")
        do {
            try FileManager.default.copyItem(at: location, to: copyURL)
            onComplete(copyURL, nil)
        } catch {
            onComplete(nil, error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            onComplete(nil, error)
        }
    }
}
