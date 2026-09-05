#pragma once

#include <QAudioDevice>
#include <QMediaDevices>
#include <QObject>
#include <QStringList>
#include <QVariantMap>

class PlaybackCapabilities final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap report READ report NOTIFY capabilitiesChanged)
    Q_PROPERTY(QAudioDevice defaultAudioOutput READ defaultAudioOutput NOTIFY capabilitiesChanged)
    Q_PROPERTY(QString outputName READ outputName NOTIFY capabilitiesChanged)
    Q_PROPERTY(QString outputConnection READ outputConnection NOTIFY capabilitiesChanged)
    Q_PROPERTY(bool hdmiConnected READ hdmiConnected NOTIFY capabilitiesChanged)

public:
    explicit PlaybackCapabilities(bool compatibilityMode, QObject *parent = nullptr);

    QVariantMap report() const;
    QAudioDevice defaultAudioOutput() const { return m_defaultAudioOutput; }
    QString outputName() const { return m_outputName; }
    QString outputConnection() const { return m_outputConnection; }
    bool hdmiConnected() const { return m_outputConnection == QStringLiteral("hdmi"); }

    Q_INVOKABLE void refresh();

signals:
    void capabilitiesChanged();

private:
    void probePulseOutput();
    void probePulseSinks(const QString &defaultSinkName, int generation);
    void applyPulseSink(const QByteArray &payload, const QString &defaultSinkName,
                        int generation);
    QString detectedConnection(const QString &id, const QString &description) const;
    static QStringList supportedContainers();
    static QStringList supportedVideoCodecs();
    static QStringList supportedAudioCodecs();

    QMediaDevices m_mediaDevices;
    QAudioDevice m_defaultAudioOutput;
    QString m_outputName;
    QString m_outputConnection = QStringLiteral("unknown");
    QStringList m_sinkPassthroughCodecs;
    bool m_compatibilityMode = false;
    int m_probeGeneration = 0;
};
