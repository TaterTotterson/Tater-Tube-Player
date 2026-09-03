#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QTimer>

class GamepadInput final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit GamepadInput(QObject *parent = nullptr);
    ~GamepadInput() override;

    bool connected() const { return m_connected; }

signals:
    void connectedChanged();
    void navigateLeft();
    void navigateRight();
    void navigateUp();
    void navigateDown();
    void accept();
    void back();

private:
    void poll();
    void openFirstController();
    void closeController();
    void setConnected(bool connected);
    void updateAxis(int axisIndex, int direction);
    void emitAxisDirection(int axisIndex, int direction);

    QTimer m_pollTimer;
    QElapsedTimer m_elapsed;
    void *m_controller = nullptr;
    bool m_connected = false;
    int m_axisDirections[2] = {0, 0};
    qint64 m_axisRepeatAt[2] = {0, 0};
};
