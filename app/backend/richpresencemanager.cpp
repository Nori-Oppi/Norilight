#include "richpresencemanager.h"

#include <QDebug>

#ifdef HAVE_DISCORD
#include <QCoreApplication>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QUuid>
#include <QtEndian>

// Norilight: the Discord application whose name Discord shows ("Playing Norilight"), and the
// key of the Rich Presence art asset uploaded to it (Developer Portal > Rich Presence > Art
// Assets). Asset keys can't be renamed in Discord, so this must match the uploaded key.
static const char* const DISCORD_APP_ID = "1572005705609773157";
static const char* const DISCORD_ICON_KEY = "nori-oppi-icon-512";
static const char* const DISCORD_BUTTON_LABEL = "Try Norilight!";  // at most 32 characters
static const char* const DISCORD_BUTTON_URL = "https://github.com/Nori-Oppi/Norilight";

// Discord IPC: each frame is a little-endian opcode and length, then UTF-8 JSON.
enum DiscordOpcode {
    OP_HANDSHAKE = 0,
    OP_FRAME = 1,
    OP_CLOSE = 2,
};

// How often to look for Discord again when it isn't running.
static const qint64 RECONNECT_INTERVAL_MS = 15000;
#endif

RichPresenceManager::RichPresenceManager(StreamingPreferences& prefs, QString gameName)
    : m_DiscordActive(false)
{
#ifdef HAVE_DISCORD
    if (prefs.richPresence) {
        m_DiscordActive = true;
        m_ShowButton = prefs.richPresenceButton;
        m_State = ("Streaming " + gameName).toUtf8().left(128);
        m_StartTime = QDateTime::currentSecsSinceEpoch();
        if (connectToDiscord()) {
            sendActivity(false);
        }
    }
#else
    Q_UNUSED(prefs)
    Q_UNUSED(gameName)
#endif
}

RichPresenceManager::~RichPresenceManager()
{
#ifdef HAVE_DISCORD
    if (m_Socket) {
        sendActivity(true);
    }
    if (m_Socket) {
        disconnectFromDiscord();
    }
#endif
}

void RichPresenceManager::runCallbacks()
{
#ifdef HAVE_DISCORD
    if (!m_DiscordActive) {
        return;
    }

    if (m_Socket && m_Socket->state() == QLocalSocket::ConnectedState) {
        // Discord answers every command; read the answers so they don't pile up.
        if (m_Socket->waitForReadyRead(0)) {
            m_Socket->readAll();
        }
        return;
    }

    // Not connected (Discord closed, or not started yet): try again now and then.
    if (!m_SinceAttempt.isValid() || m_SinceAttempt.elapsed() >= RECONNECT_INTERVAL_MS) {
        if (connectToDiscord()) {
            sendActivity(false);
        }
    }
#endif
}

#ifdef HAVE_DISCORD
bool RichPresenceManager::connectToDiscord()
{
    m_SinceAttempt.start();
    m_Socket.reset();

    // Discord listens on discord-ipc-0 to -9: a named pipe on Windows, a Unix socket in the
    // runtime or temporary folder elsewhere.
#ifdef Q_OS_WIN
    const QString prefix = "discord-ipc-";
#else
    QString dir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    for (const char* name : {"TMPDIR", "TMP", "TEMP"}) {
        if (dir.isEmpty()) {
            dir = qEnvironmentVariable(name);
        }
    }
    if (dir.isEmpty()) {
        dir = "/tmp";
    }
    const QString prefix = dir + "/discord-ipc-";
#endif

    for (int i = 0; i < 10; i++) {
        std::unique_ptr<QLocalSocket> socket(new QLocalSocket());
        socket->connectToServer(prefix + QString::number(i));
        if (!socket->waitForConnected(250)) {
            continue;
        }
        m_Socket = std::move(socket);

        QJsonObject handshake;
        handshake["v"] = 1;
        handshake["client_id"] = DISCORD_APP_ID;
        if (!sendFrame(OP_HANDSHAKE, handshake) || !m_Socket->waitForReadyRead(2000)) {
            qWarning() << "Discord integration: no answer to the handshake";
            m_Socket.reset();
            return false;
        }
        m_Socket->readAll();
        qInfo() << "Discord integration connected";
        return true;
    }
    return false;
}

bool RichPresenceManager::sendFrame(int opcode, const QJsonObject& payload)
{
    QByteArray json = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    QByteArray frame(8, Qt::Uninitialized);
    qToLittleEndian<quint32>(opcode, frame.data());
    qToLittleEndian<quint32>(json.size(), frame.data() + 4);
    frame += json;

    if (m_Socket->write(frame) != frame.size() || !m_Socket->waitForBytesWritten(1000)) {
        qWarning() << "Discord integration: couldn't send to Discord:" << m_Socket->errorString();
        return false;
    }
    return true;
}

void RichPresenceManager::sendActivity(bool clear)
{
    QJsonObject args;
    args["pid"] = (qint64)QCoreApplication::applicationPid();
    if (clear) {
        args["activity"] = QJsonValue::Null;
    }
    else {
        QJsonObject assets;
        assets["large_image"] = DISCORD_ICON_KEY;
        assets["large_text"] = "Norilight";

        QJsonObject button;
        button["label"] = DISCORD_BUTTON_LABEL;
        button["url"] = DISCORD_BUTTON_URL;

        QJsonObject activity;
        activity["state"] = QString::fromUtf8(m_State);
        activity["timestamps"] = QJsonObject {{"start", m_StartTime}};
        activity["assets"] = assets;
        if (m_ShowButton) {
            activity["buttons"] = QJsonArray {button};
        }
        args["activity"] = activity;
    }

    QJsonObject command;
    command["cmd"] = "SET_ACTIVITY";
    command["args"] = args;
    command["nonce"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
    if (!sendFrame(OP_FRAME, command)) {
        m_Socket.reset();
    }
}

void RichPresenceManager::disconnectFromDiscord()
{
    sendFrame(OP_CLOSE, QJsonObject());
    m_Socket->waitForReadyRead(200);
    m_Socket->disconnectFromServer();
    m_Socket.reset();
}
#endif
