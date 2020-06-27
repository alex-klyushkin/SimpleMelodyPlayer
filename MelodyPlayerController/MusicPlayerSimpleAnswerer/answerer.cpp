
#include <QTimer>
#include "answerer.h"
#include "Common/Headers/Logging.h"
#include "Common/Headers/LinkController.h"
#include "Common/Headers/UdpPortLinkController.h"
#include "Common/Headers/ComPortLinkController.h"



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


Answerer::Answerer(QWidget *parent) : QTextBrowser(parent)
{
    RegisterLoggingCallback([this](const QString &log)mutable { append(log); });
}


void Answerer::Connect(QJsonObject settings)
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


void Answerer::Disconnect()
{
    DEBUG_LOG("disconnect");
    if (linkCtrl) {
        linkCtrl->Disconnect();
        disconnect(linkCtrl, SIGNAL(OnMessageReceive(ProtMessageType, const QVector<char>&)),
                        this, SLOT(MessageReceived(ProtMessageType, const QVector<char>&)));
        delete linkCtrl;
        linkCtrl = nullptr;
    } else {
        WARNING_LOG("linkCtrl isn't existing");
    }
}


void Answerer::SendMessage(ProtMessageType msgType, const QVector<char>& data)
{
    DEBUG_LOG("send message " << ProtMessageTypeToString(msgType));
    if (linkCtrl) {
        linkCtrl->SendMessage(msgType, data);
    } else {
        WARNING_LOG("linkCtrl is null");
    }
}


void Answerer::MessageReceived(ProtMessageType msgType, const QVector<char>& data)
{
    DEBUG_LOG(ProtMessageTypeToString(msgType) << " message received");
    ProtocolState* oldState = state;

    if (msgType == ProtMessageType::STATUS_REQ) {
        SendMessage(state->GetProcessMessageType(), {});
    } else {
        state = state->ProcessMessageType(msgType);
        if (state != oldState) { //yes, it is pointer comparison
            SendMessage(state->GetProcessMessageType(), {});
        }
    }

    auto curState = state->GetProcessMessageType();
    if ((msgType == ProtMessageType::PLAY || msgType == ProtMessageType::CONT_PLAY) &&
         state->GetProcessMessageType() == ProtMessageType::PLAYING) {
        QTimer::singleShot(5000, this, SLOT(SendNextChunkMsg()));
    }
}


void Answerer::SendNextChunkMsg(void)
{
    if (state->GetProcessMessageType() == ProtMessageType::PLAYING) {
        SendMessage(ProtMessageType::NEXT_CHUNK, {});
    }
}


Answerer::~Answerer()
{
}
