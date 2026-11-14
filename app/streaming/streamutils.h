#pragma once

#include "SDL_compat.h"

class StreamUtils
{
public:
    static
    Uint32 getPlatformWindowFlags();

    static
    SDL_Window* createTestWindow();

    static
    void scaleSourceToDestinationSurface(SDL_Rect* src, SDL_Rect* dst);

    // Norilight: how the video fills the window
    enum VideoScaleMode {
        VSM_FIT = 0,     // whole picture visible, black bars if needed
        VSM_FILL = 1,    // no black bars, edges cropped
        VSM_STRETCH = 2, // no black bars, aspect ratio ignored
    };

    static
    void setVideoScaleMode(int mode, bool alignTop);

    // Places the video according to the scale mode. In fill mode the returned
    // rectangle is larger than dst and relies on the renderer clipping it.
    static
    void scaleVideoToDestinationSurface(SDL_Rect* src, SDL_Rect* dst);

    // Same placement, but fill mode is expressed as a crop of src with dst
    // covering the window, for renderers that can't draw outside the target.
    static
    void cropVideoToDestinationSurface(SDL_Rect* src, SDL_Rect* dst);

    static
    void screenSpaceToNormalizedDeviceCoords(SDL_FRect* rect, int viewportWidth, int viewportHeight);

    static
    void screenSpaceToNormalizedDeviceCoords(SDL_Rect* src, SDL_FRect* dst, int viewportWidth, int viewportHeight);

    static
    bool getNativeDesktopMode(int displayIndex, SDL_DisplayMode* mode, SDL_Rect* safeArea);

    static
    int getDisplayRefreshRate(SDL_Window* window);

    static
    bool hasFastAes();

    static
    int getDrmFdForWindow(SDL_Window* window, bool* needsClose);

    static
    int getDrmFd(bool preferRenderNode);

    static
    void enterAsyncLoggingMode();

    static
    void exitAsyncLoggingMode();
};
