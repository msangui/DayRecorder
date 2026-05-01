import AVFoundation
import ScreenCaptureKit
import Combine

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var microphoneGranted: Bool = false
    @Published var screenCaptureGranted: Bool = false

    private init() {
        refresh()
    }

    func refresh() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        checkScreenCapture()
    }

    func requestMicrophone() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneGranted = granted
    }

    func requestScreenCapture() async {
        if #available(macOS 13.0, *) {
            do {
                let _ = try await SCShareableContent.current
                screenCaptureGranted = true
            } catch {
                screenCaptureGranted = false
            }
        }
    }

    private func checkScreenCapture() {
        if #available(macOS 13.0, *) {
            Task {
                do {
                    let _ = try await SCShareableContent.current
                    await MainActor.run { screenCaptureGranted = true }
                } catch {
                    await MainActor.run { screenCaptureGranted = false }
                }
            }
        } else {
            screenCaptureGranted = false
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}
