#pragma once

#include <QMutex>
#include <QQueue>
#include <QThread>
#include <QString>

class TelegramWorker : public QThread {
  Q_OBJECT

public:
  explicit TelegramWorker(QObject *parent = nullptr);
  ~TelegramWorker() override;

  void submitPhoneNumber(const QString &phoneNumber);
  void submitCode(const QString &code);

protected:
  void run() override;

signals:
  void versionReceived(const QString &version);
  void authorizationStateChanged(const QString &state);
  void errorOccurred(const QString &error);

private:
  enum class CommandType { PhoneNumber, Code };
  struct Command { CommandType type; QString value; };
  void enqueue(Command command);
  QMutex m_mutex;
  QQueue<Command> m_commands;
};
