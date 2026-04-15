import SwiftUI

struct SettingsView: View {
    var settings: SettingsStore
    var proxy: ProxyManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    // MARK: - Draft State (local copies, not saved until Apply/OK)

    @State private var draftPort: String = ""
    @State private var draftAutoStart: Bool = true
    @State private var draftLaunchAtLogin: Bool = false
    @State private var draftClaudeModel: String = ""
    @State private var draftSmallModel: String = ""
    @State private var draftAccountType: String = "individual"
    @State private var showRestoredAlert: Bool = false

    private var portIsValid: Bool {
        guard let port = Int(draftPort) else { return false }
        return (1...65535).contains(port)
    }

    private var hasChanges: Bool {
        draftPort != settings.port
        || draftAutoStart != settings.autoStart
        || draftLaunchAtLogin != settings.launchAtLogin
        || draftClaudeModel != settings.claudeModel
        || draftSmallModel != settings.smallModel
        || draftAccountType != settings.accountType
    }

    /// Model options: dynamic list, always includes current draft selections
    private var modelOptions: [CopilotModel] {
        var models = proxy.availableModels
        for id in [draftClaudeModel, draftSmallModel] where !id.isEmpty {
            if !models.contains(where: { $0.id == id }) {
                models.append(CopilotModel(id: id, ownedBy: "", displayName: id))
            }
        }
        return models
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Proxy") {
                    HStack {
                        Text("Port")
                        TextField("Port", text: $draftPort)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        if !draftPort.isEmpty && !portIsValid {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .help("Port must be 1–65535")
                        }
                    }
                    Toggle("Auto Start on Launch", isOn: $draftAutoStart)
                    Toggle("Launch at Login", isOn: $draftLaunchAtLogin)
                }

                Section {
                    Picker("Claude Model", selection: $draftClaudeModel) {
                        Text("Select a model...").tag("")
                        ForEach(modelOptions) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    Picker("Small / Fast Model", selection: $draftSmallModel) {
                        Text("Select a model...").tag("")
                        ForEach(modelOptions) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    if draftClaudeModel.isEmpty || draftSmallModel.isEmpty {
                        Label("Both models must be selected", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if proxy.availableModels.isEmpty {
                        Text("Start proxy to load model list, or refresh manually")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("⚠ Please select Claude models. Non-Claude models may cause Claude Code to malfunction.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    HStack {
                        Text("Model")
                        Spacer()
                        if proxy.isFetchingModels {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button {
                            proxy.fetchModels(port: draftPort.isEmpty ? settings.port : draftPort)
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!proxy.isRunning || proxy.isFetchingModels)
                        .help(proxy.isRunning ? "Refresh model list from server" : "Proxy must be running")
                    }
                }

                Section("Account") {
                    Picker("Account Type", selection: $draftAccountType) {
                        ForEach(SettingsStore.accountTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    if let plan = proxy.detectedPlan {
                        Text("Detected plan: \(plan)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Info") {
                    LabeledContent("copilot-api") {
                        if proxy.isInstalled {
                            Label("Installed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            VStack(alignment: .leading) {
                                Label("Not Found", systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Run: npm install -g copilot-api")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    LabeledContent("Path") {
                        Text(proxy.executablePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Claude Config") {
                        Button {
                            ClaudeSettingsManager.restore()
                            showRestoredAlert = true
                        } label: {
                            Label("Restore Defaults", systemImage: "arrow.uturn.backward")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove proxy settings from ~/.claude/settings.json")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // MARK: - Action Buttons
            HStack {
                Button {
                    dismiss()
                    openWindow(id: "setup")
                    NSApp.activate()
                } label: {
                    Label("Reconfigure...", systemImage: "wand.and.stars")
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    applyChanges()
                }
                .disabled(!hasChanges || !portIsValid)

                Button("OK") {
                    applyChanges()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!portIsValid)
            }
            .padding()
        }
        .frame(minWidth: 420, idealWidth: 450, minHeight: 420)
        .navigationTitle("Settings")
        .onAppear {
            loadDraft()
        }
        .alert("Claude Settings Restored", isPresented: $showRestoredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Proxy-related settings have been removed from ~/.claude/settings.json. Claude Code will use its default configuration.")
        }
    }

    // MARK: - Helpers

    private func loadDraft() {
        draftPort = settings.port
        draftAutoStart = settings.autoStart
        draftLaunchAtLogin = settings.launchAtLogin
        draftClaudeModel = settings.claudeModel
        draftSmallModel = settings.smallModel
        draftAccountType = settings.accountType
    }

    private func applyChanges() {
        settings.port = draftPort
        settings.autoStart = draftAutoStart
        settings.launchAtLogin = draftLaunchAtLogin
        settings.claudeModel = draftClaudeModel
        settings.smallModel = draftSmallModel
        settings.accountType = draftAccountType
    }
}
