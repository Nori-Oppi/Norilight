# Roadmap

Planned, not available yet:

- **Automatic hardware and network tuning**: Norishine adapts the bitrate during a stream
  from Norilight's reports, and each profile's Tuning goal picks launch settings and learns
  start bitrates per host and network. Next: recommendations for the host's own encoder
  settings from what streams measured.
- More Norishine diagnostics as the host adds them (host stats and per-session metrics).

Existing Sunshine hosts and Moonlight-compatible setups will keep working.

## Branches

Branch review: **16 November 2026**. Nightlies build `main`; check a build's commit
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
