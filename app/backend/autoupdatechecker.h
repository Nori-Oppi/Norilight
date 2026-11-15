#pragma once

#include <QObject>
#include <QNetworkAccessManager>

// Norilight: checks the rolling "nightly" GitHub pre-release and reports when
// it was built from a different commit than the running build.
class AutoUpdateChecker : public QObject
{
    Q_OBJECT
public:
    explicit AutoUpdateChecker(QObject *parent = nullptr);

    Q_INVOKABLE void start();

signals:
    void onUpdateAvailable(QString newVersion, QString url);

private slots:
    void handleUpdateCheckRequestFinished(QNetworkReply* reply);

private:
    QString m_BuildSha;
    QNetworkAccessManager* m_Nam;
};
