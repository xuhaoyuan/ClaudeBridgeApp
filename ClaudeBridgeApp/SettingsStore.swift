import Foundation
import Observation
import ServiceManagement

@Observable
final class SettingsStore {

    // MARK: - Persisted Settings

    var port: String {
        didSet {
            UserDefaults.standard.set(port, forKey: "port")
            syncClaudeSettings()
        }
    }

    var autoStart: Bool {
        didSet { UserDefaults.standard.set(autoStart, forKey: "autoStart") }
    }

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    var claudeModel: String {
        didSet {
            UserDefaults.standard.set(claudeModel, forKey: "claudeModel")
            syncClaudeSettings()
        }
    }

    var smallModel: String {
        didSet {
            UserDefaults.standard.set(smallModel, forKey: "smallModel")
            syncClaudeSettings()
        }
    }

    var accountType: String {
        didSet { UserDefaults.standard.set(accountType, forKey: "accountType") }
    }

    var hasCompletedSetup: Bool {
        didSet { UserDefaults.standard.set(hasCompletedSetup, forKey: "hasCompletedSetup") }
    }

    // MARK: - Constants

    static let accountTypes = ["individual", "business", "enterprise"]

    // MARK: - Computed

    var isModelSelected: Bool {
        !claudeModel.isEmpty && !smallModel.isEmpty
    }

    var claudeCommand: String {
        "ANTHROPIC_BASE_URL=http://localhost:\(port) ANTHROPIC_API_KEY=copilot CLAUDE_MODEL=\(claudeModel) ANTHROPIC_SMALL_FAST_MODEL=\(smallModel) claude"
    }

    // MARK: - Init

    init() {
        let ud = UserDefaults.standard

        self.port          = ud.string(forKey: "port") ?? "4141"
        self.autoStart     = ud.object(forKey: "autoStart") as? Bool ?? true
        self.launchAtLogin = ud.object(forKey: "launchAtLogin") as? Bool ?? false
        self.claudeModel   = ud.string(forKey: "claudeModel") ?? ""
        self.smallModel    = ud.string(forKey: "smallModel") ?? ""
        self.accountType   = ud.string(forKey: "accountType") ?? "individual"

        // Migration: detect existing users (have a token file) and auto-complete setup
        let tokenPath = FileManager.default.homeDirectoryForCurrentUser.path
            + "/.local/share/copilot-api/github_token"

        if let stored = ud.object(forKey: "hasCompletedSetup") as? Bool {
            self.hasCompletedSetup = stored
        } else if FileManager.default.fileExists(atPath: tokenPath) {
            // Existing user upgrading — mark setup as done and keep working defaults
            self.hasCompletedSetup = true
            ud.set(true, forKey: "hasCompletedSetup")
            if self.claudeModel.isEmpty {
                self.claudeModel = "claude-sonnet-4.6"
                ud.set("claude-sonnet-4.6", forKey: "claudeModel")
            }
            if self.smallModel.isEmpty {
                self.smallModel = "claude-sonnet-4.6"
                ud.set("claude-sonnet-4.6", forKey: "smallModel")
            }
        } else {
            self.hasCompletedSetup = false
        }
    }

    // MARK: - Private

    private func syncClaudeSettings() {
        guard isModelSelected else { return }
        ClaudeSettingsManager.update(port: port, model: claudeModel, smallModel: smallModel)
    }
}

