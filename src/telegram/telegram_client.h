#pragma once

#include <QObject>
#include <QString>
#include <qtmetamacros.h>

#include "telegram_worker.h"

class TelegramClient final : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString authorizationState READ authorizationState NOTIFY
                 authorizationStateChanged)
  Q_PROPERTY(QString qrCodeLink READ qrCodeLink NOTIFY qrCodeLinkChanged)
  Q_PROPERTY(QString qrCodeImagePath READ qrCodeImagePath NOTIFY qrCodeImagePathChanged)

public:
  explicit TelegramClient(QObject *parent = nullptr);
  ~TelegramClient() override = default;

  QString authorizationState() const;
  QString qrCodeLink() const;
  QString qrCodeImagePath() const;
  Q_INVOKABLE void start();
  Q_INVOKABLE void submitPhoneNumber(const QString &phoneNumber);
  Q_INVOKABLE void submitCode(const QString &code);
  Q_INVOKABLE void requestQrLogin();

signals:
  void versionReceived(const QString &version);
  void authorizationStateChanged();
  void authorizationStateUpdated(const QString &state);
  void errorOccurred(const QString &error);
  void qrCodeLinkChanged();
  void qrCodeImagePathChanged();

private:
  TelegramWorker m_worker;
  QString m_authorizationState = QStringLiteral("starting");
  QString m_qrCodeLink;
  QString m_qrCodeImagePath;
};
