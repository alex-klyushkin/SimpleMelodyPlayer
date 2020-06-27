#ifndef COMPORTLINKCONTROLLER_H
#define COMPORTLINKCONTROLLER_H

#include <QSerialPort>
#include <QJsonObject>
#include "Common/Headers/LinkController.h"


class ComPortLinkController : public LinkController
{
private slots:
    virtual void OnReceiveMessage(void) override;

private:
    virtual bool ConnectChannel(QJsonObject settings) override;
    virtual void DisconnectChannel(void) override;
    virtual int  SendBytesToChannel(const char* data, int dataLen) override;

private:
    QSerialPort comPort;
};


struct ComPortDefaultSettings
{
    static constexpr int baudRate = 38400;
    static constexpr int stopBits = 1;
    static constexpr int dataBits = 8;
    static constexpr QSerialPort::Parity parity{QSerialPort::Parity::EvenParity};
};

#endif // COMPORTLINKCONTROLLER_H
