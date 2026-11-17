#pragma once

#include "settings/streamingpreferences.h"

#ifdef HAVE_DISCORD
#include <QByteArray>
#include <QElapsedTimer>
#include <QJsonObject>
#include <QLocalSocket>
#include <memory>
#endif

// Norilight: Discord Rich Presence while streaming ("Playing Norilight", the app being
// streamed, a timer, the icon and, if turned on in settings, a "Try Norilight!" button).
// Talks to the Discord client directly over its local IPC socket; the old discord-rpc
// library can't send buttons.
class RichPresenceManager
{
public:
    RichPresenceManager(StreamingPreferences& prefs, QString gameName);
    ~RichPresenceManager();

    // Called often from the streaming loop: reads Discord's replies, and reconnects now
    // and then if Discord wasn't running (or was restarted).
    void runCallbacks();

private:
#ifdef HAVE_DISCORD
    bool connectToDiscord();
    bool sendFrame(int opcode, const QJsonObject& payload);
    void sendActivity(bool clear);
    void disconnectFromDiscord();

    std::unique_ptr<QLocalSocket> m_Socket;
    QByteArray m_State;
    qint64 m_StartTime = 0;
    bool m_ShowButton = true;
    QElapsedTimer m_SinceAttempt;
#endif

    bool m_DiscordActive;
};
