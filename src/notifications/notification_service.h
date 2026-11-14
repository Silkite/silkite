#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class NotificationPortalManager;
class ChatListModel;
class TelegramClient;

class NotificationService : public QObject {
  Q_OBJECT

public:
  explicit NotificationService(NotificationPortalManager *portalManager,
                               ChatListModel *chatListModel,
                               TelegramClient *telegramClient,
                               QObject *parent = nullptr);
  ~NotificationService() override;

public slots:
  /**
   * @brief Handles incoming messages and dispatches notifications through the portal.
   */
  void onIncomingMessage(qint64 chatId, const QVariantMap &message);

private slots:
  void onNotificationActionInvoked(const QString &notificationId, const QString &action);

private:
  NotificationPortalManager *m_portalManager = nullptr;
  ChatListModel *m_chatListModel = nullptr;
  TelegramClient *m_telegramClient = nullptr;
};
