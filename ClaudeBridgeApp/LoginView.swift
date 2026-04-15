import SwiftUI
import AppKit

struct LoginView: View {
    var proxy: ProxyManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "person.badge.key")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("GitHub Device Authentication")
                .font(.headline)

            if let code = proxy.loginDeviceCode {
                // Code + copy
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
                            copyToClipboard(code)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy code")
                    }

                    // Open GitHub link (also copies the code)
                    if let urlString = proxy.loginDeviceURL,
                       let url = URL(string: urlString) {
                        Button {
                            copyToClipboard(code)
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
                }
            } else {
                // Waiting for device code
                ProgressView()
                    .controlSize(.small)
                Text("Requesting device code...")
                    .foregroundStyle(.secondary)
            }

            // Bottom: waiting indicator + cancel
            if proxy.isLoggingIn {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for authentication...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Cancel") {
                proxy.cancelLogin()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(30)
        .frame(width: 400)
        .fixedSize()
        .onChange(of: proxy.isLoggingIn) { old, new in
            // Auto-close when auth completes
            if old == true && new == false {
                // Brief delay so checkCopilotInfo can run
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
        .onDisappear {
            // If window is closed while still logging in, cancel
            if proxy.isLoggingIn {
                proxy.cancelLogin()
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

