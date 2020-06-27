
#include <QString>
#include "Common/Headers/Logging.h"
#include "Common/Headers/Protocol.h"


QString ProtMessageTypeToString(ProtMessageType type)
{
    switch(type) {
        case ProtMessageType::PLAY:
            return "PLAY";

        case ProtMessageType::CONT_PLAY:
            return "CONT_PLAY";

        case ProtMessageType::STOP:
            return "STOP";

        case ProtMessageType::PAUSE:
            return "PAUSE";

        case ProtMessageType::CONNECT:
            return "CONNECT";

        case ProtMessageType::DISCONNECT:
            return "DISCONNECT";

        case ProtMessageType::STATUS_REQ:
            return "STATUS_REQ";

        case ProtMessageType::DISCONNECTED:
            return "DISCONNECTED";

        case ProtMessageType::PLAYING:
            return "PLAYING";

        case ProtMessageType::STOPPED:
            return "STOPPED";

        case ProtMessageType::PAUSED:
            return "PAUSED";

        case ProtMessageType::NEXT_CHUNK:
            return "NEXT_CHUNK";
    }

    return "INCONVERTIBLE TYPE";
}


ProtocolState* ProtocolStateDisconnected::ProcessMessageType(ProtMessageType msgType)
{
    if (msgType == ProtMessageType::CONNECT) {
        return ProtocolStateStopped::Instance();
    }
    WARNING_LOG("Fail to go to " << ProtMessageTypeToString(msgType) << " state from DISCONNECTED state");
    return Instance();
}


ProtocolState* ProtocolStateStopped::ProcessMessageType(ProtMessageType msgType)
{
    if (msgType == ProtMessageType::PLAY) {
        return ProtocolStatePlaying::Instance();
    } else if (msgType == ProtMessageType::DISCONNECT) {
        return ProtocolStateDisconnected::Instance();
    }
    WARNING_LOG("Fail to go to " << ProtMessageTypeToString(msgType) << " state from STOPPED state");
    return Instance();
}


ProtocolState* ProtocolStatePlaying::ProcessMessageType(ProtMessageType msgType)
{
    if (msgType == ProtMessageType::PAUSE) {
        return ProtocolStatePaused::Instance();
    } else if (msgType == ProtMessageType::STOP) {
        return ProtocolStateStopped::Instance();
    } else if (msgType == ProtMessageType::DISCONNECT) {
        return ProtocolStateDisconnected::Instance();
    } else if (msgType == ProtMessageType::CONT_PLAY) {
        return Instance();
    }
    WARNING_LOG("Fail to go to " << ProtMessageTypeToString(msgType) << " state from PLAYING state");
    return Instance();
}


ProtocolState* ProtocolStatePaused::ProcessMessageType(ProtMessageType msgType)
{
    if (msgType == ProtMessageType::PLAY || msgType == ProtMessageType::CONT_PLAY) {
        return ProtocolStatePlaying::Instance();
    } else if (msgType == ProtMessageType::STOP) {
        return ProtocolStateStopped::Instance();
    } else if (msgType == ProtMessageType::DISCONNECT) {
        return ProtocolStateDisconnected::Instance();
    }
    WARNING_LOG("Fail to go to " << ProtMessageTypeToString(msgType) << " state from PAUSED state");
    return Instance();
}
