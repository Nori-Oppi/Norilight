# Windows screenshot shortcut regression test

From an x64 Visual Studio Developer Command Prompt at the repository root:

```bat
cl /nologo /EHsc /std:c++17 /MD /Iapp /Ilibs\windows\include\x64\SDL2 tests\input\ScreenshotShortcutTest.cpp /Fobuild\ScreenshotShortcutTest.obj /Febuild\Norilight-x64-release\ScreenshotShortcutTest.exe /link libs\windows\lib\x64\SDL2.lib user32.lib
build\Norilight-x64-release\ScreenshotShortcutTest.exe
```

Requires the deployed SDL2/SDL3 DLLs in `build/Norilight-x64-release`.
The test checks preserved key combinations, balanced modifier injection, and
filtering of replayed keys. It briefly focuses a small SDL window and sends F24
to verify that real Windows input is excluded from the SDL event queue while a
registered client hotkey receives it exactly once. It restores the previous
foreground window. It does not trigger ShareX or capture/upload screenshots.
