#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QListWidget>
#include <QPushButton>
#include <QComboBox>
#include <QGroupBox>
#include <QString>
#include "MelodyController.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QTextBrowser>
#include <QCheckBox>
#include <QSerialPort>


class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow(void);
    void SetSettings(QJsonObject settings) {this->settings = settings; }

public slots:
    void StateChanged(ProtMessageType state);

private:
    void SetSerialPorts();
    void virtual moveEvent(QMoveEvent *event) override;

private:
    QGroupBox *melodiesGroup;
    QListWidget *melodiesList;
    QPushButton *playButton;
    QPushButton *stopButton;
    QPushButton *pauseButton;
    QPushButton *connectionButton;
    QComboBox *comPortsComboBox;
    QSerialPort *comPort;
    MelodyController melodyCtrl;
    QTextBrowser *logBrowser;
    QCheckBox *showLogCheckBox;

private slots:
    void OnConnection(void);
    void OnPlayClick(void);
    void OnStopClick(void);
    void OnPauseClick(void);
    void OnControlButtonPress(void);
    void OnControlButtonRelease(void);
    void OnShowLog(int state);

private:
    QVector<char> GetCurrentMelody();
    QJsonObject PrepareSettings(void);
    void SetupButtons(void);
    void SetupLayouts(void);
    void ConnectSingalsSlots(void);
    void SetupMelodiesList(void);
    void SetupLogBrowser(void);

private:
    QString pressedStyleSheet{"border:3px solid #00cc00;"};
    QString releasedStyleSheet;
    QJsonObject settings;
};
#endif // MAINWINDOW_H
