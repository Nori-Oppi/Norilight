# Norilight guide

## Getting started

1. **Install.** Download from the [nightly release](https://github.com/Nori-Oppi/Norilight/releases/tag/nightly):
   - **Windows x64:** run the `-Setup.exe`. To skip installing, extract the ZIP and run
     `Norilight.exe` instead.
   - **macOS (Apple Silicon and Intel):** open the DMG and drag Norilight to Applications.
     Nightlies are unsigned, so right-click the app and choose **Open** the first time.
     Allow Local Network access when asked, or Norilight can't find your PC.
2. **Pick a starting profile.** On first launch, Norilight asks how you'll use it:

   | Starting point | What it sets up |
   | --- | --- |
   | **Gaming** | Fullscreen, V-Sync and frame pacing off, mouse captured. Frame rate follows your main display (60–240 FPS). |
   | **Work and desktop** | Borderless fullscreen at 60 FPS, V-Sync on, direct mouse control, and a cursor that can leave the stream. |
   | **Standard** | Norilight's defaults, ready to customise. |
   | **Existing settings** | Keep your current settings, copy the active profile, or import Moonlight's settings if they're on this PC. Moonlight's own settings are left untouched. |

3. **Pair with your host.** Your PC appears automatically on most networks. If it
   doesn't, add it by IP address with the **+** button.

## Managing a Norishine host

With [Norishine](https://github.com/Nori-Oppi/Norishine) on the host, right-click it and
choose **Host Settings** (settings, restart) or **Manage Host** (apps, paired
devices and displays). First allow it on the host: in its web UI, open **Devices**, edit
this device, and under **Host management** choose **View** or **Manage**. Norilight signs
in with the certificate from pairing, never the web UI password.

## Updating

Norilight checks for a newer nightly each time it starts. When one is available, an update
button appears in the toolbar. Click it and choose **Install and restart**:

- **Windows (installed):** Norilight downloads the new installer, checks it, and installs
  it over the current version. Windows asks for permission, then Norilight reopens.
- **Windows (ZIP):** Norilight downloads the new ZIP and replaces its own files once it
  has closed, keeping your portable settings, then reopens.
- **macOS:** Norilight downloads the new DMG and replaces the app in place, then reopens.
  If it can't write to the app's folder, it opens the DMG so you can drag the app over.

Settings live in your user profile (or next to `Norilight.exe` for the ZIP), so updates
keep them. Uninstalling on Windows also leaves them in place.

The version shown in Norilight (top right of Settings, or `Norilight --version`) is the
nightly's name, such as `nightly-20261115-0f4841b`: the build date and commit.

New nightlies are built daily at 20:17 Europe/Amsterdam time, when `main` has changed.
They are unsigned pre-releases. Builds you compile yourself don't check for updates.

## Shortcuts while streaming

**Settings > Shortcuts** lists every keyboard and controller shortcut. The most useful:

| Shortcut | What it does |
| --- | --- |
| Ctrl+Alt+Shift+Q | End the stream |
| Ctrl+Alt+Shift+Z | Release or recapture the mouse and keyboard |
| Ctrl+Alt+Shift+X | Switch between fullscreen and windowed |
| Ctrl+Alt+Shift+L | Keep the cursor inside the stream window, or let it out |
| Ctrl+Alt+Shift+K | Send system keys to the host, or keep them on this PC |
| Ctrl+Alt+Shift+V | Type this PC's clipboard text into the host |
| Ctrl+Alt+Shift+S | Show or hide performance stats |
| Ctrl+Alt+Shift+R | List Apollo server commands (1–9 runs one, Esc closes) |

## Command line

`Norilight pair <host> --pin 1234`, `Norilight stream <host> <app>`, `Norilight list <host>`
and `Norilight quit <host>` work as in Moonlight; `Norilight --help` lists the options.
Scripts that capture Norilight's output must keep reading it while it runs. If nobody
reads the pipe, Norilight pauses as soon as it fills, which can make pairing time out.

## More

- [Features](FEATURES.md), with screenshots
- [Roadmap and branches](ROADMAP.md)
- [Building](../BUILDING.md)
