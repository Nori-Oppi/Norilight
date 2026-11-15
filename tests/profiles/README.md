# Profile regression tests

These tests use temporary INI settings, leaving real Norilight settings untouched.
Run scenarios in separate processes because active profile selection is process-local.

From a Visual Studio x64 developer prompt with Qt's bin directory on PATH:

```bat
mkdir build\profiles-tests
cd build\profiles-tests
qmake ..\..\tests\profiles\profiles.pro CONFIG+=release
nmake release
cd ..\..
powershell -NoProfile -ExecutionPolicy Bypass -File tests\profiles\run.ps1
```

`run.ps1` accepts `-QtDir` and `-Binary` for other installations. It writes a text
report per scenario beside the test build's release directory. The Windows build
uses the same prebuilt SDL2 dependency as the client.

Coverage includes fixed and automatic monitor preset migration, preserving legacy
settings, name collisions, retry safety, profile isolation, launch arguments,
missing displays, matching the chosen display, and the unified stream picker with
a long profile list.
