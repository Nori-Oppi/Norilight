#include "autoupdatechecker.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>

// The nightly workflow passes the commit it builds through NORILIGHT_BUILD_SHA.
// Local builds don't have one and never look for updates.
#ifndef NORILIGHT_BUILD_SHA
#define NORILIGHT_BUILD_SHA ""
#endif

static const char* k_NightlyReleaseUrl =
        "https://api.github.com/repos/azijnwater/Norilight/releases/tags/nightly";

AutoUpdateChecker::AutoUpdateChecker(QObject *parent) :
    QObject(parent),
    m_BuildSha(QStringLiteral(NORILIGHT_BUILD_SHA).trimmed().toLower())
{
    m_Nam = new QNetworkAccessManager(this);

    // Never communicate over HTTP
    m_Nam->setStrictTransportSecurityEnabled(true);

    // Allow HTTP redirects
    m_Nam->setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);

    connect(m_Nam, &QNetworkAccessManager::finished,
            this, &AutoUpdateChecker::handleUpdateCheckRequestFinished);

    qDebug() << "Norilight version:" << VERSION_STR << "commit:" << (m_BuildSha.isEmpty() ? QStringLiteral("unknown") : m_BuildSha);
}

void AutoUpdateChecker::start()
{
    if (!m_Nam) {
        return;
    }

    if (m_BuildSha.isEmpty()) {
        qDebug() << "Not a nightly build; skipping the update check";
        return;
    }

#if defined(Q_OS_WIN32) || defined(Q_OS_DARWIN)
    QNetworkRequest request(QUrl(QString::fromLatin1(k_NightlyReleaseUrl)));
    // GitHub's API rejects requests without a User-Agent
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Norilight-UpdateChecker"));
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);
    m_Nam->get(request);
#endif
}

void AutoUpdateChecker::handleUpdateCheckRequestFinished(QNetworkReply* reply)
{
    Q_ASSERT(reply->isFinished());
    reply->deleteLater();

    // Only one check per launch; free the network stack afterwards
    m_Nam->deleteLater();
    m_Nam = nullptr;

    if (reply->error() != QNetworkReply::NoError) {
        // A 404 happens briefly while the workflow replaces the release
        qWarning() << "Update check failed:" << reply->error() << reply->errorString();
        return;
    }

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll(), &error);
    if (!doc.isObject()) {
        qWarning() << "Nightly release info malformed:" << error.errorString();
        return;
    }

    QJsonObject release = doc.object();
    QString targetSha = release["target_commitish"].toString().trimmed().toLower();
    if (targetSha.isEmpty()) {
        qWarning() << "Nightly release has no target commit";
        return;
    }

    // The release targets a full SHA; tolerate short SHAs on either side
    if (targetSha.startsWith(m_BuildSha) || m_BuildSha.startsWith(targetSha)) {
        qDebug() << "Running the latest nightly";
        return;
    }

    // "Nightly (nightly-20261115-abc1234)" -> "nightly-20261115-abc1234"
    QString version = release["name"].toString();
    int open = version.indexOf('(');
    int close = version.lastIndexOf(')');
    if (open >= 0 && close > open) {
        version = version.mid(open + 1, close - open - 1);
    }
    if (version.isEmpty()) {
        version = targetSha.left(7);
    }

    // Link straight to the download for this platform, so the button fetches
    // the build instead of opening a page to look for it on
#if defined(Q_OS_WIN32)
    const QString wantedSuffix = QStringLiteral("-Setup.exe");
#elif defined(Q_OS_DARWIN)
    const QString wantedSuffix = QStringLiteral(".dmg");
#else
    const QString wantedSuffix;
#endif

    QString url = release["html_url"].toString();
    if (!wantedSuffix.isEmpty()) {
        const QJsonArray assets = release["assets"].toArray();
        for (const auto& asset : assets) {
            QJsonObject assetObj = asset.toObject();
            if (assetObj["name"].toString().endsWith(wantedSuffix, Qt::CaseInsensitive)) {
                url = assetObj["browser_download_url"].toString();
                break;
            }
        }
    }

    if (url.isEmpty()) {
        url = QStringLiteral("https://github.com/azijnwater/Norilight/releases/tag/nightly");
    }

    qDebug() << "Newer nightly available:" << version << url;
    emit onUpdateAvailable(version, url);
}
