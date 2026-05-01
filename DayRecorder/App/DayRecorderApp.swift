import SwiftUI

@main
struct DayRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var manager = RecordingManager.shared

    var body: some Scene {
        WindowGroup("DayRecorder") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra {
            menuBarContent
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.menu)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack {
            Image(systemName: manager.status.menuBarIcon)
            if manager.status == .recording {
                Text(formattedElapsed)
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }

    @ViewBuilder
    private var menuBarContent: some View {
        Text("DayRecorder – \(manager.status.displayName)")
            .font(.headline)

        Divider()

        if manager.status == .idle {
            Button("Start Recording") {
                Task { await manager.startRecording() }
            }
        } else {
            if manager.status == .recording {
                Button("Pause") { manager.pauseRecording() }
            } else if manager.status == .paused {
                Button("Resume") { manager.resumeRecording() }
            }
            Button("Stop Recording") {
                Task { await manager.stopRecording() }
            }
        }

        Divider()

        Button("Open DayRecorder") {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }

        Divider()

        Button("Quit") { NSApp.terminate(nil) }
    }

    private var formattedElapsed: String {
        let t = Int(manager.elapsedTime)
        let m = t / 60, s = t % 60
        return String(format: "%d:%02d", m, s)
    }
}
