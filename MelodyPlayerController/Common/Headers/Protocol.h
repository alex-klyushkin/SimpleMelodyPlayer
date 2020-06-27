#ifndef PROTOCOL_H
#define PROTOCOL_H


#include <type_traits>
#include <QString>

//for message start
constexpr char PROT_MAGIC1 = 0xcc;
constexpr char PROT_MAGIC2 = 0xaa;
constexpr int PROT_MAGIC_LEN = 2;
constexpr int PROT_MAX_MSG_LEN = 32;

//message types
enum class ProtMessageType: char {
    //to controller
    PLAY         = 0x01,
    CONT_PLAY    = 0x02,
    STOP         = 0x03,
    PAUSE        = 0x04,
    CONNECT      = 0x05,
    DISCONNECT   = 0x06,
    STATUS_REQ   = 0x07,
    //from controller
    DISCONNECTED = 0x08,
    PLAYING      = 0x09,
    STOPPED      = 0x0a,
    PAUSED       = 0x0b,
    NEXT_CHUNK   = 0x0c
};


using PROT_MESSAGE_TYPE = std::underlying_type_t<ProtMessageType>;


struct ProtMessageHeader
{
    char magic1;
    char magic2;
    char msgType;
    char msgLen;
};


constexpr int PROT_MSG_HEADER_SIZE = sizeof(ProtMessageHeader);


QString ProtMessageTypeToString(ProtMessageType type);


class ProtocolState
{
public:
    virtual ProtocolState* ProcessMessageType(ProtMessageType msgType) = 0;
    virtual ProtMessageType GetProcessMessageType(void) = 0;
};


class ProtocolStateDisconnected: public ProtocolState
{
public:
    static ProtocolStateDisconnected* Instance() {
        static ProtocolStateDisconnected inst;
        return &inst;
    }

    virtual ProtMessageType GetProcessMessageType(void) override { return ProtMessageType::DISCONNECTED; }
    virtual ProtocolState* ProcessMessageType(ProtMessageType msgType) override;

private:
    ProtocolStateDisconnected(void) {}
};


class ProtocolStateStopped: public ProtocolState
{
public:
    static ProtocolStateStopped* Instance() {
        static ProtocolStateStopped inst;
        return &inst;
    }

    virtual ProtMessageType GetProcessMessageType(void) override { return ProtMessageType::STOPPED; };
    virtual ProtocolState* ProcessMessageType(ProtMessageType msgType) override;

private:
    ProtocolStateStopped(void) {}
};


class ProtocolStatePlaying: public ProtocolState
{
public:
    static ProtocolStatePlaying* Instance() {
        static ProtocolStatePlaying inst;
        return &inst;
    }

    virtual ProtMessageType GetProcessMessageType(void) override { return ProtMessageType::PLAYING; };
    virtual ProtocolState* ProcessMessageType(ProtMessageType msgType) override;

private:
    ProtocolStatePlaying(void) {}
};


class ProtocolStatePaused: public ProtocolState
{
public:
    static ProtocolStatePaused* Instance() {
        static ProtocolStatePaused inst;
        return &inst;
    }

    virtual ProtMessageType GetProcessMessageType(void) override { return ProtMessageType::PAUSED; };
    virtual ProtocolState* ProcessMessageType(ProtMessageType msgType) override;

private:
    ProtocolStatePaused(void) {}
};

#endif // PROTOCOL_H
