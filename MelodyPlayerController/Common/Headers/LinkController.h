#ifndef LINKCONTROLLER_H
#define LINKCONTROLLER_H


#include <QObject>
#include <QTimer>
#include <QJsonObject>
#include "Common/Headers/ProtocolMessageParser.h"
#include <QMutex>


class LinkController : public QObject
{
    Q_OBJECT
public:
    LinkController(void);
    void SendMessage(ProtMessageType mesgType, const QVector<char>& data);
    bool Connect(QJsonObject settings);
    void Disconnect(void);
    bool IsChannelOpened(void) { return isChannelOpened; }

signals:
    void OnMessageReceive(ProtMessageType mesgType, const QVector<char>& data);

public slots:
    void MessageReceived(ProtMessageType mesgType, const QVector<char>& data);

protected slots:
    virtual void CheckLink(void);

protected:
    ProtocolMessageParser msgParser;
    QTimer checkLinkTimer;
    int checkLinkTimeout = 1000;
    bool isChannelOpened = false;
    QMutex lock;
    bool needCheckLink = false;

private slots:
    virtual void OnReceiveMessage(void) = 0;

private:
    virtual bool ConnectChannel(QJsonObject settings) = 0;
    virtual void DisconnectChannel(void) = 0;
    virtual int  SendBytesToChannel(const char* data, int dataLen) = 0;
};


#endif // LINKCONTROLLER_H
