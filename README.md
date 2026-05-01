# DayRecorder

A native macOS menu bar app for local audio recording — microphone + system audio, mixed into a single m4a file.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later

## Setup

1. Open `DayRecorder.xcodeproj` in Xcode.
2. Select your development team in **Signing & Capabilities** for the `DayRecorder` target.
3. Build and run (`⌘R`).

## Permissions

Two permissions are required:

| Permission | Why | How to grant |
|---|---|---|
| Microphone | Capture mic audio | macOS will prompt on first use |
| Screen Recording | Capture system audio via ScreenCaptureKit | System Settings → Privacy & Security → Screen Recording |

The in-app **Permissions** panel (inside Settings) shows current status and has a button to open Privacy & Security directly.

## Usage

- The app runs from the **menu bar**. Click the waveform icon to see controls.
- Click **Open DayRecorder** to open the main window.
- Type an optional title, then click **Record**.
- Click **Stop** to finalize the file.
- The **recordings library** on the left lists all saved files with play, rename, reveal, and delete actions.

## File Naming

Files are saved as:

```
YYYY-MM-DD_HH-mm_Title.m4a
```

If no title is provided: `YYYY-MM-DD_HH-mm_Recording.m4a`

Illegal filesystem characters (`/ \ : * ? " < > |`) are replaced with `_`.

## Settings

| Setting | Default | Description |
|---|---|---|
| Output directory | `~/Documents/DayRecorder` | Where recordings are saved |
| Auto-split | Off | Automatically stop & restart after 30/60/120 min |
| Auto-start on launch | Off | Begin recording when app opens |

## Architecture

```
DayRecorder/
├── App/
│   ├── DayRecorderApp.swift      # @main, MenuBarExtra, Settings scene
│   └── AppDelegate.swift         # Quit-while-recording safety, auto-start
├── Models/
│   ├── Recording.swift           # Codable struct, formatted properties
│   └── RecordingState.swift      # RecordingStatus enum, AutoSplitInterval
├── Services/
│   ├── RecordingManager.swift    # Orchestrates mic + system audio + mixer
│   ├── MicrophoneCaptureService.swift  # AVCaptureSession mic input
│   ├── SystemAudioCaptureService.swift # SCStream system audio (macOS 13+)
│   ├── AudioMixerService.swift   # AVAssetWriter → m4a output
│   ├── RecordingLibraryStore.swift    # JSON store, reconcile on launch
│   ├── PermissionsManager.swift  # AVFoundation + SCShareableContent checks
│   └── SettingsStore.swift       # UserDefaults-backed settings
├── Views/
│   ├── ContentView.swift         # Root split view + toolbar
│   ├── RecordingControlsView.swift  # Start/Stop/Pause + timer + title
│   ├── RecordingListView.swift   # Sidebar list with search & context menu
│   ├── RecordingDetailView.swift # Play, metadata, rename, delete
│   ├── PermissionsView.swift     # Permission status rows
│   └── SettingsView.swift        # Form with directory picker & toggles
└── Utilities/
    ├── FileNaming.swift          # Filename generation & sanitization
    └── Logger.swift              # Local log file at ~/Library/Application Support/DayRecorder/
```

## Known Limitations

- **System audio** requires macOS 13+ and Screen Recording permission. On older OS or without permission, only mic is captured and a warning banner is shown.
- **App Sandbox is disabled** to allow ScreenCaptureKit system audio without SIP restrictions. This means the app cannot be distributed via the Mac App Store without additional entitlement review.
- **Pause** suspends the timer display but does not pause the underlying AVAssetWriter — audio continues to be written during "pause" in the current MVP. A proper pause would require flushing the writer and reopening it.
- **Auto-split** stops and immediately starts a new recording; there is a brief gap (~1s) between segments.
- **Duration** for reconciled/orphan files is shown as 0:00 until the file is re-opened in the app (the actual asset duration is not probed at reconcile time to keep startup fast).

## Log file

Errors and events are written to:

```
~/Library/Application Support/DayRecorder/dayrecorder.log
```

## Tests

Unit tests cover:

- `FileNamingTests` — default name, custom title, illegal char sanitization, unique URL generation
- `RecordingModelTests` — formatted duration, Codable round-trip
- `SettingsTests` — default output directory, AutoSplitInterval raw values

Run with `⌘U` in Xcode or:

```sh
xcodebuild test -project DayRecorder.xcodeproj -scheme DayRecorder -destination 'platform=macOS'
```
