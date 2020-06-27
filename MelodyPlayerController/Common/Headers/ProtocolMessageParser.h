#ifndef PROTOCOLMESSAGEPARSER_H
#define PROTOCOLMESSAGEPARSER_H


#include <QObject>
#include "Common/Headers/Protocol.h"


template <typename T> class QVector;


class ProtocolMessageParser : public QObject
{
    Q_OBJECT
public:
    void ParseMessage(const QByteArray& data);
    void Reset();

signals:
    void OnMessageReceive(ProtMessageType mesgType, const QVector<char>& data);

private:
    bool findMagic(QVector<char>& data);

private:
    QVector<char> currentMsg;
    bool needMagic = true;
    int msgLen = 0;
};


#endif // PROTOCOLMESSAGEPARSER_H
