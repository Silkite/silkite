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
    // A history request can finish after the user has already selected another chat.
    // Never let that stale response replace the active conversation.
    if (chatId != m_activeChatId) return;

    // Merge messages keeping them sorted by messageId ascending, avoiding duplicates
    QMap<qint64, QVariantMap> map;
    for (const auto &v : m_conversationMessages) {
      const auto m = v.toMap();
      map.insert(m.value("messageId").toLongLong(), m);
    }
    for (const auto &v : messages) {
      const auto m = v.toMap();
      const qint64 mid = m.value("messageId").toLongLong();
      if (map.contains(mid)) {
        // If we already had this message and it had a downloaded filePath, preserve it!
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
    // Populate reply metadata from cached messages if missing
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
    m_conversationMessages = merged;
    emit conversationMessagesChanged();

    // If TDLib only returned a small set (e.g. initial cache had only 1 message),
    // automatically request more history starting from the oldest message so the full conversation loads.
    if (m_conversationMessages.size() < 30 && !m_conversationMessages.isEmpty()) {
      const qint64 oldestId = m_conversationMessages.first().toMap().value("messageId").toLongLong();
      if (oldestId > 0) {
        m_worker.loadConversation(chatId, oldestId, 50);
      }
    }
  });
  auto resolveReplyInfo = [this](QVariantMap &msgMap) {
    const qint64 replyId = msgMap.value("replyToMessageId").toLongLong();
    if (replyId > 0 && (msgMap.value("replyText").toString().isEmpty() || msgMap.value("replySender").toString().isEmpty())) {
      for (const auto &v : m_conversationMessages) {
        const auto target = v.toMap();
        if (target.value("messageId").toLongLong() == replyId) {
          if (msgMap.value("replyText").toString().isEmpty()) {
            const QString targetText = target.value("caption").toString().trimmed().isEmpty()
                ? target.value("text").toString()
                : target.value("caption").toString();
            msgMap["replyText"] = targetText;
          }
          if (msgMap.value("replySender").toString().isEmpty()) {
            msgMap["replySender"] = target.value("outgoing").toBool() ? QStringLiteral("You") : m_chatTitles.value(m_activeChatId);
          }
          break;
        }
      }
    }
  };

  connect(&m_worker, &TelegramWorker::messageReceived, this, [this, resolveReplyInfo](qint64 chatId, const QVariantMap &message) {
    if (chatId != m_activeChatId) return;
    const qint64 msgId = message.value("messageId").toLongLong();
    bool exists = false;
    for (const auto &m : m_conversationMessages) {
      if (m.toMap().value("messageId").toLongLong() == msgId) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      QVariantMap msgCopy = message;
      resolveReplyInfo(msgCopy);
      m_conversationMessages.append(msgCopy);
      emit conversationMessagesChanged();
    }
  });
  connect(&m_worker, &TelegramWorker::messageSendSucceeded, this, [this, resolveReplyInfo](qint64 chatId, qint64 oldId, const QVariantMap &message) {
    if (chatId != m_activeChatId) return;
    QVariantMap msgCopy = message;
    resolveReplyInfo(msgCopy);
    bool found = false;
    for (int i = 0; i < m_conversationMessages.size(); ++i) {
      if (m_conversationMessages[i].toMap().value("messageId").toLongLong() == oldId) {
        // Also keep any replyText/replySender already in the pending message if server didn't return it
        const auto oldMap = m_conversationMessages[i].toMap();
        if (msgCopy.value("replyText").toString().isEmpty() && !oldMap.value("replyText").toString().isEmpty()) {
          msgCopy["replyText"] = oldMap.value("replyText");
        }
        if (msgCopy.value("replySender").toString().isEmpty() && !oldMap.value("replySender").toString().isEmpty()) {
          msgCopy["replySender"] = oldMap.value("replySender");
        }
        m_conversationMessages[i] = msgCopy;
        found = true;
        break;
      }
    }
    if (!found) m_conversationMessages.append(msgCopy);
    emit conversationMessagesChanged();
  });
  connect(&m_worker, &TelegramWorker::chatReadOutboxUpdated, this, [this](qint64 chatId, qint64 lastReadId) {
    if (chatId != m_activeChatId) return;
    bool changed = false;
    for (QVariant &value : m_conversationMessages) {
      QVariantMap message = value.toMap();
      if (message.value("outgoing").toBool() && message.value("messageId").toLongLong() <= lastReadId && message.value("status").toString() != QStringLiteral("✓✓")) {
        message["status"] = QStringLiteral("✓✓");
        value = message;
        changed = true;
      }
    }
    if (changed) emit conversationMessagesChanged();
  });
  connect(&m_worker, &TelegramWorker::chatTyping, this, [this](qint64 chatId, bool active) { if (chatId != m_activeChatId || m_typing == active) return; m_typing = active; emit typingChanged(); });
  connect(&m_worker, &TelegramWorker::messageFileUpdated, this, [this](qint64 chatId, qint64 messageId, const QString &filePath) {
    if (chatId != m_activeChatId) return;
    bool changed = false;
    for (QVariant &value : m_conversationMessages) {
      QVariantMap message = value.toMap();
      if (message.value("messageId").toLongLong() == messageId) {
        message["filePath"] = filePath;
        message["isDownloading"] = false;
        value = message;
        changed = true;
        break;
      }
    }
    if (changed) emit conversationMessagesChanged();
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
void TelegramClient::loadConversation(qint64 chatId, qint64 fromMessageId) { m_activeChatId = chatId; m_typing = false; emit typingChanged(); m_conversationMessages.clear(); emit conversationMessagesChanged(); m_worker.loadConversation(chatId, fromMessageId); }
void TelegramClient::sendMessage(qint64 chatId, const QString &text, qint64 replyToMessageId, const QString &quoteText) {
  if (chatId != 0 && !text.trimmed().isEmpty()) m_worker.sendMessage(chatId, text.trimmed(), replyToMessageId, quoteText.trimmed());
}
void TelegramClient::sendMedia(qint64 chatId, const QString &filePath, const QString &caption, qint64 replyToMessageId, const QString &quoteText) {
  if (chatId != 0 && !filePath.trimmed().isEmpty()) m_worker.sendMedia(chatId, filePath.trimmed(), caption.trimmed(), replyToMessageId, quoteText.trimmed());
}
void TelegramClient::viewMessage(qint64 chatId, qint64 messageId) {
  if (chatId != 0 && messageId != 0) m_worker.viewMessage(chatId, messageId);
}
QVariantList TelegramClient::conversationMessages() const { return m_conversationMessages; }
bool TelegramClient::typing() const { return m_typing; }
