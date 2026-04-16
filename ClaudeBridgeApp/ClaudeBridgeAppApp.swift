//
//  ClaudeBridgeAppApp.swift
//  ClaudeBridgeApp
//
//  Created by 许浩渊 on 2026/4/15.
//

import SwiftUI
import UserNotifications
import Sparkle

@main
struct ClaudeBridgeAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settings = SettingsStore()
    @State private var proxy = ProxyManager()
    @Environment(\.openWindow) private var openWindow

    // Sparkle updater
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        // MARK: Menu Bar
        MenuBarExtra {
            MenuBarContent(
                settings: settings,
                proxy: proxy,
                updater: updaterController.updater
            )
                .task {
                    // One-time setup when the menu bar extra is created
                    proxy.checkCopilotInfo(autoFillSettings: settings)
                    if !settings.hasCompletedSetup {
                        openWindow(id: "setup")
                        activateAppAndWindows()
                    } else if settings.autoStart && !proxy.isRunning {
                        proxy.start(settings: settings)
                    }
                }
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.menu)

        // MARK: Setup Wizard
        Window("Setup", id: "setup") {
            SetupView(settings: settings, proxy: proxy)
        }
        .windowResizability(.contentSize)

        // MARK: Settings Window
        Window("Settings", id: "settings") {
            SettingsView(settings: settings, proxy: proxy)
        }
        .defaultSize(width: 450, height: 360)
        .windowResizability(.contentSize)

        // MARK: Logs Window
        Window("Logs", id: "logs") {
            LogView(proxy: proxy)
        }
        .defaultSize(width: 650, height: 450)

        // MARK: Login Window
        Window("Login", id: "login") {
            LoginView(proxy: proxy)
        }
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        switch proxy.state {
        case .running:
            Image(systemName: "network")
        case .starting:
            Image(systemName: "network")
                .symbolEffect(.pulse)
        case .error:
            Image(systemName: "network.badge.shield.half.filled")
        case .stopped:
            Image(systemName: "network.slash")
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission (for "Copied" feedback)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup is handled by ProxyManager
    }
}

// MARK: - Window Activation Helper

/// Brings the app and its windows to the front, even for menu-bar-only apps.
func activateAppAndWindows() {
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        // Only bring our own titled windows to front, skip Sparkle/system windows
        let knownTitles: Set<String> = ["Setup", "Settings", "Logs", "Login"]
        for window in NSApp.windows where window.isVisible && knownTitles.contains(window.title) {
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
