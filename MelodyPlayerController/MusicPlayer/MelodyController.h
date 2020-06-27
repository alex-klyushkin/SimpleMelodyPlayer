#ifndef MELODYCONTROLLER_H
#define MELODYCONTROLLER_H

#include <QObject>
#include "Common/Headers/Protocol.h"
#include "Common/Headers/LinkController.h"


class QString;
template <typename T> class QVector;


//class for controling melody playing on microcontroller
class MelodyController : public QObject
{
    Q_OBJECT
public:
    MelodyController();
    void Play(QVector<char>&& melody);
    void Play(void);
    void Pause(void);
    void Stop(void);
    void Connect(QJsonObject);
    void Disconnect();
    ProtMessageType GetCurrentState(void) const { return curState; }

signals:
    void OnStateChange(ProtMessageType state);

public slots:
    void MessageReceived(ProtMessageType mesgType, const QVector<char>& data);

private:
    void SendMessage(ProtMessageType mesgType, const QVector<char>& data);
    void SendNextPortion(ProtMessageType mesgType);

private:
    ProtMessageType curState{ProtMessageType::DISCONNECTED};
    QVector<char> curMelody;
    int curByteNoToSend = 0;
    LinkController *linkCtrl = nullptr;
};


#endif // MELODYCONTROLLER_H
