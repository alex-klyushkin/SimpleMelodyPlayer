
#include <QVector>
#include <QMessageBox>
#include <QJsonObject>
#include <QMutexLocker>
#include <iostream>
#include "Common/Headers/LinkController.h"
#include "Common/Headers/Logging.h"


LinkController::LinkController()
{
    connect(&msgParser, SIGNAL(OnMessageReceive(ProtMessageType, const QVector<char>&)),
             this, SLOT(MessageReceived(ProtMessageType, const QVector<char>&)));
}


bool LinkController::Connect(QJsonObject settings)
{
    if (ConnectChannel(settings)) {
        isChannelOpened = true;
        SendMessage(ProtMessageType::CONNECT, {});

        if (needCheckLink) {
            connect(&checkLinkTimer, SIGNAL(timeout()), this, SLOT(CheckLink()));
            checkLinkTimer.start(checkLinkTimeout);
        }

        DEBUG_LOG("Channel opened, message \"Connect\" sent");
        return true;
    }

    WARNING_LOG("Fail to connect to channel");

    return false;
}


void LinkController::Disconnect()
{
    if (IsChannelOpened()) {
        SendMessage(ProtMessageType::DISCONNECT, {});
        DisconnectChannel();
        checkLinkTimer.stop();
        disconnect(&checkLinkTimer, SIGNAL(timeout()), this, SLOT(CheckLink()));
        isChannelOpened = false;
        DEBUG_LOG("Channel disconnected");
    }
}


void LinkController::SendMessage(ProtMessageType mesgType, const QVector<char>& data)
{
    if (IsChannelOpened()) {
        QVector<char> message;
        message.reserve(PROT_MSG_HEADER_SIZE + data.length());
        message.push_back(PROT_MAGIC1);
        message.push_back(PROT_MAGIC2);
        message.push_back(static_cast<PROT_MESSAGE_TYPE>(mesgType));
        assert(data.length() <= std::numeric_limits<unsigned char>::max());// ???
        message.push_back(static_cast<char>(data.length()));
        std::copy(data.cbegin(), data.cend(), std::back_inserter(message));

        int sended;
        {
            QMutexLocker locker(&lock);
            sended = SendBytesToChannel(message.data(), message.length());
        }
        if (sended != message.length()) {
            WARNING_LOG("send " << sended << " bytes from " << message.length() << " to channel");
        } else {
            DEBUG_LOG("Send " << data.length() + PROT_MSG_HEADER_SIZE << " bytes to channel");
        }
    } else {
        WARNING_LOG("Try send " << data.length() << " bytes to channel, but channel is closed");
    }
}


void LinkController::CheckLink()
{
    DEBUG_LOG("Send check link message");
    SendMessage(ProtMessageType::STATUS_REQ, {});
}


void LinkController::MessageReceived(ProtMessageType mesgType, const QVector<char>& data)
{
    DEBUG_LOG(ProtMessageTypeToString(mesgType) << " message received");
    emit OnMessageReceive(mesgType, data);
}
