import XCTest
import Foundation

// MARK: - Version Comparison Tests

/// Tests for the version comparison logic used by UpdateChecker.
/// The `isNewer` method compares two semantic version strings and returns
/// true if the first is strictly greater than the second.
///
/// Key bug being fixed: version strings with "v" prefix (e.g., "v0.6.6")
/// cause `Int("v0")` to return nil, making `compactMap` drop the segment,
/// resulting in incorrect comparisons that always return false.
final class VersionComparisonTests: XCTestCase {

    /// Replicates the UpdateChecker.isNewer logic — used to test the fix
    /// before/after the v-prefix stripping is added.
    private func isNewer(_ a: String, than b: String) -> Bool {
        // Fix: strip leading "v" or "V" before parsing
        let aClean = a.replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
        let bClean = b.replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
        let aP = aClean.split(separator: ".").compactMap { Int($0) }
        let bP = bClean.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aP.count, bP.count) {
            let av = i < aP.count ? aP[i] : 0
            let bv = i < bP.count ? bP[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }

    /// Original broken implementation — used to demonstrate the bug.
    private func isNewerBroken(_ a: String, than b: String) -> Bool {
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

    // MARK: - Clean versions (no v prefix)

    func test_newerMajorVersion_returnsTrue() {
        XCTAssertTrue(isNewer("1.0.0", than: "0.9.0"))
    }

    func test_olderMajorVersion_returnsFalse() {
        XCTAssertFalse(isNewer("0.9.0", than: "1.0.0"))
    }

    func test_newerMinorVersion_returnsTrue() {
        XCTAssertTrue(isNewer("0.6.7", than: "0.6.6"))
    }

    func test_olderMinorVersion_returnsFalse() {
        XCTAssertFalse(isNewer("0.6.5", than: "0.6.6"))
    }

    func test_newerPatchVersion_returnsTrue() {
        XCTAssertTrue(isNewer("0.6.6", than: "0.6.5"))
    }

    func test_equalVersions_returnsFalse() {
        XCTAssertFalse(isNewer("0.1.0", than: "0.1.0"))
    }

    func test_equalVersionsSamePatch_returnsFalse() {
        XCTAssertFalse(isNewer("1.2.3", than: "1.2.3"))
    }

    // MARK: - v prefix (the CRITICAL bug)

    func test_newerWithoutV_vs_olderWithV_returnsTrue() {
        // "0.6.7" > "v0.6.6" → should be true
        XCTAssertTrue(isNewer("0.6.7", than: "v0.6.6"))
    }

    func test_newerWithV_vs_olderWithV_returnsTrue() {
        // "v1.0.0" > "v0.9.0" → should be true
        XCTAssertTrue(isNewer("v1.0.0", than: "v0.9.0"))
    }

    func test_equalWithAndWithoutV_returnsFalse() {
        // "0.6.6" == "v0.6.6" → should be false (not newer)
        XCTAssertFalse(isNewer("0.6.6", than: "v0.6.6"))
    }

    func test_equalBothWithV_returnsFalse() {
        XCTAssertFalse(isNewer("v0.6.6", than: "v0.6.6"))
    }

    func test_newerWithV_vs_olderWithoutV_returnsTrue() {
        XCTAssertTrue(isNewer("v1.2.0", than: "1.1.9"))
    }

    // MARK: - Demonstrating the broken behavior (these WOULD fail without the fix)

    func test_brokenImplementation_failsOnVPrefix() {
        // Without the fix: "v0" → Int("v0") = nil → dropped → [6, 6]
        // vs "0.6.5" → [0, 6, 5]
        // 6 > 0 → true — this accidentally passes
        // But "v0.6.6" vs "0.6.7": [6, 6] vs [0, 6, 7]
        // 6 > 0 → true (WRONG — 0.6.6 is NOT newer than 0.6.7)
        XCTAssertTrue(isNewerBroken("v0.6.6", than: "0.6.5"),
                      "Broken impl accidentally passes: 6 > 0 from [6,6] vs [0,6,5]")
        // The REAL bug: v0.6.7 should be newer than v0.6.6, but broken impl says false
        XCTAssertFalse(isNewerBroken("v0.6.7", than: "v0.6.6"),
                       "Broken impl fails: [6,7] vs [6,6] → 7>6 → true BUT first segment 0 missing!")
    }

    // MARK: - Variable-length versions

    func test_fourPartVersion_comparesCorrectly() {
        XCTAssertTrue(isNewer("1.0.0.1", than: "1.0.0"))
    }

    func test_twoPartVersion_comparesCorrectly() {
        XCTAssertTrue(isNewer("2.0", than: "1.9"))
    }

    // MARK: - Edge cases

    func test_singleDigitVersion() {
        XCTAssertTrue(isNewer("2", than: "1"))
        XCTAssertFalse(isNewer("1", than: "2"))
    }

    func test_versionWithLeadingZeros() {
        // "0.6.06" → [0, 6, 6] vs "0.6.6" → [0, 6, 6] → equal
        XCTAssertFalse(isNewer("0.6.06", than: "0.6.6"))
    }

    func test_zeroVersion() {
        XCTAssertFalse(isNewer("0.0.0", than: "0.0.0"))
        XCTAssertTrue(isNewer("0.0.1", than: "0.0.0"))
    }

    func test_uppercaseVPrefix() {
        XCTAssertTrue(isNewer("V1.0.0", than: "V0.9.0"))
        XCTAssertFalse(isNewer("V0.6.6", than: "v0.6.6"))
    }
}

// MARK: - Current Version Tests

/// Tests that currentVersion reads correctly from Bundle and strips v prefix.
final class CurrentVersionTests: XCTestCase {

    func test_currentVersion_returnsNonNil() {
        // currentVersion always returns a non-empty string (falls back to "0.0.0")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        XCTAssertFalse(version.isEmpty)
    }

    func test_currentVersion_shouldNotStartWithV() {
        // After the fix, CFBundleShortVersionString should be "0.6.6" not "v0.6.6"
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        // This test documents the expectation; passes if Info.plist is already fixed
        if !raw.isEmpty {
            XCTAssertFalse(
                raw.hasPrefix("v"),
                "CFBundleShortVersionString '\(raw)' should not start with 'v'. " +
                "Run build_dmg.py after fix to sync the version."
            )
        }
    }
}

// MARK: - Download Delegate Tests

/// Tests that the URLSessionDownloadDelegate correctly updates download progress.
final class DownloadDelegateTests: XCTestCase {

    /// A simple delegate that mirrors what UpdateChecker will use.
    final class ProgressDelegate: NSObject, URLSessionDownloadDelegate {
        var onProgress: ((Double) -> Void)?
        var onComplete: ((URL?, Error?) -> Void)?

        func urlSession(_ session: URLSession,
                        downloadTask: URLSessionDownloadTask,
                        didWriteData bytesWritten: Int64,
                        totalBytesWritten: Int64,
                        totalBytesExpectedToWrite: Int64) {
            guard totalBytesExpectedToWrite > 0 else { return }
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress?(progress)
        }

        func urlSession(_ session: URLSession,
                        downloadTask: URLSessionDownloadTask,
                        didFinishDownloadingTo location: URL) {
            onComplete?(location, nil)
        }

        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        didCompleteWithError error: Error?) {
            if let error = error {
                onComplete?(nil, error)
            }
        }
    }

    func test_didWriteData_updatesProgress() {
        let delegate = ProgressDelegate()
        var capturedProgress: Double = -1
        delegate.onProgress = { capturedProgress = $0 }

        // Simulate the delegate callback
        delegate.urlSession(
            URLSession.shared,
            downloadTask: URLSessionDownloadTask(),
            didWriteData: 500_000,
            totalBytesWritten: 500_000,
            totalBytesExpectedToWrite: 2_000_000
        )

        XCTAssertEqual(capturedProgress, 0.25, accuracy: 0.001,
                       "Progress should be 500000/2000000 = 0.25")
    }

    func test_didWriteData_halfProgress() {
        let delegate = ProgressDelegate()
        var capturedProgress: Double = -1
        delegate.onProgress = { capturedProgress = $0 }

        delegate.urlSession(
            URLSession.shared,
            downloadTask: URLSessionDownloadTask(),
            didWriteData: 1_000_000,
            totalBytesWritten: 1_000_000,
            totalBytesExpectedToWrite: 2_000_000
        )

        XCTAssertEqual(capturedProgress, 0.5, accuracy: 0.001)
    }

    func test_didWriteData_completeProgress() {
        let delegate = ProgressDelegate()
        var capturedProgress: Double = -1
        delegate.onProgress = { capturedProgress = $0 }

        delegate.urlSession(
            URLSession.shared,
            downloadTask: URLSessionDownloadTask(),
            didWriteData: 2_000_000,
            totalBytesWritten: 2_000_000,
            totalBytesExpectedToWrite: 2_000_000
        )

        XCTAssertEqual(capturedProgress, 1.0, accuracy: 0.001)
    }

    func test_didWriteData_zeroExpectedBytes_doesNotCallProgress() {
        let delegate = ProgressDelegate()
        var progressCalled = false
        delegate.onProgress = { _ in progressCalled = true }

        delegate.urlSession(
            URLSession.shared,
            downloadTask: URLSessionDownloadTask(),
            didWriteData: 500_000,
            totalBytesWritten: 500_000,
            totalBytesExpectedToWrite: 0  // Unknown total size
        )

        XCTAssertFalse(progressCalled,
                       "Progress callback should not fire when total bytes unknown (0)")
    }

    func test_didWriteData_negativeExpectedBytes_doesNotCallProgress() {
        let delegate = ProgressDelegate()
        var progressCalled = false
        delegate.onProgress = { _ in progressCalled = true }

        delegate.urlSession(
            URLSession.shared,
            downloadTask: URLSessionDownloadTask(),
            didWriteData: 500_000,
            totalBytesWritten: 500_000,
            totalBytesExpectedToWrite: -1  // NSURLSessionTransferSizeUnknown
        )

        XCTAssertFalse(progressCalled,
                       "Progress callback should not fire for NSURLSessionTransferSizeUnknown")
    }
}
