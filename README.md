# NoHUD

NoHUD is a tiny macOS menu-bar app that **suppresses the system volume and brightness HUD** (including the macOS Tahoe HUD) by intercepting the media keys and applying the changes itself — **without showing any replacement HUD**.

## How suppression works

- `NoHUD` installs a HID-level `CGEvent` tap (`.cghidEventTap`) for `NX_SYSDEFINED` events (type `14`) using `.defaultTap` so it can *consume* events.
- When a volume/brightness/mute key-down is detected (decoded from `NSEvent.data1`), the event tap returns `nil` to drop the event, so macOS never handles it and the system HUD never triggers.
- NoHUD then performs the action itself:
  - **Volume/mute**: CoreAudio (virtual main volume + mute).
  - **Brightness**: `DisplayServices` (built-in display only).
- Fail-safe: if setting volume/brightness fails, NoHUD stops consuming that key type and lets the event pass through to macOS until the next device/display change.

Key implementation: `NoHUD/MediaKeySuppressor.swift`.

## Permissions

- **Accessibility**: required to install a global HID event tap.

NoHUD can prompt for it, but macOS requires you to enable it in **System Settings → Privacy & Security → Accessibility**.

## Start at login

NoHUD includes a **Start at login** toggle (via `SMAppService.mainApp`). If macOS shows “Requires approval”, approve it in System Settings.

## Build / run

### Requirements

- **macOS**: 13.0+ (deployment target)
- **Xcode**: 16+ (this project builds in Swift 6 mode)

### Build & run (Xcode)

1. Open `NoHUD.xcodeproj` in Xcode.
2. Select the **`NoHUD`** scheme and your Mac as the run destination.
3. If Xcode prompts about signing, set a team:
   - Select the `NoHUD` target → **Signing & Capabilities** → choose a **Team** (a Personal Team is fine for local builds).
4. Build & Run (**⌘R**).
5. Find **NoHUD** in the **menu bar** (it won’t appear in the Dock).

### First run permissions (required for suppression)

- Grant **Accessibility**: System Settings → Privacy & Security → Accessibility → enable **NoHUD**.
- If the event tap still can’t be created on your macOS version, also try **Input Monitoring**.

### Build from Terminal (optional)

List schemes:

```bash
xcodebuild -project NoHUD.xcodeproj -list
```

Compile (CI-style, without signing):

```bash
xcodebuild -project NoHUD.xcodeproj -scheme NoHUD -configuration Release -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```
