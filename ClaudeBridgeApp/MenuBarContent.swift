import SwiftUI
import AppKit
import UserNotifications
import Sparkle

struct MenuBarContent: View {
    var settings: SettingsStore
    var proxy: ProxyManager
    var updater: SPUUpdater
    @Environment(\.openWindow) private var openWindow

    private var isLoggedIn: Bool { proxy.isLoggedIn }

    var body: some View {
        // MARK: Status
        statusSection

        Divider()

        // MARK: Warnings
        if !proxy.isInstalled {
            Label("⚠ copilot-api not installed", systemImage: "exclamationmark.triangle")
        }
        if !settings.isModelSelected && settings.hasCompletedSetup {
            Label("⚠ Models not configured", systemImage: "exclamationmark.triangle")
        }

        // MARK: Controls
        controlsSection

        Divider()

        // MARK: Tools
        toolsSection

        Divider()

        // MARK: Login
        loginSection

        Divider()

        // MARK: Setup
        if !settings.hasCompletedSetup {
            Button {
                openWindow(id: "setup")
                NSApp.activate()
            } label: {
                Label("Setup Wizard...", systemImage: "wand.and.stars")
            }
            Divider()
        }

        // MARK: Quit
        Button {
            proxy.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        } label: {
            Label("Quit", systemImage: "power")
        }
        .keyboardShortcut("q")
    }

    // MARK: - Sections

    @ViewBuilder
    private var statusSection: some View {
        switch proxy.state {
        case .running:
            Label("Running on :\(settings.port)", systemImage: "circle.fill")
        case .starting:
            Label("Starting...", systemImage: "circle.dotted")
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
        case .stopped:
            Label("Stopped", systemImage: "circle")
        }
    }

    @ViewBuilder
    private var controlsSection: some View {
        if proxy.isRunning || proxy.state == .starting {
            Button {
                proxy.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
        } else {
            Button {
                proxy.start(settings: settings)
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .disabled(!proxy.isInstalled || !isLoggedIn || !settings.isModelSelected)
        }

        Button {
            proxy.restart(settings: settings)
        } label: {
            Label("Restart", systemImage: "arrow.clockwise")
        }
        .disabled(!proxy.isRunning)
    }

    @ViewBuilder
    private var toolsSection: some View {
        Button {
            openWindow(id: "settings")
            NSApp.activate()
        } label: {
            Label("Settings...", systemImage: "gearshape")
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(settings.claudeCommand, forType: .string)
            sendCopiedNotification()
        } label: {
            Label("Copy Claude Command", systemImage: "doc.on.clipboard")
        }
        .disabled(!isLoggedIn || !settings.isModelSelected)

        Button {
            let urlString = "https://ericc-ch.github.io/copilot-api?endpoint=http://localhost:\(settings.port)/usage"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Label("Usage Viewer", systemImage: "chart.bar")
        }
        .disabled(!isLoggedIn)

        Button {
            openWindow(id: "logs")
            NSApp.activate()
        } label: {
            Label("View Logs", systemImage: "doc.text")
        }

        Button {
            updater.checkForUpdates()
        } label: {
            Label("Check for Updates...", systemImage: "arrow.down.circle")
        }
        .disabled(!updater.canCheckForUpdates)
    }

    @ViewBuilder
    private var loginSection: some View {
        if let user = proxy.loginUser {
            Label("Login: \(user)", systemImage: "person.crop.circle.badge.checkmark")
            Button {
                proxy.logout(clearSettings: settings)
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } else {
            Label("Not logged in", systemImage: "person.crop.circle.badge.xmark")
            Button {
                proxy.login()
                openWindow(id: "login")
                NSApp.activate()
            } label: {
                Label("Login...", systemImage: "person.badge.plus")
            }
            .disabled(!proxy.isInstalled)
        }
    }

    // MARK: - Helpers

    private func sendCopiedNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Copilot API Proxy")
        content.body = String(localized: "Command copied to clipboard")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "command-copied",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
