
#include <QMessageBox>
#include <QJsonObject>
#include "Common/Headers/ComPortLinkController.h"
#include "Common/Headers/Logging.h"


static QSerialPort::Parity getParityByString(QString parity)
{
    if (parity == "none") {
        return QSerialPort::Parity::NoParity;
    } else if (parity == "even") {
        return QSerialPort::Parity::EvenParity;
    } else if (parity == "odd") {
        return QSerialPort::Parity::OddParity;
    } else if (parity == "mark") {
        return QSerialPort::Parity::MarkParity;
    } else if (parity == "space") {
        return QSerialPort::Parity::SpaceParity;
    }

    WARNING_LOG("Unknown parity");
    return QSerialPort::Parity::UnknownParity;
}


int ComPortLinkController::SendBytesToChannel(const char* data, int dataLen)
{
    DEBUG_LOG("Send " << dataLen << " bytes to com port " << comPort.portName());
    return comPort.write(data, dataLen);
}


bool ComPortLinkController::ConnectChannel(QJsonObject settings)
{
    if (comPort.isOpen()) {
        comPort.close();
    }

    QString comPortName = settings["ComPortName"].toString();
    comPort.setPortName(comPortName);
    comPort.open(QIODevice::ReadWrite);
    if (comPort.isOpen()) {
        auto baudRate = settings["baudrate"].toInt(ComPortDefaultSettings::baudRate);
        comPort.setBaudRate(baudRate);
        auto dataBits = settings["dataLen"].toInt(ComPortDefaultSettings::dataBits);
        comPort.setDataBits(QSerialPort::DataBits(dataBits));
        auto stopBits = settings["dataLen"].toInt(ComPortDefaultSettings::stopBits);
        comPort.setStopBits(QSerialPort::StopBits(stopBits));
        auto parity = settings["parity"].toString();
        comPort.setParity(getParityByString(parity));
        connect(&comPort, SIGNAL(readyRead()), this, SLOT(OnReceiveMessage()));

        DEBUG_LOG("Connect com port channel");
        return true;
    }

    QString msg = QString("COM port %1 not opened").arg(comPortName);
    QMessageBox::warning(nullptr, "Error occured", msg);
    WARNING_LOG("Fail to open com port " << comPortName);
    return false;
}


void ComPortLinkController::DisconnectChannel(void)
{
    DEBUG_LOG("Disconnect com port channel");
    disconnect(&comPort, SIGNAL(readyRead()), this, SLOT(OnReceiveMessage()));
    comPort.close();
}


void ComPortLinkController::OnReceiveMessage(void)
{
    auto data = comPort.readAll();
    msgParser.ParseMessage(data);
}
