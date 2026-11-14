<p align="center">
  <img src="app/res/norilight.svg" width="128" height="128" alt="Norilight icon: a seal pup's face inside the Moonlight ring">
</p>

<h1 align="center">Norilight</h1>

<p align="center">The cutest Moonlight client, for desktop users and gamers alike.</p>

Norilight streams your PC from [Sunshine](https://github.com/LizardByte/Sunshine),
[Apollo](https://github.com/ClassicOldSong/Apollo) or NVIDIA GameStream. It is a fork of
[Moonlight PC](https://github.com/moonlight-stream/moonlight-qt): everything Moonlight does
still works, with extras for using your PC remotely as well as for playing on it.

## What's new

**Easier settings.** Settings are split into sections with a search box, and every option
says in plain words what it does.

**For desktop use**
- Free cursor: the mouse can leave the stream, even in fullscreen, so you can drag onto other windows and monitors
- Keep the stream window on top, and reopen it where you left it
- Watch-only mode, to view the host without sending it any input
- Your own cursor over the stream, adjustable scroll speed and game-mode mouse speed

**For the picture**
- Fit, Fill or Stretch the stream to the window, optionally pinned to the top
- Type an exact bitrate, or ask for full-range colour
- A compact stats overlay, and a latency summary when the stream ends

**For controllers**
- Stick deadzone, and scrolling with a stick when a controller acts as a mouse
- Switches for motion sensors and for using the touchpad as a mouse

**For Apollo hosts**
- Stream from a virtual display that matches your screen, with a resolution scale
- Clipboard sync, kept out of Windows clipboard history
- Run the host's server commands mid-stream with Ctrl+Alt+Shift+R

## Building

Clone with submodules, because Norilight uses its own copy of `moonlight-common-c`:

```sh
git clone --recursive https://github.com/azijnwater/Norilight.git
```

Then follow [BUILDING.md](BUILDING.md) for Windows (x64) or macOS on Apple Silicon.

## Shortcuts while streaming

Moonlight's shortcuts all still work: Ctrl+Alt+Shift+Q quits, +Z releases the mouse,
+S shows stats, and so on. Norilight adds one:

| Shortcut | What it does |
| --- | --- |
| Ctrl+Alt+Shift+R | List the Apollo host's server commands. Press 1–9 to run one, Esc to close. |

## Credits

Norilight is built on [Moonlight PC](https://github.com/moonlight-stream/moonlight-qt) by the
Moonlight Game Streaming Project, and several features follow the Android client
[Artemis](https://github.com/ClassicOldSong/moonlight-android). Moonlight's original README is
in [docs/MOONLIGHT-README.md](docs/MOONLIGHT-README.md).

Licensed under the GNU General Public License v3, like Moonlight. See [LICENSE](LICENSE).
