#include "displayhdr.h"

#include <QScreen>

#ifdef Q_OS_WIN32
#include <windows.h>
#include <dxgi1_6.h>

namespace {
    // The monitor that holds the centre of this screen.
    HMONITOR monitorFor(QScreen* screen)
    {
        // Qt's geometry is in device-independent pixels; Windows wants physical ones.
        QRect g = screen->geometry();
        qreal dpr = screen->devicePixelRatio();
        POINT centre = { (LONG)((g.x() + g.width() / 2.0) * dpr), (LONG)((g.y() + g.height() / 2.0) * dpr) };
        HMONITOR byPhysical = MonitorFromPoint(centre, MONITOR_DEFAULTTONULL);
        if (byPhysical) {
            return byPhysical;
        }
        POINT logical = { (LONG)(g.x() + g.width() / 2), (LONG)(g.y() + g.height() / 2) };
        return MonitorFromPoint(logical, MONITOR_DEFAULTTONULL);
    }
}

bool DisplayHdr::isActive(QScreen* screen)
{
    if (!screen) {
        return false;
    }
    HMONITOR monitor = monitorFor(screen);
    if (!monitor) {
        return false;
    }

    IDXGIFactory1* factory = nullptr;
    if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&factory))) {
        return false;
    }

    bool hdr = false;
    bool found = false;
    IDXGIAdapter1* adapter = nullptr;
    for (UINT a = 0; !found && factory->EnumAdapters1(a, &adapter) != DXGI_ERROR_NOT_FOUND; a++) {
        IDXGIOutput* output = nullptr;
        for (UINT o = 0; !found && adapter->EnumOutputs(o, &output) != DXGI_ERROR_NOT_FOUND; o++) {
            DXGI_OUTPUT_DESC desc;
            if (SUCCEEDED(output->GetDesc(&desc)) && desc.Monitor == monitor) {
                found = true;
                IDXGIOutput6* output6 = nullptr;
                if (SUCCEEDED(output->QueryInterface(__uuidof(IDXGIOutput6), (void**)&output6))) {
                    DXGI_OUTPUT_DESC1 desc1;
                    if (SUCCEEDED(output6->GetDesc1(&desc1))) {
                        hdr = desc1.ColorSpace == DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020;
                    }
                    output6->Release();
                }
            }
            output->Release();
        }
        adapter->Release();
    }
    factory->Release();
    return hdr;
}

#elif !defined(Q_OS_DARWIN)

bool DisplayHdr::isActive(QScreen*)
{
    return false;
}

#endif
