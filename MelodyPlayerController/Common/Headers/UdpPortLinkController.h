#ifndef UDPPORTLINKCONTROLLER_H
#define UDPPORTLINKCONTROLLER_H


#include "Common/Headers/LinkController.h"
#include <QUdpSocket>
#include <QString>
#include <QHostAddress>


class UdpPortLinkController : public LinkController
{
private slots:
    virtual void OnReceiveMessage(void) override;

private:
    virtual bool ConnectChannel(QJsonObject settings) override;
    virtual void DisconnectChannel(void) override;
    virtual int  SendBytesToChannel(const char* data, int dataLen) override;
    bool         BindToLocal(QString addr, quint16 port) { return udpSock.bind(QHostAddress(addr), port); }

private:
    QUdpSocket udpSock;
    QHostAddress hostAddr;
    quint16 hostPort;
    bool isBound = false;
};


struct UdpPortDefaulSettings
{
    static const QString localAddress;
    static constexpr quint16  localPort = 50000;
    static const QString hostAddress;
    static constexpr quint16 hostPort = 50001;
    static const QString defaultMode;
};


#endif // UDPPORTLINKCONTROLLER_H
