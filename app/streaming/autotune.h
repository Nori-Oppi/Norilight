#pragma once

#include <QString>

// Norilight: launch tuning. For the profile's goal (Performance, Balanced, Quality) it
// picks the codec, HDR, V-sync and frame pacing from what this PC, its display and the
// host can do, and the start bitrate from the link to the host and what earlier streams
// to that host on the same network sustained. Starting high is safe on hosts that adapt
// the bitrate during the stream (Norishine feature "adaptive"): the host lowers it when
// it must. See docs/GUIDE.md, "Tuning".
namespace AutoTune
{
    // What the profile's "Tuning" favours.
    enum class Goal {
        Performance,  // lowest latency: lighter codecs, no V-sync, no HDR, less bitrate
        Balanced,
        Quality,      // best picture: most efficient codec, HDR when possible, smooth pacing
    };

    // What both machines can do, found at launch.
    struct Capabilities {
        bool hevcHardware = false;   // this PC decodes HEVC in hardware
        bool av1Hardware = false;    // this PC decodes AV1 in hardware
        bool hdrDecode = false;      // this PC decodes and shows 10-bit HDR
        bool displayHdr = false;     // the target display shows HDR now
        bool hostHevc = false;       // the host encodes HEVC
        bool hostAv1 = false;        // the host encodes AV1
        bool hostHdr = false;        // the host encodes 10-bit
    };

    // Launch choices. Empty means: keep the profile's setting.
    struct LaunchPicks {
        enum class Codec { Keep, PreferHevc, PreferAv1 };
        Codec codec = Codec::Keep;
        int hdr = -1;          // -1 keep, 0 off, 1 on
        int vsync = -1;
        int framePacing = -1;
    };

    // Launch choices for a goal. Codec choices apply only when the profile's codec is
    // automatic; the rest replace the profile's setting for this stream only.
    LaunchPicks pickFor(Goal goal, const Capabilities& caps);

    // The goal's share of the recommended bitrate on hosts that don't adapt the bitrate.
    double bitrateFactor(Goal goal);

    const char* goalName(Goal goal);

    enum class Link {
        Unknown,  // VPN, tunnel or not found: treated like Wi-Fi
        Ethernet,
        Wifi,
        Loopback,
    };

    struct Network {
        Link link = Link::Unknown;
        QString key;  // identifies the network for learning, e.g. "ethernet 192.168.1.0/24"
    };

    // The local interface used to reach this address. Sends nothing.
    Network describeNetwork(const QString& hostAddress);

    // What earlier streams to a host on a network sustained.
    struct Learned {
        int kbps = 0;          // 0: nothing learned yet
        bool limited = false;  // the host had to lower the bitrate
        int sessions = 0;
    };

    Learned learned(const QString& hostUuid, const QString& networkKey);

    // Record a stream's outcome. limited: the host lowered the bitrate at some point;
    // sustainedKbps: the bitrate it held (the start bitrate when not limited).
    void learn(const QString& hostUuid, const QString& networkKey, int sustainedKbps, bool limited);

    // Forget everything learned (all hosts and networks).
    void forgetAll();

    struct Pick {
        int kbps = 0;
        QString reason;  // for the log
    };

    // The start bitrate. recommendedKbps is the profile's recommended bitrate for the
    // resolution and frame rate; maxKbps the highest the profile allows.
    Pick startBitrate(int recommendedKbps, bool hdr, Link link, const Learned& learned, int maxKbps,
                      Goal goal = Goal::Balanced);

    const char* linkName(Link link);
}
