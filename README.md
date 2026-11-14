# Norilight

Norilight is a desktop streaming client for [Sunshine](https://github.com/LizardByte/Sunshine),
[Apollo](https://github.com/ClassicOldSong/Apollo) and NVIDIA GameStream hosts. It is
a fork of [Moonlight PC](https://github.com/moonlight-stream/moonlight-qt), aimed as much
at everyday remote desktop use as at games.

It keeps everything Moonlight does and adds:

**A settings page you can find your way around**
- Sections in a sidebar, with search ("cursor", "codec", "clipboard"…)
- Every option has a plain name and a line saying what it actually does

**Desktop use**
- Free cursor: the mouse can leave the stream window, even in fullscreen, so you can drag onto other windows and monitors
- Keep the stream window on top, and reopen it where you left it
- Watch-only mode: view the host without sending it any input
- Show your own cursor over the stream, scroll speed, and game-mode mouse speed

**Picture and stats**
- Picture fit: Fit, Fill (crop) or Stretch, optionally pinned to the top
- Type in an exact bitrate; full-range colour
- Compact stats overlay and a latency summary when a stream ends

**Controllers**
- Stick deadzone, scrolling with a stick in controller-as-mouse mode
- Toggles for motion sensors and for using the touchpad as a mouse

**Apollo hosts**
- Stream from a virtual display that matches your screen, with a resolution scale
- Clipboard sync, kept out of Windows clipboard history by default
- Run the host's server commands during a stream (Ctrl+Alt+Shift+R)

## Building

See [BUILDING.md](BUILDING.md) for Windows (x64) and macOS on Apple Silicon.

Clone with submodules, because Norilight uses its own fork of `moonlight-common-c`:

```sh
git clone --recursive https://github.com/azijnwater/Norilight.git
```

## Keyboard shortcuts while streaming

All of Moonlight's shortcuts still work (Ctrl+Alt+Shift+Q to quit, +Z to release the
mouse, +S for stats, and so on). Norilight adds:

| Shortcut | What it does |
| --- | --- |
| Ctrl+Alt+Shift+R | List the Apollo host's server commands; press 1–9 to run one, Esc to close |

## Credits and license

Norilight is built on [Moonlight PC](https://github.com/moonlight-stream/moonlight-qt) by
the Moonlight Game Streaming Project. Several features follow the Android client
[Artemis](https://github.com/ClassicOldSong/moonlight-android). Moonlight's original
README is kept in [docs/MOONLIGHT-README.md](docs/MOONLIGHT-README.md).

Licensed under the GNU General Public License v3, like Moonlight. See [LICENSE](LICENSE).
