import Foundation

// MARK: - PetProtocol

/// Contract that every desktop pet must fulfill.
protocol PetProtocol {
    /// Unique identifier used for asset directories and UserDefaults keys.
    var name: String { get }

    /// User-facing name shown in menus and onboarding.
    var displayName: String { get }

    /// Maps each animation state to its GIF file URL.
    var animations: [PetState: URL] { get }

    /// Logical size (in points) the pet window should use.
    var defaultSize: CGSize { get }
}

// MARK: - ElysiaPet

/// The default desktop pet — a cheerful companion.
struct ElysiaPet: PetProtocol {
    let name = "elysia"
    let displayName = "Elysia"
    let animations: [PetState: URL]
    let defaultSize = CGSize(width: 120, height: 120)

    /// Create an ElysiaPet whose animation URLs are built from the naming convention
    /// `{petName}-{state.animationFileName}.gif` inside the given directory.
    init(assetsDirectory: URL) {
        var map: [PetState: URL] = [:]
        for state in PetState.allCases {
            let filename = "\(name)-\(state.animationFileName).gif"
            map[state] = assetsDirectory.appendingPathComponent(filename)
        }
        self.animations = map
    }

    /// The manifest file looked for in each pet directory.
    static let manifestFileName = "manifest.json"
}
