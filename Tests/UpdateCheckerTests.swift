import XCTest
@testable import NotchBlock

final class UpdateCheckerTests: XCTestCase {
    @MainActor
    private func makeIsolatedDefaults() -> (defaults: UserDefaults, cleanup: () -> Void) {
        let suiteName = "com.notchblock.tests.updater.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
    }

    // MARK: - Version Comparison

    func test_cleanSemverComparisons() {
        XCTAssertTrue(UpdateChecker.isNewer("1.0.0", than: "0.9.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.9.0", than: "1.0.0"))
        XCTAssertTrue(UpdateChecker.isNewer("0.6.7", than: "0.6.6"))
        XCTAssertFalse(UpdateChecker.isNewer("0.6.5", than: "0.6.6"))
        XCTAssertFalse(UpdateChecker.isNewer("1.2.3", than: "1.2.3"))
    }

    func test_vPrefixHandling() {
        XCTAssertTrue(UpdateChecker.isNewer("0.6.7", than: "v0.6.6"))
        XCTAssertTrue(UpdateChecker.isNewer("v1.0.0", than: "v0.9.0"))
        XCTAssertTrue(UpdateChecker.isNewer("V1.2.0", than: "1.1.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.6.6", than: "v0.6.6"))
        XCTAssertFalse(UpdateChecker.isNewer("v0.6.6", than: "v0.6.6"))
        XCTAssertFalse(UpdateChecker.isNewer("V0.6.6", than: "v0.6.6"))
    }

    func test_variableLengthAndPrereleaseTags() {
        XCTAssertTrue(UpdateChecker.isNewer("1.0.0.1", than: "1.0.0"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0", than: "1.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.6.06", than: "0.6.6"))
        XCTAssertTrue(UpdateChecker.isNewer("v0.7.0-beta.1", than: "0.6.7"))
        XCTAssertFalse(UpdateChecker.isNewer("v0.6.7-beta.1", than: "0.6.7"))
    }

    // MARK: - Bundle Version & Changelog

    func test_bundleShortVersionHasNoVPrefix() {
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        XCTAssertFalse(raw.isEmpty)
        XCTAssertFalse(raw.hasPrefix("v"), "CFBundleShortVersionString '\(raw)' should not start with 'v'")
    }

    func test_extractChangelogParsesTargetSection() {
        let sample = """
        # Changelog

        ## [0.6.7] — 2026-06-07

        ### Fixed
        - Version check fix

        ## [0.6.6] — 2026-06-07

        ### Fixed
        - Older fix
        """

        let notes = UpdateChecker.extractChangelog(for: "v0.6.7", from: sample)
        XCTAssertEqual(notes, "### Fixed\n- Version check fix")
        XCTAssertNil(UpdateChecker.extractChangelog(for: "0.9.9", from: sample))
    }

    @MainActor
    func test_checkWhatsNewSkipsFirstLaunchAndSameVersion() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let checker = UpdateChecker(userDefaults: defaults)
        // First launch: records currentVersion and returns nil
        XCTAssertNil(checker.checkWhatsNew())
        // Subsequent launch on same version: returns nil
        XCTAssertNil(checker.checkWhatsNew())
        // Prior launch stored with v-prefix for same version: still returns nil
        defaults.set("v\(checker.currentVersion)", forKey: "lastLaunchedVersion")
        XCTAssertNil(checker.checkWhatsNew())
    }
}
