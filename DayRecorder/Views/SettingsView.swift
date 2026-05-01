import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var showDirectoryPicker = false

    var body: some View {
        Form {
            Section("Output") {
                HStack {
                    Label(settings.outputDirectory.path, systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose...") { showDirectoryPicker = true }
                        .buttonStyle(.bordered)
                }
            }

            Section("Auto-split") {
                Picker("Split interval", selection: $settings.autoSplitInterval) {
                    ForEach(AutoSplitInterval.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
            }

            Section("Startup") {
                Toggle("Start recording automatically on launch", isOn: $settings.autoStartOnLaunch)
            }

            Section("Permissions") {
                PermissionsView()
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 360)
        .fileImporter(isPresented: $showDirectoryPicker,
                      allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                settings.setOutputDirectory(url)
            }
        }
    }
}
