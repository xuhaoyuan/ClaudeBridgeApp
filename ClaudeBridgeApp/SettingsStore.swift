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

    // MARK: - Constants


    static let accountTypes = ["individual", "business", "enterprise"]

    // MARK: - Init

    init() {
        let ud = UserDefaults.standard
        self.port        = ud.string(forKey: "port") ?? "4141"
        self.autoStart   = ud.object(forKey: "autoStart") as? Bool ?? true
        self.launchAtLogin = ud.object(forKey: "launchAtLogin") as? Bool ?? false
        self.claudeModel = ud.string(forKey: "claudeModel") ?? "claude-sonnet-4.6"
        self.smallModel  = ud.string(forKey: "smallModel") ?? "claude-sonnet-4.6"
        self.accountType = ud.string(forKey: "accountType") ?? "individual"
    }

    // MARK: - Computed

    var claudeCommand: String {
        "ANTHROPIC_BASE_URL=http://localhost:\(port) ANTHROPIC_API_KEY=copilot CLAUDE_MODEL=\(claudeModel) ANTHROPIC_SMALL_FAST_MODEL=\(smallModel) claude"
    }

    // MARK: - Private

    private func syncClaudeSettings() {
        ClaudeSettingsManager.update(port: port, model: claudeModel, smallModel: smallModel)
    }
}

