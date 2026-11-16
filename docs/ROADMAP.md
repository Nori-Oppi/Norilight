# Roadmap

Planned, not available yet:

- **Automatic hardware and network tuning** to help pick good streaming settings.
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

## Building

Clone with submodules (`git clone --recursive`); Norilight uses its own fork of
`moonlight-common-c`, which adds Apollo server commands. Then follow
[BUILDING.md](../BUILDING.md) for Windows x64 or macOS. Linux and other upstream targets
keep Moonlight's build code but aren't built or tested here; see the
[upstream build notes](MOONLIGHT-README.md#building).
