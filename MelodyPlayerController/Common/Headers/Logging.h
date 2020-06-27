#ifndef LOGGING_H
#define LOGGING_H


#include <QLoggingCategory>
#include <QDebug>


Q_DECLARE_LOGGING_CATEGORY(logTest)


#define DEBUG_LOG(str) (qDebug() << __FUNCTION__ << ":" << str)
#define INFO_LOG(str) (qInfo() << __FUNCTION__ << ":" << str)
#define WARNING_LOG(str) (qWarning() << __FUNCTION__ << ":" << str)
#define CRITICAL_LOG(str) (qCritical() << __FUNCTION__ << ":" << str)
#define FATAL_LOG(str) (qFatal() << __FUNCTION__ << ":" << str)


using LogFunc = std::function<void(const QString&)>;
void RegisterLoggingCallback(LogFunc func);


void logMsgHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg);

#endif // LOGGING_H
