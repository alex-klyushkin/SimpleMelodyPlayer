
#include <QVector>
#include <QJsonObject>
#include <algorithm>
#include "MelodyController.h"
#include "Common/Headers/Logging.h"
#include "Common/Headers/ComPortLinkController.h"
#include "Common/Headers/UdpPortLinkController.h"


static LinkController* linkControllerByType(QString type)
{
    if (type == "ComPort") {
        DEBUG_LOG("link controller type: com port");
        return new ComPortLinkController;
    } else if (type == "UDPPort") {
        DEBUG_LOG("link controller type: udp port");
        return new UdpPortLinkController;
    }

    WARNING_LOG("link controller type is undefined: " << type);
    return nullptr;
}


MelodyController::MelodyController()
{
}


void MelodyController::Connect(QJsonObject settings)
{
    DEBUG_LOG("connect");
    if (!linkCtrl) {
        linkCtrl = linkControllerByType(settings["type"].toString());
        if (linkCtrl) {
            connect(linkCtrl, SIGNAL(OnMessageReceive(ProtMessageType, const QVector<char>&)),
                            this, SLOT(MessageReceived(ProtMessageType, const QVector<char>&)));
            if (!linkCtrl->Connect(settings["settings"].toObject())) {
                Disconnect();
                WARNING_LOG("Fail to connect on linkCtrl");
            }
            return;
        }
        WARNING_LOG("linkCtrl is null");
    } else {
        WARNING_LOG("linkCtrl already exists");
    }
}


void MelodyController::Disconnect()
{
    DEBUG_LOG("disconnect");
    if (linkCtrl) {
        linkCtrl->Disconnect();
        disconnect(linkCtrl, SIGNAL(OnMessageReceive(ProtMessageType, const QVector<char>&)),
                        this, SLOT(MessageReceived(ProtMessageType, const QVector<char>&)));
        delete linkCtrl;
        linkCtrl = nullptr;
    } else {
        WARNING_LOG("linkCtrl doesn't exist");
    }
}


void MelodyController::Play()
{
    DEBUG_LOG("cont play");
    SendMessage(ProtMessageType::CONT_PLAY, {});
}


void MelodyController::Pause()
{
    DEBUG_LOG("pause");
    SendMessage(ProtMessageType::PAUSE, {});
}


void MelodyController::Stop()
{
    DEBUG_LOG("stop");
    SendMessage(ProtMessageType::STOP, {});
}


void MelodyController::Play(QVector<char>&& melody)
{
    if (curState == ProtMessageType::PAUSED && curMelody == melody) {
        // continue play current melody
        Play();
        return;
    }
    DEBUG_LOG("play new melody");
    if (curState != ProtMessageType::DISCONNECTED) {
        if (curState == ProtMessageType::PLAYING || curState == ProtMessageType::PAUSED) {
            Stop();
            INFO_LOG("Current melody playing stopped");
        }

        curByteNoToSend = 0;
        curMelody = std::move(melody);
        SendNextPortion(ProtMessageType::PLAY);
    } else {
        WARNING_LOG("melody controller disconected");
    }
}


void MelodyController::MessageReceived(ProtMessageType msgType, const QVector<char>& data)
{
    assert(data.length() == 0);
    DEBUG_LOG(ProtMessageTypeToString(msgType) << " message received");
    switch (msgType) {
        case ProtMessageType::DISCONNECTED:
        case ProtMessageType::PLAYING:
        case ProtMessageType::STOPPED:
        case ProtMessageType::PAUSED:
            if (curState != msgType) {
                emit OnStateChange(msgType);
                curState = msgType;
            }
        break;

        case ProtMessageType::NEXT_CHUNK:
            if (curByteNoToSend >= curMelody.length()) {
                Stop();
                INFO_LOG("Melody is over");
            } else {
                SendNextPortion(ProtMessageType::CONT_PLAY);
            }
        break;
    }
}


void MelodyController::SendMessage(ProtMessageType msgType, const QVector<char>& data)
{
    DEBUG_LOG("send message");
    if (linkCtrl) {
        linkCtrl->SendMessage(msgType, data);
    } else {
        WARNING_LOG("linkCtrl is null");
    }
}


void MelodyController::SendNextPortion(ProtMessageType msgType)
{
    DEBUG_LOG("send next portion");

    int bytesToSend = std::min(PROT_MAX_MSG_LEN, curMelody.length() - curByteNoToSend);
    auto curMelodyPos = curMelody.cbegin() + curByteNoToSend;
    curByteNoToSend += bytesToSend;
    QVector<char> msg(curMelodyPos, curMelodyPos + bytesToSend);
    SendMessage(msgType, msg);
}
