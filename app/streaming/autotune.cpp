#include "autotune.h"

#include <QHostAddress>
#include <QHostInfo>
#include <QNetworkInterface>
#include <QSettings>
#include <QStringList>
#include <QUdpSocket>

#include <algorithm>
#include <cmath>

namespace AutoTune
{

namespace {
    const char* k_Group = "autotune";

    // How far above the profile's recommended bitrate to start, and the most to start at,
    // for each kind of link. The host lowers the bitrate when the network can't keep up.
    struct LinkRule {
        double factor;
        int capKbps;
    };

    LinkRule ruleFor(Link link)
    {
        switch (link) {
        case Link::Ethernet:
        case Link::Loopback:
            return { 2.5, 300000 };
        case Link::Wifi:
            return { 1.5, 150000 };
        case Link::Unknown:
            break;
        }
        return { 1.5, 100000 };
    }

    // Never start below this, whatever was learned.
    const int k_FloorKbps = 2000;

    int roundKbps(double kbps)
    {
        return (int)std::lround(kbps / 500.0) * 500;
    }

    QString settingsKey(const QString& networkKey)
    {
        QString key = networkKey;
        key.replace('/', '_').replace('\\', '_').replace(' ', '_');
        return key;
    }

    QString networkPrefix(const QNetworkAddressEntry& entry)
    {
        QHostAddress ip = entry.ip();
        int prefix = entry.prefixLength();
        if (ip.protocol() == QAbstractSocket::IPv4Protocol && prefix >= 0 && prefix <= 32) {
            quint32 mask = prefix == 0 ? 0 : 0xFFFFFFFFu << (32 - prefix);
            return QHostAddress(ip.toIPv4Address() & mask).toString() + "/" + QString::number(prefix);
        }
        return QString();
    }
}

const char* goalName(Goal goal)
{
    switch (goal) {
    case Goal::Performance:
        return "performance";
    case Goal::Quality:
        return "quality";
    case Goal::Balanced:
        break;
    }
    return "balanced";
}

double bitrateFactor(Goal goal)
{
    switch (goal) {
    case Goal::Performance:
        return 0.75;
    case Goal::Quality:
        return 1.25;
    case Goal::Balanced:
        break;
    }
    return 1.0;
}

LaunchPicks pickFor(Goal goal, const Capabilities& caps)
{
    LaunchPicks picks;
    switch (goal) {
    case Goal::Performance:
        // AV1 encodes slower on most GPUs; HEVC and H.264 keep encode and decode short.
        if (caps.hevcHardware && caps.hostHevc) {
            picks.codec = LaunchPicks::Codec::PreferHevc;
        }
        picks.hdr = 0;
        picks.vsync = 0;
        picks.framePacing = 0;
        break;
    case Goal::Quality:
        // AV1 gives the best picture per bit when both sides do it in hardware.
        if (caps.av1Hardware && caps.hostAv1) {
            picks.codec = LaunchPicks::Codec::PreferAv1;
        }
        else if (caps.hevcHardware && caps.hostHevc) {
            picks.codec = LaunchPicks::Codec::PreferHevc;
        }
        if (caps.displayHdr && caps.hdrDecode && caps.hostHdr) {
            picks.hdr = 1;
        }
        picks.vsync = 1;
        picks.framePacing = 1;
        break;
    case Goal::Balanced:
        if (caps.hevcHardware && caps.hostHevc) {
            picks.codec = LaunchPicks::Codec::PreferHevc;
        }
        break;
    }
    return picks;
}

const char* linkName(Link link)
{
    switch (link) {
    case Link::Ethernet:
        return "ethernet";
    case Link::Wifi:
        return "wifi";
    case Link::Loopback:
        return "loopback";
    case Link::Unknown:
        break;
    }
    return "other";
}

Network describeNetwork(const QString& hostAddress)
{
    Network result;

    QHostAddress host(hostAddress);
    if (host.isNull()) {
        QHostInfo info = QHostInfo::fromName(hostAddress);
        if (!info.addresses().isEmpty()) {
            host = info.addresses().first();
        }
    }
    if (host.isNull()) {
        result.key = QString("other %1").arg(hostAddress);
        return result;
    }

    // Connecting a UDP socket picks the local address the system would route through,
    // without sending anything.
    QUdpSocket socket;
    socket.connectToHost(host, 9);
    socket.waitForConnected(500);
    QHostAddress local = socket.localAddress();
    socket.close();

    if (host.isLoopback() || local.isLoopback()) {
        result.link = Link::Loopback;
        result.key = "loopback";
        return result;
    }

    for (const QNetworkInterface& iface : QNetworkInterface::allInterfaces()) {
        for (const QNetworkAddressEntry& entry : iface.addressEntries()) {
            if (entry.ip().isEqual(local, QHostAddress::TolerantConversion)) {
                switch (iface.type()) {
                case QNetworkInterface::Ethernet:
                    result.link = Link::Ethernet;
                    break;
                case QNetworkInterface::Wifi:
                    result.link = Link::Wifi;
                    break;
                case QNetworkInterface::Loopback:
                    result.link = Link::Loopback;
                    break;
                default:
                    result.link = Link::Unknown;
                    break;
                }
                QString prefix = networkPrefix(entry);
                result.key = QString("%1 %2").arg(linkName(result.link),
                                                  prefix.isEmpty() ? iface.name() : prefix);
                return result;
            }
        }
    }

    result.key = QString("other %1").arg(local.isNull() ? hostAddress : local.toString());
    return result;
}

Learned learned(const QString& hostUuid, const QString& networkKey)
{
    Learned result;
    if (hostUuid.isEmpty() || networkKey.isEmpty()) {
        return result;
    }

    QSettings settings;
    settings.beginGroup(k_Group);
    settings.beginGroup(hostUuid);
    QStringList parts = settings.value(settingsKey(networkKey)).toString().split(',');
    if (parts.size() == 3) {
        result.kbps = qMax(0, parts[0].toInt());
        result.limited = parts[1] == "1";
        result.sessions = qMax(0, parts[2].toInt());
    }
    if (result.kbps == 0) {
        result = Learned();
    }
    return result;
}

void learn(const QString& hostUuid, const QString& networkKey, int sustainedKbps, bool limited)
{
    if (hostUuid.isEmpty() || networkKey.isEmpty() || sustainedKbps <= 0) {
        return;
    }

    Learned previous = learned(hostUuid, networkKey);
    Learned next;
    next.limited = limited;
    next.sessions = previous.sessions + 1;
    if (limited && previous.sessions > 0 && previous.limited) {
        // Average with the last limited stream: one bad evening shouldn't stick.
        next.kbps = (previous.kbps + sustainedKbps) / 2;
    }
    else {
        next.kbps = sustainedKbps;
    }

    QSettings settings;
    settings.beginGroup(k_Group);
    settings.beginGroup(hostUuid);
    settings.setValue(settingsKey(networkKey),
                      QString("%1,%2,%3").arg(next.kbps).arg(next.limited ? 1 : 0).arg(next.sessions));
}

void forgetAll()
{
    QSettings settings;
    settings.remove(k_Group);
}

Pick startBitrate(int recommendedKbps, bool hdr, Link link, const Learned& learned, int maxKbps, Goal goal)
{
    LinkRule rule = ruleFor(link);
    int cap = qMax(k_FloorKbps, qMin(rule.capKbps, maxKbps));
    double base = recommendedKbps * (hdr ? 1.25 : 1.0);
    // Performance asks for less (shorter frames to encode, send and decode), Quality more.
    double goalFactor = goal == Goal::Performance ? 0.6 : goal == Goal::Quality ? 1.4 : 1.0;
    double fromLink = base * rule.factor * goalFactor;

    Pick pick;
    double kbps;
    if (learned.kbps <= 0) {
        kbps = fromLink;
        pick.reason = QString("%1 link, %2, %3x the recommended bitrate").arg(linkName(link), goalName(goal)).arg(rule.factor * goalFactor);
    }
    else if (learned.limited) {
        // Start a little above what held last time; the host comes down if it must.
        kbps = learned.kbps * (goal == Goal::Performance ? 1.0 : goal == Goal::Quality ? 1.3 : 1.2);
        pick.reason = QString("held %1 kbps here before").arg(learned.kbps);
    }
    else {
        // Never limited: the network carried everything asked for, so ask for more. Not
        // for Performance, which keeps frames small whatever the network could carry.
        kbps = goal == Goal::Performance ? qMin(fromLink, learned.kbps * 1.25)
                                         : qMax(fromLink, learned.kbps * 1.25);
        pick.reason = QString("%1 kbps held without limits here before").arg(learned.kbps);
    }

    pick.kbps = qBound(k_FloorKbps, roundKbps(kbps), cap);
    return pick;
}

}
