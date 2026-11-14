#include "notification_service.h"
#include "notification_portal_manager.h"
#include "../models/chat_list_model.h"
#include "../telegram/telegram_client.h"

#include <QDebug>
#include <QGuiApplication>
#include <QWindow>

NotificationService::NotificationService(NotificationPortalManager *portalManager,
                                         ChatListModel *chatListModel,
                                         TelegramClient *telegramClient,
                                         QObject *parent)
    : QObject(parent),
      m_portalManager(portalManager),
      m_chatListModel(chatListModel),
      m_telegramClient(telegramClient) {
  if (m_portalManager) {
    connect(m_portalManager, &NotificationPortalManager::notificationActionInvoked,
            this, &NotificationService::onNotificationActionInvoked);
  }
}

NotificationService::~NotificationService() = default;

void NotificationService::onIncomingMessage(qint64 chatId, const QVariantMap &message) {
  if (!m_portalManager) {
    return;
  }

  // Do not notify for outgoing messages
  if (message.value(QStringLiteral("outgoing")).toBool()) {
    return;
  }

  // If the chat is muted, skip notification
  QVariantMap chatInfo;
  if (m_chatListModel) {
    chatInfo = m_chatListModel->chatById(chatId);
    if (chatInfo.value(QStringLiteral("isMuted")).toBool()) {
      return;
    }
  }

  // Determine chat/contact/group/channel title
  QString title;
  if (chatInfo.contains(QStringLiteral("name")) && !chatInfo.value(QStringLiteral("name")).toString().isEmpty()) {
    title = chatInfo.value(QStringLiteral("name")).toString();
  }

  // Determine avatar path
  QString avatarPath;
  if (chatInfo.contains(QStringLiteral("avatarPath"))) {
    avatarPath = chatInfo.value(QStringLiteral("avatarPath")).toString();
  }

  // Initial text preview content
  QString body = message.value(QStringLiteral("text")).toString();
  if (body.isEmpty()) {
    body = message.value(QStringLiteral("caption")).toString();
  }

  const qint64 msgId = message.value(QStringLiteral("messageId")).toLongLong();
  const QString notificationId = QStringLiteral("silkite-%1-%2").arg(chatId).arg(msgId);

  m_portalManager->sendNotification(notificationId, title, body, avatarPath);
}

void NotificationService::onNotificationActionInvoked(const QString &notificationId, const QString &action) {
  Q_UNUSED(action);

  // Parse silkite-<chatId>-<msgId>
  const QStringList parts = notificationId.split(QLatin1Char('-'));
  if (parts.size() >= 3 && parts[0] == QStringLiteral("silkite")) {
    const qint64 chatId = parts[1].toLongLong();
    if (chatId != 0 && m_telegramClient) {
      m_telegramClient->loadConversation(chatId);
    }
  }

  // Bring window to focus if possible
  const auto windows = QGuiApplication::allWindows();
  for (QWindow *window : windows) {
    if (window && window->isVisible()) {
      window->requestActivate();
      window->raise();
      break;
    }
  }
}
