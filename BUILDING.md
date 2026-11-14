# Building Norilight

Norilight builds the same way as Moonlight PC, which it is forked from. You need
Qt 6, a C++ compiler, and a set of prebuilt libraries (FFmpeg, SDL, Opus and so
on) that a script downloads for you.

- [Windows (x64)](#windows-x64)
- [macOS on Apple Silicon](#macos-on-apple-silicon)
- [Troubleshooting](#troubleshooting)

Always clone with submodules. Norilight uses its own fork of
`moonlight-common-c` (it adds Apollo server commands), so a plain clone will not
build.

```sh
git clone --recursive https://github.com/azijnwater/Norilight.git
cd Norilight
```

If you already cloned without `--recursive`:

```sh
git submodule update --init --recursive
```

---

## Windows (x64)

### 1. Install the tools

| Tool | What to pick |
| --- | --- |
| [Visual Studio 2026](https://visualstudio.microsoft.com/downloads/) (Community is fine) | The **Desktop development with C++** workload |
| [Qt 6.11](https://www.qt.io/download-qt-installer-oss) (online installer, free account) | Under *Qt 6.11.x*, tick **MSVC 2022 64-bit**. Nothing else is needed. MinGW is not supported. |
| [Git for Windows](https://git-scm.com/download/win) | Defaults are fine |
| [Python 3](https://www.python.org/downloads/) | Only for the alternative Qt download below |

The build script expects Qt in `C:\Qt\6.11.3\msvc2022_64`. If yours is somewhere
else (for example a newer 6.11.x), set `QT_DIR` before building:

```bat
set QT_DIR=C:\Qt\6.11.4\msvc2022_64
```

> **No Qt account?** `aqtinstall` can't read the folder layout Qt uses for 6.11
> yet. You can download the official archives straight from
> `https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/qt6_6113/qt6_6113_msvc2022_64/`:
> read `Updates.xml`, get the `qtbase`, `qtdeclarative`, `qtsvg`, `qttools`,
> `qttranslations` and `d3dcompiler_47` `.7z` files from the
> `qt.qt6.6113.win64_msvc2022_64` package, check each against its `.sha1`, and
> extract them all into `C:\Qt\6.11.3\msvc2022_64`.

### 2. Download the prebuilt libraries

From the repository folder, in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File setup-deps.ps1
```

This fills `libs\windows`. Run it again whenever you pull new changes.

### 3. Build

From a normal Command Prompt in the repository folder:

```bat
scripts\build-norilight.bat release
```

The script finds Visual Studio by itself, compiles, and copies everything needed
to run into one folder:

```
build\Norilight-x64-release\Norilight.exe
```

Use `debug` instead of `release` for a debug build. Later builds only recompile
what changed.

### Optional: installer and portable zip

The upstream release scripts still work for full packages. They also need
[7-Zip](https://www.7-zip.org/) on your `PATH`, and they must be run from a *Qt
6.11 MSVC 2022 64-bit* command prompt:

```bat
scripts\build-arch.bat release
scripts\generate-bundle.bat release
```

---

## macOS on Apple Silicon

These steps build a native arm64 app for M-series Macs.

### 1. Install the tools

1. **Xcode** from the App Store (version 15 or later). Open it once so it can
   finish installing its components, then run:
   ```sh
   sudo xcode-select -s /Applications/Xcode.app
   ```
2. **Qt 6.11 for macOS**, either way works:
   - **Qt online installer** ([download](https://www.qt.io/download-qt-installer-oss)):
     under *Qt 6.11.x*, tick **macOS**. Qt's tools end up in
     `~/Qt/6.11.x/macos/bin`.
   - **Homebrew**: `brew install qt`. Make sure `qmake --version` reports
     Qt 6.11 or later.
3. **Python 3**, which comes with Xcode's command line tools.

Put Qt's `bin` folder on your `PATH` for the current terminal:

```sh
# Qt online installer
export PATH="$HOME/Qt/6.11.3/macos/bin:$PATH"
# or Homebrew
export PATH="$(brew --prefix qt)/bin:$PATH"
```

### 2. Download the prebuilt libraries

```sh
python3 setup-deps.py
```

This fills `libs/mac` with universal (arm64 + x86_64) libraries. Run it again
whenever you pull new changes.

### 3. Build

```sh
mkdir -p build/build-Release && cd build/build-Release
qmake ../../moonlight-qt.pro QMAKE_APPLE_DEVICE_ARCHS=arm64
make -j"$(sysctl -n hw.ncpu)" release
```

The app is at `build/build-Release/app/Norilight.app`. Run it with:

```sh
open app/Norilight.app
```

This build loads Qt from your Qt install, so it only runs on the Mac that built
it. To get an app you can copy to another Mac, make a DMG instead (next step).

### Optional: DMG you can share

Install [create-dmg](https://github.com/sindresorhus/create-dmg) (it needs
Node.js), then run from the repository root:

```sh
npm install --global create-dmg
scripts/generate-dmg.sh Release
```

The DMG is written to `build/installer-Release/`. It is unsigned, so the first
time you open the app on another Mac, right-click it and choose **Open**, or
clear the quarantine flag:

```sh
xattr -dr com.apple.quarantine /Applications/Norilight.app
```

To sign and notarize, set `SIGNING_IDENTITY` and `NOTARY_KEYCHAIN_PROFILE`
before running the script, as in upstream Moonlight.

---

## Troubleshooting

- **`moonlight-common-c` errors such as `LiSendExecServerCmd` not found.** The
  submodule is on the wrong commit. Run
  `git submodule update --init --recursive`.
- **Windows: "Qt not found".** Set `QT_DIR` to the folder that contains
  `bin\qmake.exe`.
- **Windows: "Prebuilt deps missing".** Run `setup-deps.ps1` first.
- **macOS: `qmake: command not found`.** Qt's `bin` folder isn't on your
  `PATH` (see step 1).
- **macOS: "Norilight is damaged and can't be opened".** That's Gatekeeper
  blocking an unsigned download. Use the `xattr` command above.
- **Settings are separate from Moonlight.** Norilight saves its settings and
  paired PCs under its own name, so you need to pair once even if Moonlight is
  already paired.
