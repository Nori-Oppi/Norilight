#include "displayhdr.h"

#include <QScreen>

#import <AppKit/AppKit.h>

bool DisplayHdr::isActive(QScreen* screen)
{
    if (!screen) {
        return false;
    }
    QString name = screen->name();
    for (NSScreen* ns in [NSScreen screens]) {
        if (QString::fromNSString(ns.localizedName) == name) {
            return ns.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0;
        }
    }
    return false;
}
