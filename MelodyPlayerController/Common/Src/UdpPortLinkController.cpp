
#include <QNetworkDatagram>
#include "Common/Headers/UdpPortLinkController.h"
#include "Common/Headers/Logging.h"


const QString UdpPortDefaulSettings::localAddress{"127.0.0.1"};
const QString UdpPortDefaulSettings::hostAddress{"127.0.0.1"};
const QString UdpPortDefaulSettings::defaultMode{"client"};

int UdpPortLinkController::SendBytesToChannel(const char* data, int dataLen)
{
    DEBUG_LOG("Send " << dataLen << " bytes to udp port " << udpSock.localAddress() << ":" << udpSock.localPort());
    return udpSock.write(data, dataLen);
}


void UdpPortLinkController::DisconnectChannel(void)
{
    DEBUG_LOG("Disconnect tcp port channel");
    disconnect(&udpSock, SIGNAL(readyRead()), this, SLOT(OnReceiveMessage()));
    udpSock.disconnectFromHost();
    udpSock.close();
}


bool UdpPortLinkController::ConnectChannel(QJsonObject settings)
{
    QString mode = settings["mode"].toString(UdpPortDefaulSettings::defaultMode);
    if (mode == "server") {
        needCheckLink = false;
    }

    if (!isBound) {
        quint16 localPort = static_cast<quint16>(settings["localPort"].toInt(UdpPortDefaulSettings::localPort));
        QString localAddr = settings["localAddr"].toString(UdpPortDefaulSettings::localAddress);
        if (!BindToLocal(localAddr, localPort)) {
            WARNING_LOG("Fail to bind to " << localAddr << ":" << localPort << ": " << udpSock.errorString());
            return false;
        }
        isBound = true;
    }

    hostPort = static_cast<quint16>(settings["hostPort"].toInt(UdpPortDefaulSettings::hostPort));
    hostAddr = QHostAddress(settings["hostAddr"].toString(UdpPortDefaulSettings::hostAddress));
    udpSock.connectToHost(hostAddr, hostPort);

    connect(&udpSock, SIGNAL(readyRead()), this, SLOT(OnReceiveMessage()));

    return true;
}


void UdpPortLinkController::OnReceiveMessage()
{
    while(udpSock.hasPendingDatagrams()) {
        auto datagram = udpSock.receiveDatagram();

        DEBUG_LOG("Receive datagram: size " << datagram.data().length());
        if (datagram.senderPort() != hostPort || datagram.senderAddress() != hostAddr) {
            WARNING_LOG("sender addr " << datagram.senderAddress() << ", must be " << hostAddr
                          << ", sender port " << datagram.senderPort() << ", must be " << hostPort);
        }
        if (datagram.data().length() > 0) {
            msgParser.ParseMessage(datagram.data());
        }
    }
}
