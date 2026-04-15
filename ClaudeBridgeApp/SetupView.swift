import SwiftUI
import AppKit

struct SetupView: View {
    var settings: SettingsStore
    var proxy: ProxyManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var selectedClaudeModel = ""
    @State private var selectedSmallModel = ""
    @State private var proxyStartedForModels = false

    private let totalSteps = 4

    private var canProceed: Bool {
        switch currentStep {
        case 0: return proxy.isInstalled
        case 1: return proxy.isLoggedIn
        case 2: return !selectedClaudeModel.isEmpty && !selectedSmallModel.isEmpty
        case 3: return true
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "network")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                Text("ClaudeBridgeApp Setup")
                    .font(.title2.bold())
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Step indicator
            stepIndicator
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

            Divider()

            // Content area
            ScrollView {
                Group {
                    switch currentStep {
                    case 0: installStep
                    case 1: loginStep
                    case 2: modelStep
                    case 3: readyStep
                    default: EmptyView()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation
            HStack {
                if currentStep > 0 && currentStep < totalSteps - 1 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) { currentStep -= 1 }
                    }
                }

                Spacer()

                if currentStep < totalSteps - 1 {
                    Button {
                        advanceStep()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canProceed)
                } else {
                    Button("Start Using") {
                        completeSetup()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 520, height: 540)
        .interactiveDismissDisabled(!settings.hasCompletedSetup)
        .onAppear {
            // Pre-fill model selections from current settings
            selectedClaudeModel = settings.claudeModel
            selectedSmallModel = settings.smallModel

            // Auto-advance to the first incomplete step
            if proxy.isInstalled && proxy.isLoggedIn && settings.isModelSelected {
                // All done — start from step 0 so user can review everything
                currentStep = 0
            } else if proxy.isInstalled && proxy.isLoggedIn {
                currentStep = 2
            } else if proxy.isInstalled {
                currentStep = 1
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { step in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 28, height: 28)

                        if isStepComplete(step) {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        } else {
                            Text("\(step + 1)")
                                .font(.caption.bold())
                                .foregroundColor(step == currentStep ? .white : .secondary)
                        }
                    }
                    Text(stepTitle(step))
                        .font(.caption2)
                        .foregroundStyle(step == currentStep ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)

                if step < totalSteps - 1 {
                    Rectangle()
                        .fill(isStepComplete(step) ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                        .offset(y: -10)
                }
            }
        }
    }

    private func stepTitle(_ step: Int) -> LocalizedStringKey {
        switch step {
        case 0: return "Install"
        case 1: return "Login"
        case 2: return "Models"
        case 3: return "Ready"
        default: return ""
        }
    }

    private func stepColor(for step: Int) -> Color {
        if isStepComplete(step) { return .green }
        if step == currentStep { return .accentColor }
        return .secondary.opacity(0.3)
    }

    private func isStepComplete(_ step: Int) -> Bool {
        switch step {
        case 0: return proxy.isInstalled
        case 1: return proxy.isLoggedIn
        case 2: return !selectedClaudeModel.isEmpty && !selectedSmallModel.isEmpty
        case 3: return false
        default: return false
        }
    }

    // MARK: - Step 1: Install

    @ViewBuilder
    private var installStep: some View {
        VStack(spacing: 20) {
            Label("Install copilot-api", systemImage: "shippingbox")
                .font(.title3.bold())

            if proxy.isInstalled {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("copilot-api is installed")
                        .foregroundStyle(.secondary)
                    Text(proxy.executablePath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            } else if proxy.isInstalling {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Installing copilot-api via npm...")
                        .foregroundStyle(.secondary)
                    if !proxy.installOutput.isEmpty {
                        ScrollView {
                            Text(proxy.installOutput)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 120)
                        .padding(8)
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                    Text("copilot-api is not installed")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button {
                            proxy.installCopilotApi()
                        } label: {
                            Label("One-Click Install", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            proxy.recheckInstallation()
                        } label: {
                            Label("Re-check", systemImage: "arrow.clockwise")
                        }
                    }
                    VStack(spacing: 6) {
                        Text("Or install manually in Terminal:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text("npm install -g copilot-api")
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quinary, in: RoundedRectangle(cornerRadius: 4))
                                .textSelection(.enabled)
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("npm install -g copilot-api", forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Copy command")
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Step 2: Login

    @ViewBuilder
    private var loginStep: some View {
        VStack(spacing: 20) {
            Label("Login to GitHub Copilot", systemImage: "person.badge.key")
                .font(.title3.bold())

            if proxy.isLoggedIn {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    if let user = proxy.loginUser {
                        Text("Logged in as **\(user)**")
                    }
                    if let plan = proxy.detectedPlan {
                        Text("Plan: \(plan)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else if proxy.isLoggingIn {
                if let code = proxy.loginDeviceCode {
                    deviceCodeView(code: code)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Requesting device code...")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Sign in with your GitHub account to access Copilot.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        proxy.login()
                    } label: {
                        Label("Login with GitHub", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ViewBuilder
    private func deviceCodeView(code: String) -> some View {
        VStack(spacing: 14) {
            Text("Enter this code on GitHub:")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text(code)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("Copy code")
            }
            if let urlString = proxy.loginDeviceURL,
               let url = URL(string: urlString) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "safari")
                        Text("Open GitHub")
                        Text("(auto-copies code)")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.link)
            }
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for authentication...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Cancel Login") {
                proxy.cancelLogin()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Step 3: Models

    @ViewBuilder
    private var modelStep: some View {
        VStack(spacing: 20) {
            Label("Select Models", systemImage: "cpu")
                .font(.title3.bold())
            Text("Choose the AI models for Claude Code to use.\nBoth fields are required.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Label("Please select Claude models. Non-Claude models may cause Claude Code to malfunction.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            if proxy.availableModels.isEmpty {
                VStack(spacing: 12) {
                    if case .error(let msg) = proxy.state {
                        // Proxy failed to start
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                        Text("Proxy error: \(msg)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            proxyStartedForModels = false
                            proxy.start(settings: settings)
                            proxyStartedForModels = true
                        } label: {
                            Label("Retry Start Proxy", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    } else if proxy.isFetchingModels {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Fetching models from server...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if proxy.isRunning {
                        // Proxy is running but models are empty — fetch may have failed
                        ProgressView()
                            .controlSize(.regular)
                        Text("Loading models from server...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            proxy.fetchModels(port: settings.port)
                        } label: {
                            Label("Retry Fetch", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        ProgressView()
                            .controlSize(.regular)
                        if proxy.state == .starting {
                            Text("Starting proxy...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Starting proxy to load models...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onAppear {
                    startProxyForModelFetch()
                }
            } else {
                VStack(spacing: 16) {
                    Grid(alignment: .leading, verticalSpacing: 12) {
                        GridRow {
                            Text("Claude Model")
                                .gridColumnAlignment(.trailing)
                            Picker("", selection: $selectedClaudeModel) {
                                Text("Select a model...").tag("")
                                ForEach(proxy.availableModels) { model in
                                    Text(model.displayName).tag(model.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 240)
                        }
                        GridRow {
                            Text("Small / Fast Model")
                            Picker("", selection: $selectedSmallModel) {
                                Text("Select a model...").tag("")
                                ForEach(proxy.availableModels) { model in
                                    Text(model.displayName).tag(model.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 240)
                        }
                    }
                    if selectedClaudeModel.isEmpty || selectedSmallModel.isEmpty {
                        Label("Both models must be selected to continue",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Button {
                        proxy.fetchModels(port: settings.port)
                    } label: {
                        HStack(spacing: 6) {
                            if proxy.isFetchingModels {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Label("Refresh Models", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!proxy.isRunning || proxy.isFetchingModels)
                }
            }
        }
    }

    // MARK: - Step 4: Ready

    @ViewBuilder
    private var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "party.popper")
                .font(.system(size: 48))
                .symbolRenderingMode(.multicolor)
            Text("All Set!")
                .font(.title2.bold())
            Text("ClaudeBridgeApp is ready to use.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                Label("copilot-api installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if let user = proxy.loginUser {
                    Label("Logged in as \(user)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Label("Models configured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
            Divider()
            VStack(spacing: 12) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                Toggle("Auto Start Proxy on Launch", isOn: Binding(
                    get: { settings.autoStart },
                    set: { settings.autoStart = $0 }
                ))
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func advanceStep() {
        if currentStep == 2 {
            settings.claudeModel = selectedClaudeModel
            settings.smallModel = selectedSmallModel
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep += 1
        }
    }

    private func startProxyForModelFetch() {
        if proxy.isRunning && proxy.availableModels.isEmpty {
            // Proxy already running but models not fetched — trigger fetch directly
            proxy.fetchModels(port: settings.port)
            return
        }
        guard !proxyStartedForModels else { return }
        proxyStartedForModels = true
        if !proxy.isRunning && proxy.state != .starting {
            proxy.start(settings: settings)
        }
    }

    private func completeSetup() {
        settings.hasCompletedSetup = true
        if !proxy.isRunning && proxy.state != .starting {
            proxy.start(settings: settings)
        }
        dismiss()
    }
}
