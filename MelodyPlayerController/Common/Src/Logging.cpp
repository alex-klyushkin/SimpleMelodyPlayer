#include "Common/Headers/Logging.h"
#include <QDateTime>
#include <functional>
#include <iostream>
#include <QVector>
#include <QString>


Q_LOGGING_CATEGORY(logTest, "Test")


static QVector<LogFunc> callbacks;

void RegisterLoggingCallback(LogFunc func)
{
    callbacks.push_back(std::move(func));
}


//Logging handler
void logMsgHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QString log;
    QTextStream logStream(&log);
    logStream << QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss.zzz ") << "|| ";
    switch (type)
    {
        case QtInfoMsg:     logStream << " [INFO] "; break;
        case QtDebugMsg:    logStream << " [DEBUG] "; break;
        case QtWarningMsg:  logStream << " [WARNING] "; break;
        case QtCriticalMsg: logStream << " [CRITICAL] "; break;
        case QtFatalMsg:    logStream << " [FATAL] "; break;
    }
    logStream << context.category << ": " << msg;

    for (auto& func : callbacks) {
        func(log);
    }
}

