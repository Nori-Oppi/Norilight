// Standalone Windows test. Intercept replay so the test never captures or uploads.
#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <SDL_syswm.h>
#include <windows.h>
#include <vector>
#include <cstdio>
#include <cstdlib>
std::vector<INPUT> replay;
SHORT heldModifier = 0;
UINT WINAPI captureInput(UINT count, LPINPUT inputs, int size) {
    if (size != sizeof(INPUT)) std::abort();
    replay.assign(inputs, inputs + count);
    return count;
}
SHORT WINAPI modifierState(int key) { return key == heldModifier ? SHORT(0x8000) : 0; }
#define SendInput captureInput
#define GetAsyncKeyState modifierState
#include "streaming/input/localscreenshot.h"
#undef SendInput
#undef GetAsyncKeyState
void check(bool value, const char* label) {
    if (!value) { std::fprintf(stderr, "FAIL: %s\n", label); std::exit(1); }
}
int main() {
    SDL_KeyboardEvent event = {};
    event.keysym.scancode = SDL_SCANCODE_PRINTSCREEN;
    replayLocalScreenshotShortcut(&event);
    check(replay.size() == 2 && replay[0].ki.wVk == VK_SNAPSHOT, "plain PrtScn preserved");
    check(!(replay[0].ki.dwFlags & KEYEVENTF_KEYUP) && (replay[1].ki.dwFlags & KEYEVENTF_KEYUP), "balanced screenshot key");
    event.keysym.mod = KMOD_CTRL | KMOD_ALT;
    replayLocalScreenshotShortcut(&event);
    check(replay.size() == 6 && replay[0].ki.wVk == VK_CONTROL && replay[1].ki.wVk == VK_MENU && replay[2].ki.wVk == VK_SNAPSHOT, "modified PrtScn preserved");
    event.keysym.scancode = SDL_SCANCODE_S;
    event.keysym.mod = KMOD_GUI | KMOD_SHIFT;
    heldModifier = VK_SHIFT;
    replayLocalScreenshotShortcut(&event);
    check(replay.size() == 4 && replay[0].ki.wVk == VK_LWIN && replay[1].ki.wVk == 'S' && replay[3].ki.wVk == VK_LWIN, "Win Shift S preserves locally held Shift");
    for (const INPUT& input : replay) check(input.ki.dwExtraInfo == LocalScreenshotInputTag, "every injected event tagged");
    SDL_Event queued = {};
    queued.type = SDL_KEYDOWN;
    LPARAM old = SetMessageExtraInfo(LocalScreenshotInputTag);
    check(filterLocalScreenshotReplay(nullptr, &queued) == 0, "injected key down excluded from remote input");
    queued.type = SDL_KEYUP;
    check(filterLocalScreenshotReplay(nullptr, &queued) == 0, "injected key up excluded from remote input");
    queued.type = SDL_MOUSEMOTION;
    check(filterLocalScreenshotReplay(nullptr, &queued) == 1, "other input preserved");
    SetMessageExtraInfo(old);
    queued.type = SDL_KEYDOWN;
    check(filterLocalScreenshotReplay(nullptr, &queued) == 1, "physical keyboard input preserved");
    check(SDL_Init(SDL_INIT_VIDEO) == 0, "SDL video initialized");
    HWND previousFocus = GetForegroundWindow();
    SDL_Window* window = SDL_CreateWindow("Norilight keyboard routing test", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 240, 80, SDL_WINDOW_SHOWN);
    check(window != nullptr, "native test window created");
    SDL_RaiseWindow(window);
    SDL_SysWMinfo info = {};
    SDL_VERSION(&info.version);
    check(SDL_GetWindowWMInfo(window, &info) == SDL_TRUE, "native window handle");
    DWORD focusThread = GetWindowThreadProcessId(previousFocus, nullptr);
    AttachThreadInput(GetCurrentThreadId(), focusThread, TRUE);
    SetForegroundWindow(info.info.win.window);
    SetFocus(info.info.win.window);
    AttachThreadInput(GetCurrentThreadId(), focusThread, FALSE);
    SDL_Delay(100);
    check(GetForegroundWindow() == info.info.win.window, "test window has keyboard focus");
    SDL_Event pending;
    while (SDL_PollEvent(&pending)) {}
    int filtered = 0;
    SDL_SetEventFilter([](void* data, SDL_Event* input) -> int {
        int keep = filterLocalScreenshotReplay(nullptr, input);
        if (!keep) ++*static_cast<int*>(data);
        return keep;
    }, &filtered);
    INPUT probe[2] = {};
    for (int i = 0; i < 2; ++i) {
        probe[i].type = INPUT_KEYBOARD;
        probe[i].ki.wVk = VK_F24;
        probe[i].ki.dwFlags = i ? KEYEVENTF_KEYUP : 0;
        probe[i].ki.dwExtraInfo = LocalScreenshotInputTag;
    }
    check(SendInput(2, probe, sizeof(INPUT)) == 2, "native tagged input sent");
    bool leaked = false;
    for (int i = 0; i < 30; ++i) {
        while (SDL_PollEvent(&pending)) {
            if ((pending.type == SDL_KEYDOWN || pending.type == SDL_KEYUP) && pending.key.keysym.scancode == SDL_SCANCODE_F24) leaked = true;
        }
        SDL_Delay(10);
    }
    int hotkeyCount = 0;
    SDL_SetWindowsMessageHook([](void* data, void*, unsigned int message, Uint64, Sint64) {
        if (message == WM_HOTKEY) ++*static_cast<int*>(data);
    }, &hotkeyCount);
    check(RegisterHotKey(info.info.win.window, 1, MOD_NOREPEAT, VK_F24) != 0, "test client global hotkey registered");
    check(SendInput(2, probe, sizeof(INPUT)) == 2, "tagged input replayed to registered hotkey");
    for (int i = 0; i < 30; ++i) {
        while (SDL_PollEvent(&pending)) {}
        SDL_Delay(10);
    }
    UnregisterHotKey(info.info.win.window, 1);
    SDL_SetWindowsMessageHook(nullptr, nullptr);
    SDL_SetEventFilter(nullptr, nullptr);
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (previousFocus) SetForegroundWindow(previousFocus);
    check(hotkeyCount == 1, "client global hotkey receives replay exactly once");
    check(filtered >= 2 && !leaked, "real Windows injected input filtered by installed SDL runtime");
    std::puts("PASS: shortcut keys, modifiers, held modifiers, replay tags and native Windows/SDL replay filtering");
}
