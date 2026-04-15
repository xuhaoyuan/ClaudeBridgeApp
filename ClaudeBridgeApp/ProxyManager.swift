import Foundation
import Observation

@Observable
final class ProxyManager {

    // MARK: - Types

    enum ProxyState: Equatable {
        case stopped
        case starting
        case running
        case error(String)
    }

    // MARK: - Published State

    var state: ProxyState = .stopped
    var logs: String = ""
    var loginUser: String?
    var detectedPlan: String?
    var availableModels: [CopilotModel] = []

    // Login flow state
    var isLoggingIn: Bool = false
    var loginDeviceCode: String?
    var loginDeviceURL: String?

    // Install flow state
    var isInstalling: Bool = false
    var installOutput: String = ""

    // Model fetch state
    var isFetchingModels: Bool = false

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var isLoggedIn: Bool {
        loginUser != nil
    }

    // MARK: - Private

    private var process: Process?
    private var authProcess: Process?
    private var outputPipe: Pipe?
    private var healthCheckTimer: Timer?
    private var cachedExecutablePath: String?
    private var modelsFetched = false
    private var startupTime: Date?

    private static let tokenPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.local/share/copilot-api/github_token"
    }()

    // MARK: - Init

    init() {
        resolveExecutablePath()
    }

    // MARK: - Executable Path

    var executablePath: String {
        cachedExecutablePath ?? "/opt/homebrew/bin/copilot-api"
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: executablePath)
    }

    private func resolveExecutablePath() {
        let knownPaths = [
            "/opt/homebrew/bin/copilot-api",
            "/usr/local/bin/copilot-api",
        ]
        for path in knownPaths {
            if FileManager.default.fileExists(atPath: path) {
                cachedExecutablePath = path
                return
            }
        }

        // Fallback: ask the login shell
        Task.detached { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-l", "-c", "which copilot-api"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty,
                   FileManager.default.fileExists(atPath: path) {
                    await MainActor.run { self?.cachedExecutablePath = path }
                }
            } catch {}
        }
    }

    // MARK: - Process Control

    /// Synchronously re-check known paths for copilot-api, then kick off async shell lookup.
    func recheckInstallation() {
        let knownPaths = [
            "/opt/homebrew/bin/copilot-api",
            "/usr/local/bin/copilot-api",
        ]
        for path in knownPaths {
            if FileManager.default.fileExists(atPath: path) {
                cachedExecutablePath = path
                return
            }
        }
        resolveExecutablePath()
    }

    /// One-click install via npm
    func installCopilotApi() {
        guard !isInstalling else { return }
        isInstalling = true
        installOutput = ""

        Task.detached { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-l", "-c", "npm install -g copilot-api"]

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor [weak self] in
                    self?.installOutput += str
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil

                let success = proc.terminationStatus == 0
                await MainActor.run {
                    self?.isInstalling = false
                    self?.recheckInstallation()
                    if success {
                        self?.appendLog("copilot-api installed successfully")
                    } else {
                        self?.appendLog("copilot-api installation failed (exit \(proc.terminationStatus))")
                    }
                }
            } catch {
                await MainActor.run {
                    self?.isInstalling = false
                    self?.installOutput += "\nError: \(error.localizedDescription)"
                    self?.appendLog("Failed to install copilot-api: \(error.localizedDescription)")
                }
            }
        }
    }

    func start(settings: SettingsStore) {
        guard process == nil || process?.isRunning != true else { return }

        state = .starting
        modelsFetched = false
        appendLog("Starting copilot-api on port \(settings.port)...")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)

        let args = [
            "start",
            "--port", settings.port,
            "--account-type", settings.accountType,
        ]
        proc.arguments = args

        proc.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
            "HOME": NSHomeDirectory(),
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        self.outputPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.logs += str
            }
        }

        proc.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self?.appendLog("Process exited with code \(p.terminationStatus)")
                self?.state = .stopped
                self?.process = nil
                self?.stopHealthCheck()
            }
        }

        do {
            try proc.run()
            self.process = proc
            // Stay in .starting — health check will set .running when server responds
            startHealthCheck(port: settings.port)
        } catch {
            self.state = .error(error.localizedDescription)
            appendLog("Failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        stopHealthCheck()
        guard let process, process.isRunning else {
            state = .stopped
            self.process = nil
            return
        }
        appendLog("Stopping...")
        process.terminate()
    }

    func restart(settings: SettingsStore) {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.start(settings: settings)
        }
    }

    func clearLogs() {
        logs = ""
    }

    // MARK: - Health Check

    private func startHealthCheck(port: String) {
        stopHealthCheck()
        startupTime = Date()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck(port: port)
        }
        // First check after server has had time to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.performHealthCheck(port: port)
        }
    }

    private func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    private func performHealthCheck(port: String) {
        guard let url = URL(string: "http://localhost:\(port)/") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if error == nil,
                   let http = response as? HTTPURLResponse,
                   (200 ..< 400).contains(http.statusCode) {
                    // Server is responding — mark as running
                    if !self.isRunning {
                        self.state = .running
                        self.appendLog("Server is healthy on port \(port)")
                    }
                    // Fetch models once after server is confirmed healthy
                    if !self.modelsFetched {
                        self.modelsFetched = true
                        self.fetchModels(port: port)
                    } else if self.availableModels.isEmpty {
                        // Previous fetch failed — retry
                        self.fetchModels(port: port)
                    }
                } else if self.process?.isRunning == true {
                    // Process is alive but HTTP failed
                    if case .starting = self.state {
                        // Still starting up — only error after 30s timeout
                        if let t = self.startupTime, Date().timeIntervalSince(t) > 30 {
                            self.state = .error("Server failed to start (timeout)")
                        }
                        return
                    }
                    self.state = .error("Health check failed")
                }
            }
        }.resume()
    }

    // MARK: - Models (dynamic from /v1/models)

    func fetchModels(port: String) {
        guard !isFetchingModels else { return }
        guard let url = URL(string: "http://localhost:\(port)/v1/models") else { return }

        isFetchingModels = true
        appendLog("Fetching models from server...")

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isFetchingModels = false

                if let error {
                    self.appendLog("Failed to fetch models: \(error.localizedDescription)")
                    return
                }
                guard let data else {
                    self.appendLog("Failed to fetch models: no data")
                    return
                }
                do {
                    let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
                    let chatModels = CopilotModel.filterChatModels(response.data)
                    if !chatModels.isEmpty {
                        self.availableModels = chatModels
                        self.appendLog("Fetched \(chatModels.count) models from server")
                    } else {
                        self.appendLog("Server returned 0 chat models")
                    }
                } catch {
                    self.appendLog("Failed to parse models: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    // MARK: - Copilot Info (login + plan from check-usage)

    func checkCopilotInfo(autoFillSettings settings: SettingsStore? = nil) {
        // Quick check: token file exists?
        guard FileManager.default.fileExists(atPath: Self.tokenPath) else {
            self.loginUser = nil
            self.detectedPlan = nil
            return
        }

        Task.detached { [weak self] in
            guard let self else { return }
            let path = await self.executablePath

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: path)
            proc.arguments = ["check-usage"]
            proc.environment = [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                "HOME": NSHomeDirectory(),
            ]

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                // Parse: "Logged in as xuhaoyuan"
                let username: String? = {
                    if let range = output.range(of: #"Logged in as (\S+)"#, options: .regularExpression) {
                        let match = output[range]
                        return match.replacingOccurrences(of: "Logged in as ", with: "")
                    }
                    return nil
                }()

                // Parse: "plan: business"
                let plan: String? = {
                    if let range = output.range(of: #"plan: (\w+)"#, options: .regularExpression) {
                        let match = output[range]
                        return match.replacingOccurrences(of: "plan: ", with: "")
                    }
                    return nil
                }()

                await MainActor.run {
                    self.loginUser = username
                    self.detectedPlan = plan
                    // Auto-fill account type in settings if detected
                    if let plan, let settings {
                        settings.accountType = plan
                    }
                }
            } catch {
                await MainActor.run {
                    self.loginUser = nil
                    self.detectedPlan = nil
                }
            }
        }
    }

    // MARK: - Login / Logout

    func login() {
        isLoggingIn = true
        loginDeviceCode = nil
        loginDeviceURL = nil

        Task.detached { [weak self] in
            guard let self else { return }
            let path = await self.executablePath

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: path)
            proc.arguments = ["auth"]
            proc.environment = [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                "HOME": NSHomeDirectory(),
            ]

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            // Parse device code + URL from auth output in real time
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }

                // Match: code "XXXX-XXXX" in https://github.com/login/device
                if let codeRange = str.range(of: #""([A-Z0-9]{4}-[A-Z0-9]{4})""#, options: .regularExpression) {
                    let raw = str[codeRange]
                    let code = raw.replacingOccurrences(of: "\"", with: "")

                    let url: String? = {
                        if let r = str.range(of: #"https://\S+"#, options: .regularExpression) {
                            return String(str[r])
                        }
                        return nil
                    }()

                    Task { @MainActor [weak self] in
                        self?.loginDeviceCode = code
                        self?.loginDeviceURL = url ?? "https://github.com/login/device"
                    }
                }
            }

            await MainActor.run { self.authProcess = proc }

            do {
                try proc.run()
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil

                await MainActor.run {
                    self.authProcess = nil
                    self.isLoggingIn = false
                    self.loginDeviceCode = nil
                    self.loginDeviceURL = nil
                    // Re-check info after auth completes
                    self.checkCopilotInfo()
                }
            } catch {
                await MainActor.run {
                    self.authProcess = nil
                    self.isLoggingIn = false
                    self.appendLog("Login failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelLogin() {
        authProcess?.terminate()
        authProcess = nil
        isLoggingIn = false
        loginDeviceCode = nil
        loginDeviceURL = nil
    }

    func logout(clearSettings settings: SettingsStore? = nil) {
        // Stop proxy first — it needs the token to function
        stop()
        // Delete token file
        let fm = FileManager.default
        if fm.fileExists(atPath: Self.tokenPath) {
            try? fm.removeItem(atPath: Self.tokenPath)
        }
        loginUser = nil
        detectedPlan = nil
        availableModels = []
        // Clear model selections so UI resets to "Select a model..."
        if let settings {
            settings.claudeModel = ""
            settings.smallModel = ""
        }
        appendLog("Logged out (token removed)")
    }

    // MARK: - Helpers

    private func appendLog(_ message: String) {
        let ts = Self.timestampFormatter.string(from: Date())
        logs += "[\(ts)] \(message)\n"
    }

    nonisolated private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

