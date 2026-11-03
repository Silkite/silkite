#pragma once

#include <QObject>
#include <QString>

#include "telegram_worker.h"

class TelegramClient final : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString authorizationState READ authorizationState NOTIFY authorizationStateChanged)

public:
  explicit TelegramClient(QObject *parent = nullptr);
  ~TelegramClient() override = default;

  QString authorizationState() const;
  Q_INVOKABLE void start();
  Q_INVOKABLE void submitPhoneNumber(const QString &phoneNumber);
  Q_INVOKABLE void submitCode(const QString &code);

signals:
  void versionReceived(const QString &version);
  void authorizationStateChanged();
  void authorizationStateUpdated(const QString &state);
  void errorOccurred(const QString &error);

private:
  TelegramWorker m_worker;
  QString m_authorizationState = QStringLiteral("starting");
};
