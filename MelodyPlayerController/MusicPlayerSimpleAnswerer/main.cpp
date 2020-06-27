
#include <QApplication>
#include <QJsonObject>
#include <QJsonDocument>
#include <QFile>
#include <QDir>
#include "answerer.h"
#include "Common/Headers/Logging.h"


static QJsonObject loadJson(QString fileName)
{
    QFile settingsFile(fileName);
    settingsFile.open(QFile::ReadOnly);
    QJsonParseError error;
    return QJsonDocument().fromJson(settingsFile.readAll(), &error).object();
}


int main(int argc, char *argv[])
{
    QApplication a(argc, argv);

    qInstallMessageHandler(logMsgHandler);

    Answerer w;
    QString fileName;
    if (argc > 1) {
        fileName = argv[1];
    } else {
        fileName = "testSettings.json";
    }
    DEBUG_LOG("file containing settings: " << fileName);

    QJsonObject testSettings = loadJson(fileName);
    QJsonObject linkSettings = testSettings["linkController"].toObject();

    w.resize(550, 250);
    w.show();
    w.Connect(linkSettings);

    int ret = a.exec();

    w.Disconnect();

    return ret;
}
