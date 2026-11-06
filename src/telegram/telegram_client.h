#pragma once

#include <QObject>
#include <QString>
#include <qtmetamacros.h>
#include <QVariantList>

#include "telegram_worker.h"

class TelegramClient final : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString authorizationState READ authorizationState NOTIFY
                 authorizationStateChanged)
  Q_PROPERTY(QString qrCodeLink READ qrCodeLink NOTIFY qrCodeLinkChanged)
  Q_PROPERTY(QString qrCodeImagePath READ qrCodeImagePath NOTIFY qrCodeImagePathChanged)
  Q_PROPERTY(int authenticationCodeLength READ authenticationCodeLength NOTIFY authenticationCodeLengthChanged)
  Q_PROPERTY(int authenticationCodeTimeout READ authenticationCodeTimeout NOTIFY authenticationCodeTimeoutChanged)
  Q_PROPERTY(QVariantList conversationMessages READ conversationMessages NOTIFY conversationMessagesChanged)
  Q_PROPERTY(bool typing READ typing NOTIFY typingChanged)

public:
  explicit TelegramClient(QObject *parent = nullptr);
  ~TelegramClient() override = default;

  QString authorizationState() const;
  QString qrCodeLink() const;
  QString qrCodeImagePath() const;
  int authenticationCodeLength() const;
  int authenticationCodeTimeout() const;
  Q_INVOKABLE void start();
  Q_INVOKABLE void submitPhoneNumber(const QString &phoneNumber);
  Q_INVOKABLE void submitCode(const QString &code);
  Q_INVOKABLE void requestQrLogin();
  Q_INVOKABLE void resendAuthenticationCode();
  Q_INVOKABLE void selectPhoneLogin();
  Q_INVOKABLE void selectQrLogin();
  Q_INVOKABLE void loadConversation(qint64 chatId, qint64 fromMessageId = 0);
  Q_INVOKABLE void sendMessage(qint64 chatId, const QString &text, qint64 replyToMessageId = 0, const QString &quoteText = QString());
  Q_INVOKABLE void sendMedia(qint64 chatId, const QString &filePath, const QString &caption = QString(), qint64 replyToMessageId = 0, const QString &quoteText = QString());
  Q_INVOKABLE void viewMessage(qint64 chatId, qint64 messageId);
  QVariantList conversationMessages() const;
  bool typing() const;

signals:
  void versionReceived(const QString &version);
  void authorizationStateChanged();
  void authorizationStateUpdated(const QString &state);
  void errorOccurred(const QString &error);
  void qrCodeLinkChanged();
  void qrCodeImagePathChanged();
  void authenticationCodeLengthChanged();
  void authenticationCodeTimeoutChanged();
  void chatUpdated(const QVariantMap &chat);
  void chatsReset();
  void conversationMessagesChanged();
  void messageReceived(qint64 chatId, const QVariantMap &message);
  void chatReadOutboxUpdated(qint64 chatId, qint64 lastReadOutboxMessageId);
  void typingChanged();

private:
  TelegramWorker m_worker;
  QString m_authorizationState = QStringLiteral("starting");
  QString m_qrCodeLink;
  QString m_qrCodeImagePath;
  int m_authenticationCodeLength = 5;
  int m_authenticationCodeTimeout = 60;
  QVariantList m_conversationMessages;
  qint64 m_activeChatId = 0;
  bool m_typing = false;
  QHash<qint64, QString> m_chatTitles;
};
