import SwiftUI

struct ContentView: View {
    @State private var selectedRecording: Recording? = nil
    @State private var showSettings = false
    @ObservedObject private var manager = RecordingManager.shared

    var body: some View {
        VStack(spacing: 0) {
            RecordingControlsView()
            Divider()
            HSplitView {
                RecordingListView(selected: $selectedRecording)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)

                detailPane
                    .frame(minWidth: 340, maxWidth: .infinity)
            }
            .frame(minHeight: 400)
        }
        .frame(minWidth: 680, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .help("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showSettings = false }
                    }
                }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let rec = selectedRecording {
            RecordingDetailView(recording: rec)
                .id(rec.id)
        } else {
            VStack {
                Spacer()
                Image(systemName: "waveform.badge.microphone")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary)
                Text("Select a recording")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}
