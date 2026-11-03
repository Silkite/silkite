// telegram interface for the main app

#pragma once

#include <QObject>
#include <qobject.h>
#include <qtmetamacros.h>

#include "telegram_worker.h"

class TelergramClient : public QObject {
  Q_OBJECT

public:
  explicit TelergramClient(QObject *parent = nullptr);
  ~TelergramClient() override;
  void start();

signals:
  void versionReceived(const QString &version);
  void errorOccured(const QString &error);

private:
  TelegramWorker m_worker;
};
