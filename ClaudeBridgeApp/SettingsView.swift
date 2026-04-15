import SwiftUI

struct SettingsView: View {
    var settings: SettingsStore
    var proxy: ProxyManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - Draft State (local copies, not saved until Apply/OK)

    @State private var draftPort: String = ""
    @State private var draftAutoStart: Bool = true
    @State private var draftLaunchAtLogin: Bool = false
    @State private var draftClaudeModel: String = "claude-sonnet-4.6"
    @State private var draftSmallModel: String = "claude-sonnet-4.6"
    @State private var draftAccountType: String = "individual"

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
        for id in [draftClaudeModel, draftSmallModel] {
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
                        ForEach(modelOptions) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    Picker("Small / Fast Model", selection: $draftSmallModel) {
                        ForEach(modelOptions) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    if proxy.availableModels.isEmpty {
                        Text("Start proxy to load model list, or refresh manually")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("Model")
                        Spacer()
                        Button {
                            proxy.fetchModels(port: draftPort.isEmpty ? settings.port : draftPort)
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!proxy.isRunning)
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
                }
            }
            .formStyle(.grouped)

            Divider()

            // MARK: - Action Buttons
            HStack {
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
