// telegram interface for the main app

#pragma once

#include <QObject>
#include <qobject.h>
#include <qtmetamacros.h>

#include "telegram_worker.h"

class TelegramClient : public QObject {
  Q_OBJECT

public:
  explicit TelegramClient(QObject *parent = nullptr);
  ~TelegramClient() override;
  void start();

signals:
  void versionReceived(const QString &version);
  void errorOccured(const QString &error);

private:
  TelegramWorker m_worker;
};
