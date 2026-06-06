import Foundation

// MARK: - PetConfig

/// Parsed representation of a pet's manifest JSON (`manifest.json`).
///
/// The manifest maps each `PetState.manifestKey` to a GIF filename.
/// When no manifest exists (or a state is missing from it), the naming convention
/// `{petName}-{state.animationFileName}.gif` is used as a fallback.
struct PetConfig: Codable, Equatable {

    // MARK: - Stored Properties

    let name: String
    let displayName: String

    /// Maps state manifest keys (e.g. `"idle"`) to GIF filenames (e.g. `"elysia-idle.gif"`).
    let animationFiles: [String: String]

    // MARK: - Coding

    enum CodingKeys: String, CodingKey {
        case name, displayName, animationFiles = "animations"
    }

    init(name: String, displayName: String, animationFiles: [String: String]) {
        self.name = name
        self.displayName = displayName
        self.animationFiles = animationFiles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? name
        animationFiles = (try? c.decode([String: String].self, forKey: .animationFiles)) ?? [:]
    }

    // MARK: - URL Resolution

    /// Resolve the GIF file URL for a given state.
    ///
    /// - If the manifest has an explicit mapping for this state, use it.
    /// - Otherwise, fall back to the naming convention: `{petName}-{state.animationFileName}.gif`.
    func url(for state: PetState, in directory: URL) -> URL {
        if let filename = animationFiles[state.manifestKey] {
            return directory.appendingPathComponent(filename)
        }
        let fallback = "\(name)-\(state.animationFileName).gif"
        return directory.appendingPathComponent(fallback)
    }

    /// Build an animation map for all known states using whatever resolution is available.
    func animationURLs(in directory: URL) -> [PetState: URL] {
        var map: [PetState: URL] = [:]
        for state in PetState.allCases {
            map[state] = url(for: state, in: directory)
        }
        return map
    }

    // MARK: - Loading

    /// Default manifest file name inside each pet directory.
    static let manifestFileName = "manifest.json"

    /// Load a `PetConfig` from a pet directory.
    ///
    /// - Parameter petName: The pet identifier (also used as fallback `displayName`).
    /// - Parameter directory: The directory containing the pet's assets and optional manifest.
    /// - Returns: A parsed `PetConfig`, or `nil` if the manifest exists but is malformed.
    static func load(petName: String, from directory: URL) -> PetConfig? {
        let manifestURL = directory.appendingPathComponent(manifestFileName)
        guard let data = try? Data(contentsOf: manifestURL) else {
            // No manifest file — build from naming convention
            return PetConfig(name: petName, displayName: petName, animationFiles: [:])
        }
        guard let config = try? JSONDecoder().decode(PetConfig.self, from: data) else {
            return nil
        }
        return config
    }
}
