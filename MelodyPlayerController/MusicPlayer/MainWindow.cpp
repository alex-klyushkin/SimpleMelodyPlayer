#include "MainWindow.h"
#include <QGridLayout>
#include <QHBoxLayout>
#include <QList>
#include <QSerialPortInfo>
#include <QStatusBar>
#include <QDir>
#include <QDirIterator>
#include <QJsonObject>
#include <QTextStream>
#include <iostream>
#include "Common/Headers/Logging.h"


MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent),
      melodiesGroup(new QGroupBox(this)),
      melodiesList(new QListWidget(this)),
      playButton(new QPushButton("", this)),
      stopButton(new QPushButton("", this)),
      pauseButton(new QPushButton("", this)),
      connectionButton(new QPushButton("Connect", this)),
      comPortsComboBox(new QComboBox(this)),
      logBrowser(new QTextBrowser(this)),
      showLogCheckBox(new QCheckBox(this))
{
    SetupLogBrowser();

    DEBUG_LOG("ManWindow CTOR");
    SetupButtons();
    SetupLayouts();
    SetSerialPorts();
    StateChanged(ProtMessageType::DISCONNECTED);
    ConnectSingalsSlots();
    SetupMelodiesList();
}


void MainWindow::SetupButtons()
{
    DEBUG_LOG("ManWindow: setup buttons");
    releasedStyleSheet = playButton->styleSheet();
    stopButton->setFixedWidth(30);
    playButton->setFixedWidth(30);
    pauseButton->setFixedWidth(30);
    stopButton->setIcon(QIcon(":/icons/stop.png"));
    playButton->setIcon(QIcon(":/icons/start.png"));
    pauseButton->setIcon(QIcon(":/icons/pause.png"));
    showLogCheckBox->setText("show log");
}


void MainWindow::SetupLayouts()
{
    DEBUG_LOG("ManWindow: setup layouts");
    QHBoxLayout *boxLayout = new QHBoxLayout;
    boxLayout->addWidget(melodiesList);
    melodiesGroup->setLayout(boxLayout);
    melodiesGroup->setTitle("Melodies");

    QGridLayout *layout = new QGridLayout(this);
    layout->setSpacing(10);
    layout->addWidget(melodiesGroup, 0, 0, 4, 6);
    layout->addWidget(comPortsComboBox, 5, 0);
    layout->addWidget(connectionButton, 5, 1);
    layout->addWidget(playButton, 5, 3, Qt::AlignHCenter);
    layout->addWidget(pauseButton, 5, 4, Qt::AlignHCenter);
    layout->addWidget(stopButton, 5, 5, Qt::AlignHCenter);
    layout->addWidget(showLogCheckBox, 6, 0);
    layout->setColumnMinimumWidth(0, 120);
    layout->setColumnMinimumWidth(3, 30);
    layout->setColumnMinimumWidth(4, 30);
    layout->setColumnMinimumWidth(5, 30);

    QWidget *centralWidget = new QWidget();
    centralWidget->setLayout(layout);
    this->setCentralWidget(centralWidget);
    this->setFixedSize(400, 300);
}


void MainWindow::ConnectSingalsSlots()
{
    DEBUG_LOG("connect signals with slots");
    connect(connectionButton, SIGNAL(clicked()), this, SLOT(OnConnection()));
    connect(&melodyCtrl, SIGNAL(OnStateChange(ProtMessageType)), this, SLOT(StateChanged(ProtMessageType)));
    connect(playButton, SIGNAL(pressed()), this, SLOT(OnControlButtonPress()));
    connect(playButton, SIGNAL(released()), this, SLOT(OnControlButtonRelease()));
    connect(stopButton, SIGNAL(pressed()), this, SLOT(OnControlButtonPress()));
    connect(stopButton, SIGNAL(released()), this, SLOT(OnControlButtonRelease()));
    connect(pauseButton, SIGNAL(pressed()), this, SLOT(OnControlButtonPress()));
    connect(pauseButton, SIGNAL(released()), this, SLOT(OnControlButtonRelease()));
    connect(playButton, SIGNAL(clicked()), this, SLOT(OnPlayClick()));
    connect(stopButton, SIGNAL(clicked()), this, SLOT(OnStopClick()));
    connect(pauseButton, SIGNAL(clicked()), this, SLOT(OnPauseClick()));
    connect(showLogCheckBox, SIGNAL(stateChanged(int)), this, SLOT(OnShowLog(int)));
}


void MainWindow::SetupMelodiesList()
{
    DEBUG_LOG("setup melodies list:");
    QDir melodiesDir(QDir::currentPath() + "/melodies");
    if (melodiesDir.exists()) {
        QStringList melodies = melodiesDir.entryList(QStringList() << "*.mld", QDir::Files);
        for (auto& str : melodies) {
            str.replace('_', ' ');
            str.remove(".mld");
            DEBUG_LOG("\t" << str);
        }
        melodiesList->addItems(melodies);
    }
}


void MainWindow::SetSerialPorts()
{
    DEBUG_LOG("set serial ports");
    QList<QSerialPortInfo> portsList = QSerialPortInfo::availablePorts();
    for (auto& port: portsList) {
        comPortsComboBox->addItem(port.portName());
    }
}


void MainWindow::SetupLogBrowser()
{
    logBrowser->setFixedSize(600, this->frameGeometry().height());
    logBrowser->setWindowTitle("Log browser");
    logBrowser->setWindowFlag(Qt::SplashScreen);
    logBrowser->move(this->pos().x() + this->frameGeometry().width(), this->pos().y() + this->frameGeometry().height());
    RegisterLoggingCallback([this](const QString &log)mutable { logBrowser->append(log); });
}


void MainWindow::OnConnection()
{
    DEBUG_LOG("on connection");
    QJsonObject linkSettings = PrepareSettings();
    if (!linkSettings.isEmpty()) {
        melodyCtrl.Connect(linkSettings);
    } else {
        WARNING_LOG("Link controller settings is empty!");
    }
}


QJsonObject MainWindow::PrepareSettings()
{
    DEBUG_LOG("prepare settings");
    QJsonObject linkSettings = settings["linkController"].toObject();
    if (linkSettings["type"].isUndefined()) {
        linkSettings.insert("type", "ComPort");
    }

    if (linkSettings["type"].toString() == "ComPort") {
        if (linkSettings["settings"].isUndefined()) {
            linkSettings.insert("settings", QJsonObject());
        }
        QString comPortName = comPortsComboBox->currentText();
        QJsonObject comPortSettings = linkSettings["settings"].toObject();
        comPortSettings.insert("ComPortName", comPortName);
        linkSettings["settings"] = comPortSettings;
    }

    return linkSettings;
}


void MainWindow::StateChanged(ProtMessageType state)
{
    QString colorString("color: green");
    QString stateString(ProtMessageTypeToString(state));

    if (state == ProtMessageType::DISCONNECTED) {
        colorString = "color: red";
    } else {
        stateString = "CONNECTED: " + stateString;
    }

    statusBar()->setStyleSheet(colorString);
    statusBar()->showMessage(stateString);
    DEBUG_LOG("state changed ->" << stateString);
}


void MainWindow::OnPlayClick()
{
    DEBUG_LOG("play");
    melodyCtrl.Play(GetCurrentMelody());
}


void MainWindow::OnStopClick()
{
    DEBUG_LOG("stop");
    melodyCtrl.Stop();
}


void MainWindow::OnPauseClick()
{
    DEBUG_LOG("pause");
    melodyCtrl.Pause();
}


void MainWindow::OnControlButtonPress()
{
    QPushButton *button = static_cast<QPushButton*>(sender());
    button->setStyleSheet(pressedStyleSheet);
}


void MainWindow::OnControlButtonRelease()
{
    QPushButton *button = static_cast<QPushButton*>(sender());
    button->setStyleSheet(releasedStyleSheet);
}


void MainWindow::OnShowLog(int state)
{
    if (state == Qt::Checked) {
        logBrowser->setFixedSize(600, this->frameGeometry().height());
        logBrowser->move(this->pos().x() + this->frameGeometry().width(), this->pos().y());
        logBrowser->show();
    } else {
        logBrowser->hide();
    }
}


QVector<char> MainWindow::GetCurrentMelody()
{
    DEBUG_LOG("get current melody");
    auto item = melodiesList->currentItem();
    if (item != nullptr) {
        QString path = QDir::currentPath() + "/melodies/" + item->text().replace(" ", "_") + ".mld";
        QFile melodyFile(path);
        melodyFile.open(QFile::ReadOnly | QFile::Text);

        QStringList melodyElems = QTextStream(&melodyFile).readAll().split(" ");
        QVector<char> melody;
        melody.reserve(melodyElems.length());
        for (auto& str : melodyElems) {
            melody.push_back(static_cast<char>(str.toInt()));
        }
        DEBUG_LOG("current melody file -> " << path);
        return melody;
    }

    WARNING_LOG("current melody not selected");

    return {};
}


void MainWindow::moveEvent(QMoveEvent *event)
{
    OnShowLog(showLogCheckBox->checkState());
}


MainWindow::~MainWindow()
{
}

