// this file makes tdlib run on a different thread without disrupting the main
// app

#pragma once

#include <QThread>

class TelegramWorker : public QThread {
  Q_OBJECT

public:
  explicit TelegramWorker(QObject *parent = nullptr);

protected:
  void run() override;

signals:
  void versionReceived(const QString &version);
  void errorOccurred(const QString &error);
};
