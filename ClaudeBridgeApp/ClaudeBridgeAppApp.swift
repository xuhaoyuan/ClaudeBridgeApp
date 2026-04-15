//
//  ClaudeBridgeAppApp.swift
//  ClaudeBridgeApp
//
//  Created by 许浩渊 on 2026/4/15.
//

import SwiftUI
import UserNotifications

@main
struct ClaudeBridgeAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settings = SettingsStore()
    @State private var proxy = ProxyManager()

    var body: some Scene {
        // MARK: Menu Bar
        MenuBarExtra {
            MenuBarContent(settings: settings, proxy: proxy)
                .task {
                    // One-time setup when the menu bar extra is created
                    proxy.checkCopilotInfo(autoFillSettings: settings)
                    if settings.autoStart && !proxy.isRunning {
                        proxy.start(settings: settings)
                    }
                }
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.menu)

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
