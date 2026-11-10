#include "telegram_client.h"
#include "src/telegram/telegram_worker.h"

#include <QDir>
#include <QImage>
#include <QStandardPaths>
#include <qrencode.h>

TelegramClient::TelegramClient(QObject *parent)
    : QObject(parent), m_worker(this) {
  connect(&m_worker, &TelegramWorker::versionReceived, this,
          &TelegramClient::versionReceived);
  connect(&m_worker, &TelegramWorker::authorizationStateChanged, this,
          [this](const QString &state) {
            if (state == QLatin1String("loggingOut") ||
                state == QLatin1String("closing") ||
                state == QLatin1String("closed")) {
              clearSessionData();
            }
            if (m_authorizationState != state) {
              m_authorizationState = state;
              emit authorizationStateChanged();
            }
            emit authorizationStateUpdated(state);
          });
  connect(&m_worker, &TelegramWorker::errorOccurred, this,
          &TelegramClient::errorOccurred);
  connect(&m_worker, &TelegramWorker::chatUpdated, this, [this](const QVariantMap &chat) {
    const qint64 cid = chat.value("chatId").toLongLong();
    const QString name = chat.value("name").toString();
    if (cid != 0 && !name.isEmpty()) {
      m_chatTitles[cid] = name;
    }
    emit chatUpdated(chat);
  });
  connect(&m_worker, &TelegramWorker::chatsReset, this, &TelegramClient::chatsReset);
  connect(&m_worker, &TelegramWorker::messagesLoaded, this, [this](qint64 chatId, const QVariantList &messages, bool hasMore) {
    auto updateMessagesForChat = [this, chatId, &messages, hasMore](qint64 targetChatId, QVariantList &targetMessages, MessageListModel &targetModel, auto emitChanged) {
      if (chatId != targetChatId) return;

      QMap<qint64, QVariantMap> map;
      for (const auto &v : targetMessages) {
        const auto m = v.toMap();
        map.insert(m.value("messageId").toLongLong(), m);
      }
      for (const auto &v : messages) {
        const auto m = v.toMap();
        const qint64 mid = m.value("messageId").toLongLong();
        if (map.contains(mid)) {
          auto existing = map.value(mid);
          if (m.value("filePath").toString().isEmpty() && !existing.value("filePath").toString().isEmpty()) {
            QVariantMap updated = m;
            updated["filePath"] = existing.value("filePath");
            updated["isDownloading"] = false;
            map.insert(mid, updated);
            continue;
          }
        }
        map.insert(mid, m);
      }
      QVariantList merged;
      for (auto it = map.constBegin(); it != map.constEnd(); ++it) {
        merged.append(it.value());
      }
      for (int i = 0; i < merged.size(); ++i) {
        QVariantMap m = merged[i].toMap();
        const qint64 replyId = m.value("replyToMessageId").toLongLong();
        if (replyId > 0 && (m.value("replyText").toString().isEmpty() || m.value("replySender").toString().isEmpty())) {
          if (map.contains(replyId)) {
            const QVariantMap target = map.value(replyId);
            if (m.value("replyText").toString().isEmpty()) {
              const QString targetText = target.value("caption").toString().trimmed().isEmpty()
                  ? target.value("text").toString()
                  : target.value("caption").toString();
              m["replyText"] = targetText;
            }
            if (m.value("replySender").toString().isEmpty()) {
              m["replySender"] = target.value("outgoing").toBool() ? QStringLiteral("You") : m_chatTitles.value(chatId);
            }
            merged[i] = m;
          }
        }
      }
      targetMessages = merged;
      targetModel.setMessages(merged);
      emitChanged();

      if (hasMore && targetMessages.size() < 30 && !targetMessages.isEmpty()) {
        const qint64 oldestId = targetMessages.first().toMap().value("messageId").toLongLong();
        if (oldestId > 0) {
          m_worker.loadConversation(chatId, oldestId, 50);
        }
      }
    };

    updateMessagesForChat(m_activeChatId, m_conversationMessages, m_messageModel, [this]() { emit conversationMessagesChanged(); });
    updateMessagesForChat(m_secondaryActiveChatId, m_secondaryConversationMessages, m_secondaryMessageModel, [this]() { emit secondaryConversationMessagesChanged(); });
  });

  auto resolveReplyInfo = [this](QVariantMap &msgMap, qint64 activeId, const QVariantList &targetMessages) {
    const qint64 replyId = msgMap.value("replyToMessageId").toLongLong();
    if (replyId > 0 && (msgMap.value("replyText").toString().isEmpty() || msgMap.value("replySender").toString().isEmpty())) {
      for (const auto &v : targetMessages) {
        const auto target = v.toMap();
        if (target.value("messageId").toLongLong() == replyId) {
          if (msgMap.value("replyText").toString().isEmpty()) {
            const QString targetText = target.value("caption").toString().trimmed().isEmpty()
                ? target.value("text").toString()
                : target.value("caption").toString();
            msgMap["replyText"] = targetText;
          }
          if (msgMap.value("replySender").toString().isEmpty()) {
            msgMap["replySender"] = target.value("outgoing").toBool() ? QStringLiteral("You") : m_chatTitles.value(activeId);
          }
          break;
        }
      }
    }
  };

  connect(&m_worker, &TelegramWorker::messageReceived, this, [this, resolveReplyInfo](qint64 chatId, const QVariantMap &message) {
    auto handleReceived = [this, chatId, &message, resolveReplyInfo](qint64 activeId, QVariantList &targetMessages, MessageListModel &targetModel, auto emitChanged) {
      if (chatId != activeId) return;
      const qint64 msgId = message.value("messageId").toLongLong();
      bool exists = false;
      for (const auto &m : targetMessages) {
        if (m.toMap().value("messageId").toLongLong() == msgId) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        QVariantMap msgCopy = message;
        resolveReplyInfo(msgCopy, activeId, targetMessages);
        targetMessages.append(msgCopy);
        targetModel.appendMessage(msgCopy);
        emitChanged();
      }
    };

    handleReceived(m_activeChatId, m_conversationMessages, m_messageModel, [this]() { emit conversationMessagesChanged(); });
    handleReceived(m_secondaryActiveChatId, m_secondaryConversationMessages, m_secondaryMessageModel, [this]() { emit secondaryConversationMessagesChanged(); });
  });

  connect(&m_worker, &TelegramWorker::messageSendSucceeded, this, [this, resolveReplyInfo](qint64 chatId, qint64 oldId, const QVariantMap &message) {
    auto handleSendSucceeded = [this, chatId, oldId, &message, resolveReplyInfo](qint64 activeId, QVariantList &targetMessages, MessageListModel &targetModel, auto emitChanged) {
      if (chatId != activeId) return;
      QVariantMap msgCopy = message;
      resolveReplyInfo(msgCopy, activeId, targetMessages);
      bool found = false;
      for (int i = 0; i < targetMessages.size(); ++i) {
        if (targetMessages[i].toMap().value("messageId").toLongLong() == oldId) {
          const auto oldMap = targetMessages[i].toMap();
          if (msgCopy.value("replyText").toString().isEmpty() && !oldMap.value("replyText").toString().isEmpty()) {
            msgCopy["replyText"] = oldMap.value("replyText");
          }
          if (msgCopy.value("replySender").toString().isEmpty() && !oldMap.value("replySender").toString().isEmpty()) {
            msgCopy["replySender"] = oldMap.value("replySender");
          }
          targetMessages[i] = msgCopy;
          found = true;
          break;
        }
      }
      if (!found) targetMessages.append(msgCopy);
      targetModel.replaceMessageId(oldId, msgCopy);
      emitChanged();
    };

    handleSendSucceeded(m_activeChatId, m_conversationMessages, m_messageModel, [this]() { emit conversationMessagesChanged(); });
    handleSendSucceeded(m_secondaryActiveChatId, m_secondaryConversationMessages, m_secondaryMessageModel, [this]() { emit secondaryConversationMessagesChanged(); });
  });

  connect(&m_worker, &TelegramWorker::messageSendFailed, this, [this, resolveReplyInfo](qint64 chatId, qint64 oldId, const QVariantMap &message, const QString &error) {
    const bool isRestricted = error.contains(QLatin1String("USER_RESTRICTED")) ||
                              error.contains(QLatin1String("PEER_FLOOD")) ||
                              error.contains(QLatin1String("CHAT_WRITE_FORBIDDEN")) ||
                              error.contains(QLatin1String("USER_PRIVACY_RESTRICTED"));

    if (error.contains(QLatin1String("USER_RESTRICTED")) || error.contains(QLatin1String("PEER_FLOOD"))) {
      if (!m_isAccountRestricted) {
        m_isAccountRestricted = true;
        m_accountRestrictionError = error;
        emit accountRestrictedChanged();
      }
    }

    auto handleSendFailed = [this, chatId, oldId, &message, &error, isRestricted, resolveReplyInfo](qint64 activeId, QVariantList &targetMessages, MessageListModel &targetModel, auto emitChanged) {
      if (chatId != activeId) return;
      if (isRestricted) {
        for (int i = 0; i < targetMessages.size(); ++i) {
          if (targetMessages[i].toMap().value("messageId").toLongLong() == oldId) {
            targetMessages.removeAt(i);
            break;
          }
        }
        targetModel.removeMessage(oldId);
        emitChanged();
        return;
      }
      QVariantMap msgCopy = message;
      resolveReplyInfo(msgCopy, activeId, targetMessages);
      bool found = false;
      for (int i = 0; i < targetMessages.size(); ++i) {
        if (targetMessages[i].toMap().value("messageId").toLongLong() == oldId) {
          const auto oldMap = targetMessages[i].toMap();
          if (msgCopy.value("replyText").toString().isEmpty() && !oldMap.value("replyText").toString().isEmpty()) {
            msgCopy["replyText"] = oldMap.value("replyText");
          }
          if (msgCopy.value("replySender").toString().isEmpty() && !oldMap.value("replySender").toString().isEmpty()) {
            msgCopy["replySender"] = oldMap.value("replySender");
          }
          targetMessages[i] = msgCopy;
          found = true;
          break;
        }
      }
      if (!found) targetMessages.append(msgCopy);
      targetModel.setMessageFailed(oldId, msgCopy, error);
      emitChanged();
    };

    handleSendFailed(m_activeChatId, m_conversationMessages, m_messageModel, [this]() { emit conversationMessagesChanged(); });
    handleSendFailed(m_secondaryActiveChatId, m_secondaryConversationMessages, m_secondaryMessageModel, [this]() { emit secondaryConversationMessagesChanged(); });
    emit messageSendFailed(chatId, error);
  });

  connect(&m_worker, &TelegramWorker::chatReadOutboxUpdated, this, [this](qint64 chatId, qint64 lastReadId) {
    auto handleReadOutbox = [chatId, lastReadId](qint64 activeId, QVariantList &targetMessages, MessageListModel &targetModel, auto emitChanged) {
      if (chatId != activeId) return;
      bool changed = false;
      for (QVariant &value : targetMessages) {
        QVariantMap message = value.toMap();
        if (message.value("outgoing").toBool() && message.value("messageId").toLongLong() <= lastReadId && message.value("status").toString() != QStringLiteral("✓✓")) {
          message["status"] = QStringLiteral("✓✓");
          value = message;
          changed = true;
        }
      }
      targetModel.updateReadOutbox(lastReadId);
      if (changed) emitChanged();
    };

    handleReadOutbox(m_activeChatId, m_conversationMessages, m_messageModel, [this]() { emit conversationMessagesChanged(); });
    handleReadOutbox(m_secondaryActiveChatId, m_secondaryConversationMessages, m_secondaryMessageModel, [this]() { emit secondaryConversationMessagesChanged(); });
  });

  connect(&m_worker, &TelegramWorker::chatTyping, this, [this](qint64 chatId, bool active) {
    if (chatId == m_activeChatId && m_typing != active) {
      m_typing = active;
      emit typingChanged();
    }
    if (chatId == m_secondaryActiveChatId && m_secondaryTyping != active) {
      m_secondaryTyping = active;
      emit secondaryTypingChanged();
    }
  });

  connect(&m_worker, &TelegramWorker::messageFileUpdated, this, [this](qint64 chatId, qint64 messageId, const QString &filePath) {
    auto handleFileUpdated = [chatId, messageId, &filePath](qint64 activeId, QVariantList &targetMessages, MessageListModel &targetModel, auto emitChanged) {
      if (chatId != activeId) return;
      bool changed = false;
      for (QVariant &value : targetMessages) {
        QVariantMap message = value.toMap();
        if (message.value("messageId").toLongLong() == messageId) {
          message["filePath"] = filePath;
          message["isDownloading"] = false;
          value = message;
          changed = true;
          break;
        }
      }
      if (changed) {
        targetModel.updateMessageFile(messageId, filePath);
        emitChanged();
      }
    };

    handleFileUpdated(m_activeChatId, m_conversationMessages, m_messageModel, [this]() { emit conversationMessagesChanged(); });
    handleFileUpdated(m_secondaryActiveChatId, m_secondaryConversationMessages, m_secondaryMessageModel, [this]() { emit secondaryConversationMessagesChanged(); });
  });

  connect(&m_worker, &TelegramWorker::messageReactionsUpdated, this, [this](qint64 chatId, qint64 messageId, const QVariantList &reactions) {
    auto handleReactionsUpdated = [chatId, messageId, &reactions](qint64 activeId, QVariantList &targetMessages, MessageListModel &targetModel, auto emitChanged) {
      if (chatId != activeId) return;
      bool changed = false;
      for (QVariant &value : targetMessages) {
        QVariantMap message = value.toMap();
        if (message.value("messageId").toLongLong() == messageId) {
          message["reactions"] = reactions;
          value = message;
          changed = true;
          break;
        }
      }
      targetModel.updateMessageReactions(messageId, reactions);
      if (changed) emitChanged();
    };

    handleReactionsUpdated(m_activeChatId, m_conversationMessages, m_messageModel, [this]() { emit conversationMessagesChanged(); });
    handleReactionsUpdated(m_secondaryActiveChatId, m_secondaryConversationMessages, m_secondaryMessageModel, [this]() { emit secondaryConversationMessagesChanged(); });
  });
  connect(&m_worker, &TelegramWorker::qrCodeLinkChanged, this,
          [this](const QString &link) {
            if (m_qrCodeLink != link) {
              m_qrCodeLink = link;
              emit qrCodeLinkChanged();
            }

            QRcode *code = QRcode_encodeString8bit(
                link.toUtf8().constData(), 0, QR_ECLEVEL_M);
            if (!code)
              return;

            constexpr int scale = 8;
            constexpr int quietZone = 4;
            const int side = (code->width + quietZone * 2) * scale;
            QImage image(side, side, QImage::Format_RGB32);
            image.fill(Qt::white);
            for (int y = 0; y < code->width; ++y) {
              for (int x = 0; x < code->width; ++x) {
                if (code->data[y * code->width + x] & 1) {
                  for (int dy = 0; dy < scale; ++dy) {
                    for (int dx = 0; dx < scale; ++dx) {
                      image.setPixel((quietZone + x) * scale + dx,
                                     (quietZone + y) * scale + dy,
                                     qRgb(0, 0, 0));
                    }
                  }
                }
              }
            }
            QRcode_free(code);

            const auto dir = QStandardPaths::writableLocation(
                                 QStandardPaths::CacheLocation) + "/auth";
            QDir().mkpath(dir);
            const auto path = dir + "/telegram-login-qr.png";
            if (image.save(path) && m_qrCodeImagePath != path) {
              m_qrCodeImagePath = path;
              emit qrCodeImagePathChanged();
            }
          });

  // Connect contacts signals from worker
  connect(&m_worker, &TelegramWorker::contactsReset, this, &TelegramClient::contactsReset);
  connect(&m_worker, &TelegramWorker::contactUpdated, this, &TelegramClient::contactUpdated);
  connect(&m_worker, &TelegramWorker::contactStatusUpdated, this, &TelegramClient::contactStatusUpdated);
  connect(&m_worker, &TelegramWorker::contactAvatarUpdated, this, &TelegramClient::contactAvatarUpdated);
  connect(&m_worker, &TelegramWorker::contactChatHistoryChecked, this, &TelegramClient::contactChatHistoryChecked);
  connect(&m_worker, &TelegramWorker::contactRemoved, this, &TelegramClient::contactRemoved);
  connect(&m_worker, &TelegramWorker::privateChatCreated, this, &TelegramClient::privateChatCreated);
  connect(&m_worker, &TelegramWorker::groupChatCreated, this, &TelegramClient::groupChatCreated);
  connect(&m_worker, &TelegramWorker::groupCreationFailed, this, &TelegramClient::groupCreationFailed);
  connect(&m_worker, &TelegramWorker::accountRestrictedChanged, this, [this](bool restricted, const QString &reason) {
    if (m_isAccountRestricted != restricted || m_accountRestrictionError != reason) {
      m_isAccountRestricted = restricted;
      m_accountRestrictionError = reason;
      emit accountRestrictedChanged();
    }
  });
  connect(&m_worker, &TelegramWorker::userProfileLoaded, this, &TelegramClient::userProfileLoaded);
  connect(&m_worker, &TelegramWorker::userProfilePhotosLoaded, this, &TelegramClient::userProfilePhotosLoaded);
  connect(&m_worker, &TelegramWorker::userBlockedStatusChanged, this, &TelegramClient::userBlockedStatusChanged);
  connect(&m_worker, &TelegramWorker::chatDeleted, this, &TelegramClient::chatDeleted);
  connect(&m_worker, &TelegramWorker::localSearchResults, this, &TelegramClient::localSearchResults);
  connect(&m_worker, &TelegramWorker::globalSearchResults, this, &TelegramClient::globalSearchResults);
  connect(&m_worker, &TelegramWorker::myUserUpdated, this, [this](const QVariantMap &profile) {
    // Merge or replace profile details
    for (auto it = profile.begin(); it != profile.end(); ++it) {
      m_myProfile.insert(it.key(), it.value());
    }
    emit myProfileChanged();
  });

  connect(&m_worker, &TelegramWorker::authenticationCodeLengthChanged, this,
          [this](int length) {
            if (m_authenticationCodeLength != length) {
              m_authenticationCodeLength = length;
              emit authenticationCodeLengthChanged();
            }
          });
  connect(&m_worker, &TelegramWorker::authenticationCodeTimeoutChanged, this,
          [this](int seconds) {
            if (m_authenticationCodeTimeout != seconds) {
              m_authenticationCodeTimeout = seconds;
              emit authenticationCodeTimeoutChanged();
            }
          });
}

QString TelegramClient::authorizationState() const {
  return m_authorizationState;
}
QString TelegramClient::qrCodeLink() const { return m_qrCodeLink; }
QString TelegramClient::qrCodeImagePath() const { return m_qrCodeImagePath; }
int TelegramClient::authenticationCodeLength() const { return m_authenticationCodeLength; }
int TelegramClient::authenticationCodeTimeout() const { return m_authenticationCodeTimeout; }
void TelegramClient::start() {
  if (!m_worker.isRunning())
    m_worker.start();
}

void TelegramClient::submitPhoneNumber(const QString &phoneNumber) {
  if (!phoneNumber.trimmed().isEmpty())
    m_worker.submitPhoneNumber(phoneNumber.trimmed());
}

void TelegramClient::submitCode(const QString &code) {
  if (!code.trimmed().isEmpty())
    m_worker.submitCode(code.trimmed());
}

void TelegramClient::requestQrLogin() { m_worker.submitQrLogin(); }
void TelegramClient::resendAuthenticationCode() { m_worker.resendAuthenticationCode(); }
void TelegramClient::selectPhoneLogin() { m_worker.selectPhoneLogin(); }
void TelegramClient::selectQrLogin() { m_worker.selectQrLogin(); }
void TelegramClient::loadConversation(qint64 chatId, qint64 fromMessageId) {
  m_activeChatId = chatId;
  m_typing = false;
  emit typingChanged();
  m_conversationMessages.clear();
  m_messageModel.clear();
  emit conversationMessagesChanged();
  m_worker.loadConversation(chatId, fromMessageId);
}
void TelegramClient::loadSecondaryConversation(qint64 chatId, qint64 fromMessageId) {
  m_secondaryActiveChatId = chatId;
  m_secondaryTyping = false;
  emit secondaryTypingChanged();
  m_secondaryConversationMessages.clear();
  m_secondaryMessageModel.clear();
  emit secondaryConversationMessagesChanged();
  if (chatId != 0) {
    m_worker.loadConversation(chatId, fromMessageId);
  }
}
void TelegramClient::closeSecondaryConversation() {
  m_secondaryActiveChatId = 0;
  m_secondaryTyping = false;
  emit secondaryTypingChanged();
  m_secondaryConversationMessages.clear();
  m_secondaryMessageModel.clear();
  emit secondaryConversationMessagesChanged();
}
void TelegramClient::sendMessage(qint64 chatId, const QString &text, qint64 replyToMessageId, const QString &quoteText) {
  if (chatId != 0 && !text.trimmed().isEmpty()) m_worker.sendMessage(chatId, text.trimmed(), replyToMessageId, quoteText.trimmed());
}
void TelegramClient::sendMedia(qint64 chatId, const QString &filePath, const QString &caption, qint64 replyToMessageId, const QString &quoteText) {
  if (chatId != 0 && !filePath.trimmed().isEmpty()) m_worker.sendMedia(chatId, filePath.trimmed(), caption.trimmed(), replyToMessageId, quoteText.trimmed());
}
void TelegramClient::viewMessage(qint64 chatId, qint64 messageId) {
  if (chatId != 0 && messageId != 0) m_worker.viewMessage(chatId, messageId);
}
void TelegramClient::toggleReaction(qint64 chatId, qint64 messageId, const QString &emoji, bool isChosen) {
  if (chatId != 0 && messageId != 0 && !emoji.isEmpty()) {
    // 1. Optimistically update local model immediately for instant UI feedback
    if (chatId == m_activeChatId) {
      m_messageModel.toggleReactionOptimistic(messageId, emoji);
    }
    if (chatId == m_secondaryActiveChatId) {
      m_secondaryMessageModel.toggleReactionOptimistic(messageId, emoji);
    }
    // 2. Dispatch to TDLib worker
    m_worker.toggleReaction(chatId, messageId, emoji, isChosen);
  }
}

void TelegramClient::addContact(const QString &phoneNumber, const QString &firstName, const QString &lastName) {
  m_worker.addContact(phoneNumber.trimmed(), firstName.trimmed(), lastName.trimmed());
}

void TelegramClient::createNewGroup(const QString &title, const QVariantList &userIds) {
  if (m_isAccountRestricted) {
    emit groupCreationFailed(m_accountRestrictionError.isEmpty() ? QStringLiteral("USER_RESTRICTED") : m_accountRestrictionError);
    return;
  }
  QList<qint64> uids;
  for (const auto &v : userIds) {
    qint64 id = v.toLongLong();
    if (id <= 0) {
      id = v.toString().toLongLong();
    }
    if (id > 0) {
      uids.append(id);
    }
  }
  qDebug() << "[TelegramClient] createNewGroup:" << title << "member count:" << uids.size() << "uids:" << uids;
  m_worker.createNewGroup(title.trimmed(), uids);
}

void TelegramClient::createPrivateChatForUser(qint64 userId) {
  m_worker.createPrivateChatForUser(userId);
}

void TelegramClient::deleteContact(qint64 userId) {
  m_worker.deleteContact(userId);
}

void TelegramClient::loadContacts() {
  m_worker.loadContacts();
}

void TelegramClient::loadUserProfile(qint64 userId, qint64 chatId) {
  m_worker.loadUserProfile(userId, chatId);
}

void TelegramClient::blockUser(qint64 userId, bool block) {
  m_worker.blockUser(userId, block);
}

void TelegramClient::deleteChatHistory(qint64 chatId, bool removeFromChatList, bool revoke) {
  m_worker.deleteChatHistory(chatId, removeFromChatList, revoke);
}

void TelegramClient::deleteChat(qint64 chatId) {
  m_worker.deleteChat(chatId);
}

void TelegramClient::logOut() {
  m_worker.logOut();
}

void TelegramClient::clearSessionData() {
  m_activeChatId = 0;
  m_typing = false;
  emit typingChanged();
  m_conversationMessages.clear();
  m_messageModel.clear();
  emit conversationMessagesChanged();

  m_secondaryActiveChatId = 0;
  m_secondaryTyping = false;
  emit secondaryTypingChanged();
  m_secondaryConversationMessages.clear();
  m_secondaryMessageModel.clear();
  emit secondaryConversationMessagesChanged();

  m_chatTitles.clear();

  m_isAccountRestricted = false;
  m_accountRestrictionError.clear();
  emit accountRestrictedChanged();

  m_qrCodeLink.clear();
  emit qrCodeLinkChanged();
  m_qrCodeImagePath.clear();
  emit qrCodeImagePathChanged();
}

QVariantList TelegramClient::conversationMessages() const { return m_conversationMessages; }
bool TelegramClient::typing() const { return m_typing; }

void TelegramClient::searchLocal(const QString &query) {
  m_worker.searchLocal(query);
}

void TelegramClient::searchGlobal(const QString &query) {
  m_worker.searchGlobal(query);
}

void TelegramClient::addRecentlyFoundChat(qint64 chatId) {
  m_worker.addRecentlyFoundChat(chatId);
}

void TelegramClient::joinChat(qint64 chatId) {
  m_worker.joinChat(chatId);
}

void TelegramClient::leaveChat(qint64 chatId) {
  m_worker.leaveChat(chatId);
}

void TelegramClient::toggleChatMute(qint64 chatId, bool mute) {
  m_worker.toggleChatMute(chatId, mute);
}

void TelegramClient::setProfilePhoto(const QString &filePath) {
  m_worker.setProfilePhoto(filePath);
}

void TelegramClient::setName(const QString &firstName, const QString &lastName) {
  m_worker.setName(firstName, lastName);
}

void TelegramClient::setBio(const QString &bio) {
  m_worker.setBio(bio);
}

void TelegramClient::setUsername(const QString &username) {
  m_worker.setUsername(username);
}
QVariantList TelegramClient::secondaryConversationMessages() const { return m_secondaryConversationMessages; }
bool TelegramClient::secondaryTyping() const { return m_secondaryTyping; }
