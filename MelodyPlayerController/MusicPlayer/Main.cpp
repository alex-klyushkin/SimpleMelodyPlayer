#include "MainWindow.h"

#include <QApplication>
#include <QSettings>
#include <QFile>
#include <QJsonDocument>
#include <QTextBrowser>
#include "Common/Headers/Logging.h"


static QJsonObject loadJson(QString fileName)
{
    QFile settingsFile(fileName);
    settingsFile.open(QFile::ReadOnly);
    return QJsonDocument().fromJson(settingsFile.readAll()).object();
}


int main(int argc, char *argv[])
{
    QApplication a(argc, argv);

    qInstallMessageHandler(logMsgHandler);

    QString fileName;
    if (argc > 1) {
        fileName = argv[1];
    } else {
        fileName = "./workSettings.json";
    }
    DEBUG_LOG("file containing settings: " << fileName);

    MainWindow w;
    w.SetSettings(loadJson(fileName));
    w.show();


    return a.exec();
}
