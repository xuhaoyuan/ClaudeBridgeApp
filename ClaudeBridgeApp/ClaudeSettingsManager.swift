import Foundation

/// Manages reading and writing ~/.claude/settings.json
/// Merges proxy-related fields while preserving existing user settings (e.g. permissions).
enum ClaudeSettingsManager {

    private static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }

    static func update(port: String, model: String, smallModel: String) {
        var existing: [String: Any] = [:]

        // Read existing file
        if let data = try? Data(contentsOf: settingsURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            existing = json
        }

        // Merge env
        var env = existing["env"] as? [String: String] ?? [:]
        env["ANTHROPIC_BASE_URL"] = "http://localhost:\(port)"
        env["ANTHROPIC_API_KEY"] = "copilot"
        env["CLAUDE_MODEL"] = model
        env["ANTHROPIC_SMALL_FAST_MODEL"] = smallModel
        existing["env"] = env

        // Update top-level model fields
        existing["model"] = model
        existing["smallModel"] = smallModel

        // Write back
        guard let data = try? JSONSerialization.data(
            withJSONObject: existing,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }

        let dir = settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: settingsURL, options: .atomic)
    }

    /// Remove all proxy-related fields from ~/.claude/settings.json,
    /// restoring it to a clean state while preserving other user settings.
    static func restore() {
        guard let data = try? Data(contentsOf: settingsURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Remove proxy env keys
        let proxyEnvKeys = [
            "ANTHROPIC_BASE_URL",
            "ANTHROPIC_API_KEY",
            "CLAUDE_MODEL",
            "ANTHROPIC_SMALL_FAST_MODEL",
        ]
        if var env = json["env"] as? [String: String] {
            for key in proxyEnvKeys {
                env.removeValue(forKey: key)
            }
            if env.isEmpty {
                json.removeValue(forKey: "env")
            } else {
                json["env"] = env
            }
        }

        // Remove top-level model fields we wrote
        json.removeValue(forKey: "model")
        json.removeValue(forKey: "smallModel")

        // Write back
        guard let output = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? output.write(to: settingsURL, options: .atomic)
    }
}

