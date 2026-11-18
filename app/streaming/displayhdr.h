#pragma once

class QScreen;

// Norilight: whether a display shows HDR now (Windows: HDR is on for it in Windows
// settings; macOS: it can show extended dynamic range). Used by launch tuning
// (autotune.h). Returns false when unknown.
namespace DisplayHdr
{
    bool isActive(QScreen* screen);
}
