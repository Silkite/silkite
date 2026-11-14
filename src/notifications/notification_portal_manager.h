#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class NotificationPortalManager : public QObject {
  Q_OBJECT

public:
  explicit NotificationPortalManager(QObject *parent = nullptr);
  ~NotificationPortalManager() override;

public slots:
  /**
   * @brief Sends a notification through the shell's XDG notification portal.
   *
   * Displays the title (contact/group/channel), preview body (initial text content),
   * and avatar (if available).
   *
   * @param notificationId Unique identifier for this notification.
   * @param title Title of the contact, group, or channel.
   * @param body Initial text content of the message.
   * @param avatarPath Path or file URL to the avatar image (optional).
   */
  void sendNotification(const QString &notificationId,
                        const QString &title,
                        const QString &body,
                        const QString &avatarPath = QString());

  /**
   * @brief Withdraws/removes a previously displayed notification.
   *
   * @param notificationId Notification ID to remove.
   */
  void removeNotification(const QString &notificationId);

signals:
  /**
   * @brief Emitted when the user activates or clicks the notification.
   *
   * @param notificationId Identifier of the activated notification.
   * @param action Action name triggered by the portal.
   */
  void notificationActionInvoked(const QString &notificationId, const QString &action);

private slots:
  void onActionInvoked(const QString &id, const QString &action, const QVariantList &parameter);

private:
  void setupPortalConnection();
};
