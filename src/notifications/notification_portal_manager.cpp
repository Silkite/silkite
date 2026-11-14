#include "notification_portal_manager.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusArgument>
#include <QDBusVariant>
#include <QFileInfo>
#include <QUrl>
#include <QDebug>

namespace {
constexpr const char *kPortalService = "org.freedesktop.portal.Desktop";
constexpr const char *kPortalPath = "/org/freedesktop/portal/desktop";
constexpr const char *kPortalInterface = "org.freedesktop.portal.Notification";
} // namespace

NotificationPortalManager::NotificationPortalManager(QObject *parent)
    : QObject(parent) {
  setupPortalConnection();
}

NotificationPortalManager::~NotificationPortalManager() = default;

void NotificationPortalManager::setupPortalConnection() {
  QDBusConnection::sessionBus().connect(
      QString::fromLatin1(kPortalService),
      QString::fromLatin1(kPortalPath),
      QString::fromLatin1(kPortalInterface),
      QStringLiteral("ActionInvoked"),
      this,
      SLOT(onActionInvoked(QString, QString, QVariantList)));
}

void NotificationPortalManager::onActionInvoked(const QString &id,
                                                const QString &action,
                                                const QVariantList &parameter) {
  Q_UNUSED(parameter);
  qInfo() << "Notification action invoked:" << id << action;
  emit notificationActionInvoked(id, action);
}

void NotificationPortalManager::sendNotification(const QString &notificationId,
                                                const QString &title,
                                                const QString &body,
                                                const QString &avatarPath) {
  if (notificationId.isEmpty()) {
    return;
  }

  QVariantMap notification;
  notification[QStringLiteral("title")] = title.isEmpty() ? QStringLiteral("New message") : title;
  notification[QStringLiteral("body")] = body;
  notification[QStringLiteral("default-action")] = QStringLiteral("app.activate");

  // Format avatar if a valid local file exists
  QString localFile = avatarPath;
  if (localFile.startsWith(QStringLiteral("file://"))) {
    localFile = QUrl(localFile).toLocalFile();
  }

  if (!localFile.isEmpty() && QFileInfo::exists(localFile)) {
    const QString fileUri = QUrl::fromLocalFile(localFile).toString();
    QDBusArgument iconArg;
    iconArg.beginStructure();
    iconArg << QStringLiteral("file-icon");
    iconArg << QDBusVariant(fileUri);
    iconArg.endStructure();
    notification[QStringLiteral("icon")] = QVariant::fromValue(iconArg);
  }

  QDBusMessage msg = QDBusMessage::createMethodCall(
      QString::fromLatin1(kPortalService),
      QString::fromLatin1(kPortalPath),
      QString::fromLatin1(kPortalInterface),
      QStringLiteral("AddNotification"));

  msg << notificationId << notification;

  // Asynchronous non-blocking D-Bus send
  if (!QDBusConnection::sessionBus().send(msg)) {
    qWarning() << "Failed to send notification message via D-Bus session bus";
  }
}

void NotificationPortalManager::removeNotification(const QString &notificationId) {
  if (notificationId.isEmpty()) {
    return;
  }

  QDBusMessage msg = QDBusMessage::createMethodCall(
      QString::fromLatin1(kPortalService),
      QString::fromLatin1(kPortalPath),
      QString::fromLatin1(kPortalInterface),
      QStringLiteral("RemoveNotification"));

  msg << notificationId;

  if (!QDBusConnection::sessionBus().send(msg)) {
    qWarning() << "Failed to send remove notification message via D-Bus session bus";
  }
}
