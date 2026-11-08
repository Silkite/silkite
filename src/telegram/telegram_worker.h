#pragma once

#include <QMutex>
#include <QQueue>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QThread>

class TelegramWorker : public QThread {
  Q_OBJECT

public:
  explicit TelegramWorker(QObject *parent = nullptr);
  ~TelegramWorker() override;

  void submitPhoneNumber(const QString &phoneNumber);
  void submitCode(const QString &code);
  void submitQrLogin();
  void resendAuthenticationCode();
  void selectPhoneLogin();
  void selectQrLogin();
  void loadConversation(qint64 chatId, qint64 fromMessageId = 0, int limit = 50);
  void sendMessage(qint64 chatId, const QString &text, qint64 replyToMessageId = 0, const QString &quoteText = QString());
  void sendMedia(qint64 chatId, const QString &filePath, const QString &caption = QString(), qint64 replyToMessageId = 0, const QString &quoteText = QString());
  void viewMessage(qint64 chatId, qint64 messageId);
  void toggleReaction(qint64 chatId, qint64 messageId, const QString &emoji, bool isChosen);

  void addContact(const QString &phoneNumber, const QString &firstName, const QString &lastName);
  void createNewGroup(const QString &title, const QList<qint64> &userIds);
  void createPrivateChatForUser(qint64 userId);
  void deleteContact(qint64 userId);
  void loadContacts();
  void loadUserProfile(qint64 userId, qint64 chatId = 0);
  void blockUser(qint64 userId, bool block);
  void deleteChat(qint64 chatId);
  void deleteChatHistory(qint64 chatId, bool removeFromChatList = true, bool revoke = false);
  void logOut();

  // Global search methods
  void searchLocal(const QString &query);
  void searchGlobal(const QString &query);
  void addRecentlyFoundChat(qint64 chatId);

  bool isAccountRestricted() const { return m_isAccountRestricted; }
  QString accountRestrictionError() const { return m_accountRestrictionError; }

protected:
  void run() override;

signals:
  void versionReceived(const QString &version);
  void authorizationStateChanged(const QString &state);
  void authenticationCodeLengthChanged(int length);
  void authenticationCodeTimeoutChanged(int seconds);
  void qrCodeLinkChanged(const QString &link);
  void errorOccurred(const QString &error);
  void accountRestrictedChanged(bool isRestricted, const QString &reason);
  void chatUpdated(const QVariantMap &chat);
  void chatsReset();
  void messagesLoaded(qint64 chatId, const QVariantList &messages, bool hasMore);
  void messageReceived(qint64 chatId, const QVariantMap &message);
  void messageSendSucceeded(qint64 chatId, qint64 oldMessageId, const QVariantMap &message);
  void messageSendFailed(qint64 chatId, qint64 oldMessageId, const QVariantMap &message, const QString &error);
  void chatReadOutboxUpdated(qint64 chatId, qint64 lastReadOutboxMessageId);
  void chatTyping(qint64 chatId, bool active);
  void messageFileUpdated(qint64 chatId, qint64 messageId, const QString &filePath);
  void messageReactionsUpdated(qint64 chatId, qint64 messageId, const QVariantList &reactions);

  // Contacts signals
  void contactsReset();
  void contactUpdated(const QVariantMap &contact);
  void contactStatusUpdated(qint64 userId, const QString &statusText, bool isOnline, qint64 lastSeenSecs);
  void contactAvatarUpdated(qint64 userId, const QString &avatarPath);
  void contactChatHistoryChecked(qint64 userId, qint64 chatId, bool hasHistory);
  void contactRemoved(qint64 userId);
  void privateChatCreated(qint64 userId, qint64 chatId);
  void groupChatCreated(qint64 chatId);
  void groupCreationFailed(const QString &error);
  void userProfileLoaded(qint64 userId, const QVariantMap &profile);
  void userProfilePhotosLoaded(qint64 userId, const QVariantList &photos);
  void userBlockedStatusChanged(qint64 userId, bool isBlocked);
  void chatDeleted(qint64 chatId);

  // Search signals
  void localSearchResults(const QString &query, const QVariantList &results);
  void globalSearchResults(const QString &query, const QVariantList &results);

private:
  enum class CommandType {
    PhoneNumber,
    Code,
    QrLogin,
    ResendCode,
    SelectPhone,
    SelectQr,
    History,
    SendMessage,
    SendMedia,
    ViewMessage,
    AddReaction,
    RemoveReaction,
    AddContact,
    CreateGroup,
    CreatePrivateChat,
    DeleteContact,
    LoadContacts,
    LoadUserProfile,
    BlockUser,
    DeleteChatHistory,
    DeleteChat,
    LogOut,
    SearchLocal,
    SearchGlobal,
    AddRecentlyFoundChat
  };
  struct Command {
    CommandType type;
    QString value;
    qint64 chatId = 0;
    qint64 messageId = 0;
    QString extra;
    QString quote;
    QList<qint64> userIds;
    bool flag = false;
    bool revoke = false;
  };
  void enqueue(Command command);
  QMutex m_mutex;
  QQueue<Command> m_commands;
  bool m_isAccountRestricted = false;
  QString m_accountRestrictionError;
};
