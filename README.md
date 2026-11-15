<p align="center">
  <img src="app/res/norilight.svg" width="128" height="128" alt="Norilight icon: a seal pup's face inside the Moonlight ring">
</p>

<h1 align="center">Norilight</h1>

<p align="center">The cutest Moonlight client, for desktop users and gamers alike.</p>

Norilight streams your PC from [Sunshine](https://github.com/LizardByte/Sunshine),
[Apollo](https://github.com/ClassicOldSong/Apollo) or NVIDIA GameStream. It is a fork of
[Moonlight PC](https://github.com/moonlight-stream/moonlight-qt): everything Moonlight does
still works, with extras for using your PC remotely as well as for playing on it.

## Download and install

Get the builds from the [rolling nightly release](https://github.com/azijnwater/Norilight/releases/tag/nightly):

- **Windows (x64):** run the `-Setup.exe` for a regular installation with a Start menu
  shortcut and an uninstaller. Later installers update the same installation and keep
  your settings. For running without installing, extract the ZIP and open `Norilight.exe`.
- **macOS (Apple Silicon and Intel):** open the universal DMG and drag Norilight to Applications.

The GitHub Actions workflow is scheduled for **20:00 Europe/Amsterdam** each day and
skips unchanged commits. Nightly builds are unsigned pre-releases. Windows and macOS
nightlies check for updates at launch; the update button opens the download in your
browser, and you install it yourself.

## What's new

**Profiles and monitors.** Keep separate settings for gaming, desktop work or any other
use. The first-run wizard offers Gaming, Work and desktop, and Standard starting points,
plus your existing Norilight or Moonlight settings when found. Create, copy, rename and
switch profiles from the toolbar or Settings. Language is shared across profiles.

Each profile can target a monitor and match its resolution and refresh rate. Choose a
profile when opening an app to launch its stream in a separate window while the main
window stays available. The Streams bar lets you track, stop and restart sessions.

**Easier settings.** Settings are split into sections with a search box, and every option
says in plain words what it does.

**For desktop use**
- Free cursor: the mouse can leave the stream, even in fullscreen, so you can drag onto other windows and monitors
- Keep the stream window on top, and reopen it where you left it
- Watch-only mode, to view the host without sending it any input
- Your own cursor over the stream, adjustable scroll speed and game-mode mouse speed
- On Windows, keep PrtScn and Win+Shift+S on this PC with **Take screenshots on this PC only**
  under Keyboard and touch. Your configured capture tool, such as ShareX, handles the shortcut.

**For the picture**
- Fit, Fill or Stretch the stream to the window, optionally pinned to the top
- Type an exact bitrate, or ask for full-range colour
- A compact stats overlay, and a latency summary when the stream ends

**For controllers**
- Stick deadzone, and scrolling with a stick when a controller acts as a mouse
- Switches for motion sensors and for using the touchpad as a mouse

**For Apollo hosts**
- Stream from a virtual display that matches your screen, with a resolution scale
- Text clipboard sync, with an option to keep host text out of Windows clipboard history
- Run the host's server commands mid-stream with Ctrl+Alt+Shift+R

## Building

Clone with submodules, because Norilight uses its own copy of `moonlight-common-c`:

```sh
git clone --recursive https://github.com/azijnwater/Norilight.git
```

Then follow [BUILDING.md](BUILDING.md) for Windows (x64) or macOS on Apple Silicon.

## Shortcuts while streaming

The full list is also available under **Settings > Shortcuts**.

| Shortcut | What it does |
| --- | --- |
| Ctrl+Alt+Shift+Q | End the stream. |
| Ctrl+Alt+Shift+E | End the stream and close Norilight. |
| Ctrl+Alt+Shift+Z | Release or recapture the mouse and keyboard. |
| Ctrl+Alt+Shift+X | Switch between fullscreen and a window. |
| Ctrl+Alt+Shift+D | Minimize the stream window. |
| Ctrl+Alt+Shift+M | Toggle remote desktop mouse mode. |
| Ctrl+Alt+Shift+C | Show or hide this PC's cursor in remote desktop mouse mode. |
| Ctrl+Alt+Shift+L | Lock the cursor inside the stream window or let it out. |
| Ctrl+Alt+Shift+K | Send system keys to the host or keep them on this PC. |
| Ctrl+Alt+Shift+V | Type this PC's clipboard text into the host. |
| Ctrl+Alt+Shift+S | Show or hide performance stats. |
| Ctrl+Alt+Shift+R | List the Apollo host's server commands. Press 1–9 to run one, Esc to close. |

## Credits

Norilight is built on [Moonlight PC](https://github.com/moonlight-stream/moonlight-qt) by the
Moonlight Game Streaming Project, and several features follow the Android client
[Artemis](https://github.com/ClassicOldSong/moonlight-android). Moonlight's original README is
in [docs/MOONLIGHT-README.md](docs/MOONLIGHT-README.md).

Licensed under the GNU General Public License v3, like Moonlight. See [LICENSE](LICENSE).
