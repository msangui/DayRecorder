import SwiftUI

struct PermissionsView: View {
    @ObservedObject private var permissions = PermissionsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions").font(.headline)
            permissionRow(
                icon: "mic.fill",
                title: "Microphone",
                granted: permissions.microphoneGranted,
                action: {
                    Task { await permissions.requestMicrophone() }
                }
            )
            permissionRow(
                icon: "display",
                title: "Screen Recording",
                granted: permissions.screenCaptureGranted,
                action: {
                    Task { await permissions.requestScreenCapture() }
                }
            )
            Button("Open Privacy & Security Settings") {
                permissions.openPrivacySettings()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .onAppear { permissions.refresh() }
    }

    private func permissionRow(icon: String, title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(granted ? .green : .orange)
            Text(title)
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Button("Request", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Label("Missing", systemImage: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }
}
