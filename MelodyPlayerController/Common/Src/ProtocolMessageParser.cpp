
#include <QVector>
#include "Common/Headers/Logging.h"
#include "Common/Headers/ProtocolMessageParser.h"


void ProtocolMessageParser::Reset()
{
    DEBUG_LOG("reset");
    needMagic = true;
    msgLen = 0;
    currentMsg.clear();
}


void ProtocolMessageParser::ParseMessage(const QByteArray& data)
{
    DEBUG_LOG("parse message");
    std::copy(data.cbegin(), data.cend(), std::back_inserter(currentMsg));
    if (needMagic && currentMsg.length() > PROT_MAGIC_LEN) {
        needMagic = !findMagic(currentMsg);
    }

    //we have magic, check header completion
    if (!needMagic && currentMsg.length() >= PROT_MSG_HEADER_SIZE) {
        DEBUG_LOG("magic complete");
        ProtMessageHeader *header = reinterpret_cast<ProtMessageHeader*>(currentMsg.data());
        int totalMsgLen = header->msgLen + PROT_MSG_HEADER_SIZE;

        //message complete, emit signal
        if (currentMsg.length() >= totalMsgLen) {
            DEBUG_LOG("message complete");
            QVector<char> message(currentMsg.begin() + PROT_MSG_HEADER_SIZE, currentMsg.begin() + totalMsgLen);
            emit OnMessageReceive(ProtMessageType(header->msgType), message);
            currentMsg.erase(currentMsg.begin(), currentMsg.begin() + totalMsgLen);
            needMagic = true;
        }
    }
}


bool ProtocolMessageParser::findMagic(QVector<char>& data)
{
    for (int i = 0; i < data.length() - 1; i++) {
        if (data[i] == PROT_MAGIC1 && data[i + 1] == PROT_MAGIC2) {
            return true;
        }
    }

    data.erase(data.begin(), data.end() - 1);
    return false;
}
