#pragma once

#include "SDL_compat.h"
#include <windows.h>

namespace {
constexpr ULONG_PTR LocalScreenshotInputTag = 0x4E4C5353;
SDL_EventFilter previousScreenshotFilter = nullptr;
void* previousScreenshotFilterData = nullptr;
bool screenshotFilterInstalled = false;

int SDLCALL filterLocalScreenshotReplay(void*, SDL_Event* event)
{
    // Replayed input belongs to the client's global hotkey handler. Do not
    // interpret it as a new remote shortcut if it also reaches our window.
    if ((event->type == SDL_KEYDOWN || event->type == SDL_KEYUP) &&
            static_cast<ULONG_PTR>(GetMessageExtraInfo()) == LocalScreenshotInputTag) {
        return 0;
    }
    return previousScreenshotFilter ? previousScreenshotFilter(previousScreenshotFilterData, event) : 1;
}

void replayLocalScreenshotShortcut(const SDL_KeyboardEvent* event)
{
    INPUT inputs[10] = {};
    UINT count = 0;
    auto append = [&](WORD key, bool up) {
        INPUT& input = inputs[count++];
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = key;
        input.ki.dwFlags = (up ? KEYEVENTF_KEYUP : 0) |
                ((key == VK_LWIN || key == VK_SNAPSHOT) ? KEYEVENTF_EXTENDEDKEY : 0);
        input.ki.dwExtraInfo = LocalScreenshotInputTag;
    };
    // Replay the original modifiers too: Windows keys may have been consumed
    // by SDL's system-key grab. Keep the user's configured hotkey unchanged.
    const WORD keys[] = { VK_CONTROL, VK_MENU, VK_SHIFT, VK_LWIN };
    const SDL_Keymod mods[] = { KMOD_CTRL, KMOD_ALT, KMOD_SHIFT, KMOD_GUI };
    bool injectedModifiers[4] = {};
    for (int i = 0; i < 4; ++i) {
        injectedModifiers[i] = (event->keysym.mod & mods[i]) && !(GetAsyncKeyState(keys[i]) & 0x8000);
        if (injectedModifiers[i]) append(keys[i], false);
    }
    WORD key = event->keysym.scancode == SDL_SCANCODE_PRINTSCREEN ? VK_SNAPSHOT : 'S';
    append(key, false);
    append(key, true);
    for (int i = 3; i >= 0; --i) {
        if (injectedModifiers[i]) append(keys[i], true);
    }
    if (SendInput(count, inputs, sizeof(INPUT)) != count) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION, "Unable to replay the client screenshot shortcut: %lu", GetLastError());
    }
}
}
