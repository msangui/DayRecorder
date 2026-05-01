import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager = RecordingManager.shared
    private var settings = SettingsStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon; app lives in menu bar
        NSApp.setActivationPolicy(.accessory)

        if settings.autoStartOnLaunch {
            Task {
                await manager.startRecording()
            }
        }

        Task { await PermissionsManager.shared.requestMicrophone() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard manager.status != .idle else { return .terminateNow }

        // Finalize recording before quit
        Task {
            await manager.stopRecording()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows { window.makeKeyAndOrderFront(nil) }
        }
        return true
    }
}
