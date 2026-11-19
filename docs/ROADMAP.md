# Roadmap

Updated 2026-11-19. Norishine's roadmap holds the full ranked list for both projects
([Next](https://github.com/Nori-Oppi/Norishine/blob/master/docs/ROADMAP.md#next)); the
numbers below match it.

## Done

- **Profiles, monitors and several streams at once**, the first-start wizard, Moonlight
  settings import. See [Features](https://github.com/Nori-Oppi/norilight-docs/wiki/Norilight-Features).
- **Managing a Norishine host**: Host Settings, Manage Host (apps, devices, displays,
  updates) and its Stats tab. See [Features](https://github.com/Nori-Oppi/norilight-docs/wiki/Norilight-Features#managing-a-norishine-host).
- **Automatic tuning**: reports to Norishine's adaptive bitrate, Tuning goals that pick
  launch settings and learn start bitrates per host and network, the host's encoder
  recommendations with Apply and Undo. See [Features](https://github.com/Nori-Oppi/norilight-docs/wiki/Norilight-Features#picture-and-performance).
- **Reset button** (N1): Settings › Reset Norilight moves the settings to a dated backup and
  restarts into the first-start wizard; `Norilight --reset` does the same. See
  [the guide](https://github.com/Nori-Oppi/norilight-docs/wiki/Norilight-Guide#resetting-norilight).
- **Benchmark check** (N2, with Norishine): Norishine with Norilight against stored Apollo,
  Vibepollo and Sunshine results with Moonlight. See [Checks](#checks).
- **Help links** (N3): the help buttons open
  [norilight-docs wiki](https://github.com/Nori-Oppi/norilight-docs/wiki), written for Norilight and
  Norishine, instead of moonlight-docs.
- **Norishine setup wizard and reset** (N4, Norishine): a first-start wizard in the host's
  web UI (import, name, display, encoder check, first device) and Reset Norishine. After a
  host reset, Norilight sees a new host and pairs again. See
  [the Norishine guide](https://github.com/Nori-Oppi/norilight-docs/wiki/Norishine-Guide#first-start).
- **Near-instant stream start** (N5, with Norishine): the audio device is opened once, in the
  background, and each decoder check is made once per launch; the log shows every step to the
  first frame. Launch 1060 → 895 ms, resume 975 → 824 ms. See
  [Norishine's BENCHMARK.md](https://github.com/Nori-Oppi/Norishine/blob/master/docs/BENCHMARK.md#stream-start-start_timepy).
- **Optimise** (N6, with Norishine): short test streams of the host's test picture pick the
  profile's codec and bitrate (and a lower frame rate or resolution when needed), saved with
  Undo; the host's encoder test picks its preset. See
  [the guide](https://github.com/Nori-Oppi/norilight-docs/wiki/Norilight-Guide#optimise).
- **Settings during a stream** (N9, with Norishine): Ctrl+Alt+Shift+O opens Stream settings in
  the overlay: bitrate, error correction, encoder preset, resolution, frame rate and codec
  change without reconnecting (the decoder is rebuilt behind one key frame, 125–440 ms of
  picture); the host's own settings apply at once too. See
  [the guide](https://github.com/Nori-Oppi/norilight-docs/wiki/Norilight-Guide#changing-settings-during-a-stream).
- **Through a host update** (N10, with Norishine): when the host says it restarts (an update or
  a restart for its settings), Norilight waits for it and starts the same app again by itself;
  its own part is half a second. A real handover isn't planned (see
  [Norishine's BENCHMARK.md](https://github.com/Nori-Oppi/Norishine/blob/master/docs/BENCHMARK.md#reconnect-after-a-host-restart-n10)).

## Next

In order. Effort: **S** days, **M** one to two weeks, **L** several weeks, **XL** a month or
more.

| # | Item | Effort | Notes |
| --- | --- | --- | --- |
| N7 | Linux build | M | Moonlight's Linux build code is kept: CI, AppImage or Flatpak, check Norilight's own features |
| N8 | Separate command-line build | M | `norilight-cli` without the Qt GUI: pair, list, stream, quit |
| N12 | Android build, for handhelds | XL | Qt for Android or a start from Artemis, decided by a short spike; controller-first, battery-aware |
| N13 | iOS build | XL | After Android; installing unsigned builds needs sideloading |

Small fix, any time between the items above:

| # | Item | Effort | Notes |
| --- | --- | --- | --- |
| N14 | Fewer full-queue frame drops in the pacer | S–M | About 0.15–0.3 % of frames dropped when the pacer's queue is full; Moonlight 6.2.0 drops the same, so not a regression, but fewer would put Norilight ahead. Prove it with the benchmark check |

Existing Sunshine hosts and Moonlight-compatible setups will keep working.

## Branches

Branch review: **18 November 2026**. Nightlies build `main`; check a build's commit
before assuming it contains a particular change.

| Branch | Changes | Status |
| --- | --- | --- |
| `host-settings` | Norishine status, schema-driven settings editing, per-field errors and host restart | Merged into `main` |
| `host-manage` | Manage Host page: apps, paired devices, streams and displays | Merged into `main` |
| `ci-speedup` | Windows compile caching, cached macOS deployment, parallel packaging and deployed-binary checks | Merged into `main` |
| `integrate-all-refs` | Earlier integration work | No unique commits beyond `main` |
| `dependabot/submodules/app/SDL_GameControllerDB-c0f11d4` | Controller database refresh | Included in `main` |

## Checks

Every pull request and push to `main` runs the `CI` workflow: the Windows x64 and macOS
builds, the Windows regression tests (`scripts\run-tests.bat`) and the installer checks.
Changes that only touch documentation skip it.

After any change to decoding, rendering or the network code, run Norishine's benchmark check
on the real PC with a release build of Norilight (`python scripts/benchmark/compare.py` in the
Norishine repository; see its
[BENCHMARK.md](https://github.com/Nori-Oppi/Norishine/blob/master/docs/BENCHMARK.md#check-against-apollo-vibepollo-and-sunshine))
and put the verdict in the pull request. A metric worse than Apollo, Vibepollo or Sunshine
with Moonlight is fixed before merging, or explained.

## Upstream

Norilight includes every bug fix from Moonlight PC's `master` up to
[`28629dc`](https://github.com/moonlight-stream/moonlight-qt/commit/28629dc1) (synced
17 November 2026).

## Building

Clone with submodules (`git clone --recursive`); Norilight uses its own fork of
`moonlight-common-c`, which adds Apollo server commands. Then follow
[BUILDING.md](../BUILDING.md) for Windows x64 or macOS. Linux and other upstream targets
keep Moonlight's build code but aren't built or tested here; see the
[upstream build notes](MOONLIGHT-README.md#building).
