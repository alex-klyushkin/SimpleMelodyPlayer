#ifndef ANSWERER_H
#define ANSWERER_H

#include <QTextBrowser>
#include <QJsonObject>
#include "Common/Headers/LinkController.h"
#include "Common/Headers/Protocol.h"

class Answerer : public QTextBrowser
{
    Q_OBJECT

public:
    Answerer(QWidget *parent = nullptr);
    ~Answerer();
    void Connect(QJsonObject);
    void Disconnect();

public slots:
    void SendNextChunkMsg(void);

private slots:
    void MessageReceived(ProtMessageType mesgType, const QVector<char>& data);

private:
    void SendMessage(ProtMessageType mesgType, const QVector<char>& data);

private:
    LinkController* linkCtrl = nullptr;
    ProtocolState* state{ProtocolStateDisconnected::Instance()};
};
#endif // ANSWERER_H
