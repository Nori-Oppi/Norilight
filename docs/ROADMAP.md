# Roadmap

Updated 2026-11-18. Norishine's roadmap holds the full ranked list for both projects
([Next](https://github.com/Nori-Oppi/Norishine/blob/master/docs/ROADMAP.md#next)); the
numbers below match it.

## Done

- **Profiles, monitors and several streams at once**, the first-start wizard, Moonlight
  settings import. See [FEATURES.md](FEATURES.md).
- **Managing a Norishine host**: Host Settings, Manage Host (apps, devices, displays,
  updates) and its Stats tab. See [FEATURES.md](FEATURES.md#managing-a-norishine-host).
- **Automatic tuning**: reports to Norishine's adaptive bitrate, Tuning goals that pick
  launch settings and learn start bitrates per host and network, the host's encoder
  recommendations with Apply and Undo. See [FEATURES.md](FEATURES.md#picture-and-performance).

## Next

In order. Effort: **S** days, **M** one to two weeks, **L** several weeks, **XL** a month or
more.

| # | Item | Effort | Notes |
| --- | --- | --- | --- |
| N1 | Reset button | S | Settings › Reset Norilight: settings moved to a backup, restart into the first-start wizard |
| N2 | Help links to `norilight-docs` | S | The guide and help buttons still open moonlight-docs; a new `Nori-Oppi/norilight-docs` repository replaces it |
| N4 | Comparison test suite (with Norishine) | M–L | Norilight against Moonlight, on Norishine, Apollo, Vibepollo and Sunshine |
| N5 | Near-instant stream start (with Norishine) | L | Measure each step to the first frame, then cut the slow ones |
| N6 | Auto-optimisation wizard (with Norishine) | M | Short test streams per setting, the best saved to the profile, with Undo |
| N7 | Linux build | M | Moonlight's Linux build code is kept: CI, AppImage or Flatpak, check Norilight's own features |
| N8 | Separate command-line build | M | `norilight-cli` without the Qt GUI: pair, list, stream, quit |
| N9 | Change settings during a stream (with Norishine) | L | Bitrate first, then resolution, frame rate and codec without reconnecting |
| N10 | Keep the stream through a host update (with Norishine) | L | Reconnect to the same app by itself when the host comes back |
| N12 | Android build, for handhelds | XL | Qt for Android or a start from Artemis, decided by a short spike; controller-first, battery-aware |
| N13 | iOS build | XL | After Android; installing unsigned builds needs sideloading |

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
