#include "telegram_worker.h"

#include <QDir>
#include <QFileInfo>
#include <QMutexLocker>
#include <QProcess>
#include <QStandardPaths>
#include <QSysInfo>
#include <QDateTime>
#include <QHash>
#include <QImageReader>

#include <cstdlib>
#include <string>
#include <vector>

#include <td/telegram/Client.h>
#include <td/telegram/td_api.h>
#include <td/telegram/td_api.hpp>

namespace {
std::string envValue(const char *name) {
  const char *value = std::getenv(name);
  return value ? std::string(value) : std::string();
}

QString stateName(const td::td_api::AuthorizationState &state) {
  switch (state.get_id()) {
  case td::td_api::authorizationStateWaitTdlibParameters::ID: return "waitTdlibParameters";
  case td::td_api::authorizationStateWaitPhoneNumber::ID: return "waitPhoneNumber";
  case td::td_api::authorizationStateWaitCode::ID: return "waitCode";
  case td::td_api::authorizationStateWaitPassword::ID: return "waitPassword";
  case td::td_api::authorizationStateReady::ID: return "ready";
  case td::td_api::authorizationStateLoggingOut::ID: return "loggingOut";
  case td::td_api::authorizationStateClosing::ID: return "closing";
  case td::td_api::authorizationStateClosed::ID: return "closed";
  default: return "authorizing";
  }
}

QString preview(const td::td_api::message *message) {
  if (!message || !message->content_) return {};
  const auto contentId = message->content_->get_id();
  if (contentId == td::td_api::messageText::ID)
    return QString::fromStdString(static_cast<const td::td_api::messageText *>(message->content_.get())->text_->text_);
  if (contentId == td::td_api::messagePhoto::ID) {
    auto *p = static_cast<const td::td_api::messagePhoto *>(message->content_.get());
    if (p->caption_ && !p->caption_->text_.empty())
      return QString::fromStdString(p->caption_->text_);
    return QStringLiteral("Photo");
  }
  if (contentId == td::td_api::messageDocument::ID) {
    auto *d = static_cast<const td::td_api::messageDocument *>(message->content_.get());
    if (d->caption_ && !d->caption_->text_.empty())
      return QString::fromStdString(d->caption_->text_);
    if (d->document_ && !d->document_->file_name_.empty())
      return QString::fromStdString(d->document_->file_name_);
    return QStringLiteral("Document");
  }
  if (contentId == td::td_api::messageVideo::ID) {
    auto *v = static_cast<const td::td_api::messageVideo *>(message->content_.get());
    if (v->caption_ && !v->caption_->text_.empty())
      return QString::fromStdString(v->caption_->text_);
    return QStringLiteral("Video");
  }
  if (contentId == td::td_api::messageAnimation::ID) return QStringLiteral("GIF");
  if (contentId == td::td_api::messageAudio::ID) return QStringLiteral("Audio");
  if (contentId == td::td_api::messageVoiceNote::ID) return QStringLiteral("Voice Message");
  return QStringLiteral("Attachment");
}

QString replyPreview(const td::td_api::message *message) {
  if (!message || !message->reply_to_) return {};
  if (message->reply_to_->get_id() == td::td_api::messageReplyToMessage::ID) {
    auto *reply = static_cast<const td::td_api::messageReplyToMessage *>(message->reply_to_.get());
    if (reply->quote_ && reply->quote_->text_ && !reply->quote_->text_->text_.empty()) {
      return QString::fromStdString(reply->quote_->text_->text_);
    }
    if (reply->content_) {
      const auto cid = reply->content_->get_id();
      if (cid == td::td_api::messageText::ID)
        return QString::fromStdString(static_cast<const td::td_api::messageText *>(reply->content_.get())->text_->text_);
      if (cid == td::td_api::messagePhoto::ID) return QStringLiteral("Photo");
      if (cid == td::td_api::messageDocument::ID) return QStringLiteral("Document");
      if (cid == td::td_api::messageVideo::ID) return QStringLiteral("Video");
      if (cid == td::td_api::messageAnimation::ID) return QStringLiteral("GIF");
      if (cid == td::td_api::messageAudio::ID) return QStringLiteral("Audio");
      if (cid == td::td_api::messageVoiceNote::ID) return QStringLiteral("Voice Message");
      return QStringLiteral("Attachment");
    }
  }
  return {};
}

QString ensureGifConverted(const QString &sourcePath) {
  if (sourcePath.isEmpty()) return sourcePath;
  const QFileInfo fi(sourcePath);
  const QString ext = fi.suffix().toLower();
  if (ext == "gif") return sourcePath;
  if (ext != "mp4" && ext != "webm" && ext != "mov") return sourcePath;

  const QString gifDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/animations";
  QDir().mkpath(gifDir);
  const QString targetPath = gifDir + "/" + fi.completeBaseName() + ".gif";
  if (QFileInfo::exists(targetPath)) return targetPath;

  QProcess process;
  process.start("ffmpeg", QStringList() << "-y" << "-i" << sourcePath
                                        << "-vf" << "fps=18,scale='min(360,iw)':-1:flags=lanczos"
                                        << targetPath);
  if (process.waitForFinished(8000) && process.exitCode() == 0 && QFileInfo::exists(targetPath)) {
    return targetPath;
  }
  return sourcePath;
}

QVariantList parseReactions(const td::td_api::messageReactions *reactions) {
  if (!reactions) return {};
  QVariantList list;
  for (const auto &r : reactions->reactions_) {
    if (!r || !r->type_) continue;
    if (r->type_->get_id() == td::td_api::reactionTypeEmoji::ID) {
      auto *re = static_cast<const td::td_api::reactionTypeEmoji *>(r->type_.get());
      QVariantMap item;
      item["emoji"] = QString::fromStdString(re->emoji_);
      item["count"] = r->total_count_;
      item["isChosen"] = r->is_chosen_;
      list.append(item);
    }
  }
  return list;
}

QVariantMap parseMessage(const td::td_api::message *message, int &fileIdToDownload) {
  fileIdToDownload = 0;
  if (!message) return {};

  QVariantMap map;
  map["messageId"] = qint64(message->id_);
  map["chatId"] = qint64(message->chat_id_);
  map["time"] = QDateTime::fromSecsSinceEpoch(message->date_).toLocalTime().toString("HH:mm");
  map["outgoing"] = message->is_outgoing_;
  map["replyText"] = replyPreview(message);
  map["replySender"] = QString();
  map["replyToMessageId"] = qint64(0);
  if (message->interaction_info_ && message->interaction_info_->reactions_) {
    map["reactions"] = parseReactions(message->interaction_info_->reactions_.get());
  } else {
    map["reactions"] = QVariantList();
  }
  if (message->reply_to_ && message->reply_to_->get_id() == td::td_api::messageReplyToMessage::ID) {
    auto *r = static_cast<const td::td_api::messageReplyToMessage *>(message->reply_to_.get());
    map["replyToMessageId"] = qint64(r->message_id_);
    if (r->origin_) {
      const auto originId = r->origin_->get_id();
      if (originId == td::td_api::messageOriginHiddenUser::ID) {
        map["replySender"] = QString::fromStdString(static_cast<const td::td_api::messageOriginHiddenUser *>(r->origin_.get())->sender_name_);
      } else if (originId == td::td_api::messageOriginChat::ID) {
        const auto &sig = static_cast<const td::td_api::messageOriginChat *>(r->origin_.get())->author_signature_;
        if (!sig.empty()) map["replySender"] = QString::fromStdString(sig);
      } else if (originId == td::td_api::messageOriginChannel::ID) {
        const auto &sig = static_cast<const td::td_api::messageOriginChannel *>(r->origin_.get())->author_signature_;
        if (!sig.empty()) map["replySender"] = QString::fromStdString(sig);
      }
    }
  }
  map["mediaType"] = QStringLiteral("none");
  map["filePath"] = QString();
  map["fileName"] = QString();
  map["fileSize"] = 0;
  map["mediaWidth"] = 0;
  map["mediaHeight"] = 0;
  map["duration"] = 0;
  map["caption"] = QString();
  map["isDownloading"] = false;
  map["text"] = preview(message);

  if (!message->content_) return map;
  const auto contentId = message->content_->get_id();

  if (contentId == td::td_api::messageText::ID) {
    auto *t = static_cast<const td::td_api::messageText *>(message->content_.get());
    map["text"] = QString::fromStdString(t->text_->text_);
  } else if (contentId == td::td_api::messagePhoto::ID) {
    auto *p = static_cast<const td::td_api::messagePhoto *>(message->content_.get());
    map["mediaType"] = QStringLiteral("photo");
    if (p->caption_) map["caption"] = QString::fromStdString(p->caption_->text_);
    if (p->photo_ && !p->photo_->sizes_.empty()) {
      const auto &size = p->photo_->sizes_.back();
      if (size) {
        map["mediaWidth"] = size->width_;
        map["mediaHeight"] = size->height_;
        if (size->photo_) {
          const int fid = size->photo_->id_;
          map["fileId"] = fid;
          map["fileSize"] = qint64(size->photo_->size_);
          const QString localPath = size->photo_->local_ ? QString::fromStdString(size->photo_->local_->path_) : QString();
          if (!localPath.isEmpty() && (size->photo_->local_->is_downloading_completed_ || QFile::exists(localPath))) {
            map["filePath"] = localPath;
            if (map["mediaWidth"].toInt() == 0 || map["mediaHeight"].toInt() == 0) {
              const QSize actualSize = QImageReader(localPath).size();
              if (actualSize.isValid() && actualSize.width() > 0 && actualSize.height() > 0) {
                map["mediaWidth"] = actualSize.width();
                map["mediaHeight"] = actualSize.height();
              }
            }
          } else {
            fileIdToDownload = fid;
            map["isDownloading"] = true;
          }
        }
      }
    }
  } else if (contentId == td::td_api::messageDocument::ID) {
    auto *d = static_cast<const td::td_api::messageDocument *>(message->content_.get());
    map["mediaType"] = QStringLiteral("document");
    if (d->caption_) map["caption"] = QString::fromStdString(d->caption_->text_);
    if (d->document_) {
      map["fileName"] = QString::fromStdString(d->document_->file_name_);
      if (d->document_->thumbnail_) {
        map["mediaWidth"] = d->document_->thumbnail_->width_;
        map["mediaHeight"] = d->document_->thumbnail_->height_;
      }
      if (d->document_->document_) {
        const int fid = d->document_->document_->id_;
        map["fileId"] = fid;
        map["fileSize"] = qint64(d->document_->document_->size_);
        const QString localPath = d->document_->document_->local_ ? QString::fromStdString(d->document_->document_->local_->path_) : QString();
        if (!localPath.isEmpty() && (d->document_->document_->local_->is_downloading_completed_ || QFile::exists(localPath))) {
          map["filePath"] = localPath;
        } else {
          fileIdToDownload = fid;
          map["isDownloading"] = true;
        }
      }
    }
  } else if (contentId == td::td_api::messageVideo::ID) {
    auto *v = static_cast<const td::td_api::messageVideo *>(message->content_.get());
    map["mediaType"] = QStringLiteral("video");
    if (v->caption_) map["caption"] = QString::fromStdString(v->caption_->text_);
    if (v->video_) {
      map["fileName"] = QString::fromStdString(v->video_->file_name_);
      map["mediaWidth"] = v->video_->width_;
      map["mediaHeight"] = v->video_->height_;
      map["duration"] = v->video_->duration_;
      if (v->video_->video_) {
        const int fid = v->video_->video_->id_;
        map["fileId"] = fid;
        map["fileSize"] = qint64(v->video_->video_->size_);
        const QString localPath = v->video_->video_->local_ ? QString::fromStdString(v->video_->video_->local_->path_) : QString();
        if (!localPath.isEmpty() && (v->video_->video_->local_->is_downloading_completed_ || QFile::exists(localPath))) {
          map["filePath"] = localPath;
        } else {
          fileIdToDownload = fid;
          map["isDownloading"] = true;
        }
      }
    }
  } else if (contentId == td::td_api::messageAnimation::ID) {
    auto *a = static_cast<const td::td_api::messageAnimation *>(message->content_.get());
    map["mediaType"] = QStringLiteral("animation");
    if (a->caption_) map["caption"] = QString::fromStdString(a->caption_->text_);
    if (a->animation_) {
      map["fileName"] = QString::fromStdString(a->animation_->file_name_);
      map["mediaWidth"] = a->animation_->width_;
      map["mediaHeight"] = a->animation_->height_;
      map["duration"] = a->animation_->duration_;
      if (a->animation_->animation_) {
        const int fid = a->animation_->animation_->id_;
        map["fileId"] = fid;
        map["fileSize"] = qint64(a->animation_->animation_->size_);
        const QString localPath = a->animation_->animation_->local_ ? QString::fromStdString(a->animation_->animation_->local_->path_) : QString();
        if (!localPath.isEmpty() && (a->animation_->animation_->local_->is_downloading_completed_ || QFile::exists(localPath))) {
          map["filePath"] = ensureGifConverted(localPath);
        } else {
          fileIdToDownload = fid;
          map["isDownloading"] = true;
        }
      }
    }
  } else if (contentId == td::td_api::messageAudio::ID) {
    auto *au = static_cast<const td::td_api::messageAudio *>(message->content_.get());
    map["mediaType"] = QStringLiteral("audio");
    if (au->caption_) map["caption"] = QString::fromStdString(au->caption_->text_);
    if (au->audio_) {
      map["fileName"] = QString::fromStdString(au->audio_->file_name_);
      map["duration"] = au->audio_->duration_;
      if (au->audio_->audio_) {
        const int fid = au->audio_->audio_->id_;
        map["fileId"] = fid;
        map["fileSize"] = qint64(au->audio_->audio_->size_);
        const QString localPath = au->audio_->audio_->local_ ? QString::fromStdString(au->audio_->audio_->local_->path_) : QString();
        if (!localPath.isEmpty() && (au->audio_->audio_->local_->is_downloading_completed_ || QFile::exists(localPath))) {
          map["filePath"] = localPath;
        } else {
          fileIdToDownload = fid;
          map["isDownloading"] = true;
        }
      }
    }
  }

  return map;
}

QString formatUserStatus(const td::td_api::UserStatus *status, bool isBot, bool *outIsOnline = nullptr) {
  if (outIsOnline) *outIsOnline = false;
  if (!status) return {};
  if (isBot) return QStringLiteral("bot");

  switch (status->get_id()) {
  case td::td_api::userStatusOnline::ID: {
    if (outIsOnline) *outIsOnline = true;
    return QStringLiteral("online");
  }
  case td::td_api::userStatusOffline::ID: {
    auto *offline = static_cast<const td::td_api::userStatusOffline *>(status);
    const qint64 wasOnlineSecs = offline->was_online_;
    if (wasOnlineSecs <= 0) return QStringLiteral("offline");
    const QDateTime wasOnline = QDateTime::fromSecsSinceEpoch(wasOnlineSecs).toLocalTime();
    const QDateTime now = QDateTime::currentDateTime();
    const qint64 diffSecs = wasOnline.secsTo(now);

    if (diffSecs < 60) {
      return QStringLiteral("last seen just now");
    }
    if (diffSecs < 3600) {
      const int mins = int(diffSecs / 60);
      return QStringLiteral("last seen %1 minute%2 ago").arg(mins).arg(mins > 1 ? QStringLiteral("s") : QString());
    }

    const QDate wasDate = wasOnline.date();
    const QDate nowDate = now.date();
    const QString timeStr = wasOnline.toString(QStringLiteral("HH:mm"));

    if (wasDate == nowDate) {
      return QStringLiteral("last seen today at %1").arg(timeStr);
    }
    if (wasDate == nowDate.addDays(-1)) {
      return QStringLiteral("last seen yesterday at %1").arg(timeStr);
    }
    if (wasDate.year() == nowDate.year()) {
      return QStringLiteral("last seen %1 at %2").arg(wasOnline.toString(QStringLiteral("MMM d"))).arg(timeStr);
    }
    return QStringLiteral("last seen %1 at %2").arg(wasOnline.toString(QStringLiteral("dd.MM.yyyy"))).arg(timeStr);
  }
  case td::td_api::userStatusRecently::ID:
    return QStringLiteral("last seen recently");
  case td::td_api::userStatusLastWeek::ID:
    return QStringLiteral("last seen within a week");
  case td::td_api::userStatusLastMonth::ID:
    return QStringLiteral("last seen within a month");
  case td::td_api::userStatusEmpty::ID:
  default:
    return QStringLiteral("offline");
  }
}

QVariantMap toChatMap(const td::td_api::chat *chat) {
  if (!chat) return {};
  const QString name = QString::fromStdString(chat->title_);
  QString avatarPath;
  if (chat->photo_ && chat->photo_->small_ && chat->photo_->small_->local_ && chat->photo_->small_->local_->is_downloading_completed_)
    avatarPath = QString::fromStdString(chat->photo_->small_->local_->path_);
  qint64 order = 0;
  for (const auto &position : chat->positions_)
    if (position && position->list_ && position->list_->get_id() == td::td_api::chatListMain::ID)
      order = position->order_;
  return {{"chatId", qint64(chat->id_)}, {"name", name}, {"lastMessage", preview(chat->last_message_.get())},
          {"time", chat->last_message_ ? QDateTime::fromSecsSinceEpoch(chat->last_message_->date_).toLocalTime().toString("HH:mm") : QString()},
          {"initials", name.trimmed().isEmpty() ? QStringLiteral("?") : name.trimmed().left(2).toUpper()},
          {"avatarColor", QStringLiteral("#526C8A")}, {"avatarPath", avatarPath},
          {"unreadCount", chat->unread_count_}, {"order", order}};
}

qint64 mainChatOrder(const td::td_api::array<td::td_api::object_ptr<td::td_api::chatPosition>> &positions) {
  for (const auto &position : positions)
    if (position && position->list_ && position->list_->get_id() == td::td_api::chatListMain::ID)
      return position->order_;
  return 0;
}
}

TelegramWorker::TelegramWorker(QObject *parent) : QThread(parent) {}

TelegramWorker::~TelegramWorker() {
  requestInterruption();
  if (isRunning()) wait();
}

void TelegramWorker::submitPhoneNumber(const QString &phoneNumber) { enqueue({CommandType::PhoneNumber, phoneNumber}); }
void TelegramWorker::submitCode(const QString &code) { enqueue({CommandType::Code, code}); }
void TelegramWorker::submitQrLogin() { enqueue({CommandType::QrLogin, {}}); }
void TelegramWorker::resendAuthenticationCode() { enqueue({CommandType::ResendCode, {}}); }
void TelegramWorker::selectPhoneLogin() { enqueue({CommandType::SelectPhone, {}, 0, 0}); }
void TelegramWorker::selectQrLogin() { enqueue({CommandType::SelectQr, {}, 0, 0}); }
void TelegramWorker::loadConversation(qint64 chatId, qint64 fromMessageId, int limit) {
  enqueue({CommandType::History, QString::number(fromMessageId) + ":" + QString::number(limit), chatId, 0});
}
void TelegramWorker::sendMessage(qint64 chatId, const QString &text, qint64 replyToMessageId, const QString &quoteText) {
  enqueue({CommandType::SendMessage, text, chatId, replyToMessageId, {}, quoteText});
}
void TelegramWorker::sendMedia(qint64 chatId, const QString &filePath, const QString &caption, qint64 replyToMessageId, const QString &quoteText) {
  enqueue({CommandType::SendMedia, filePath, chatId, replyToMessageId, caption, quoteText});
}
void TelegramWorker::viewMessage(qint64 chatId, qint64 messageId) {
  enqueue({CommandType::ViewMessage, {}, chatId, messageId, {}});
}
void TelegramWorker::toggleReaction(qint64 chatId, qint64 messageId, const QString &emoji, bool isChosen) {
  enqueue({isChosen ? CommandType::RemoveReaction : CommandType::AddReaction, emoji, chatId, messageId, {}});
}

void TelegramWorker::enqueue(Command command) {
  QMutexLocker locker(&m_mutex);
  m_commands.enqueue(std::move(command));
}

void TelegramWorker::run() {
  td::ClientManager manager;
  const auto qrClientId = manager.create_client_id();
  const auto phoneClientId = manager.create_client_id();
  auto activeClientId = qrClientId;
  td::ClientManager::RequestId nextRequestId = 1;
  const auto apiIdText = envValue("SILKITE_API_ID");
  const auto apiHash = envValue("SILKITE_API_HASH");
  bool qrParametersSent = false;
  bool phoneParametersSent = false;
  bool qrReady = false;
  bool phoneReady = false;
  qint64 currentOpenedChatId = 0;
  QHash<int, qint64> avatarFileChats;
  QMultiHash<int, QPair<qint64, qint64>> messageFiles; // fileId -> (chatId, messageId)
  QHash<qint64, qint64> lastReadOutbox;
  QHash<td::ClientManager::RequestId, qint64> historyRequests;
  struct UserInfo {
    bool isBot = false;
    QString statusText;
    bool isOnline = false;
  };
  QHash<qint64, UserInfo> users; // userId -> UserInfo
  QHash<qint64, qint64> chatUserIds; // chatId -> userId
  QHash<qint64, qint64> chatBasicGroupIds; // chatId -> basicGroupId
  QHash<qint64, qint64> chatSupergroupIds; // chatId -> supergroupId
  QHash<qint64, int> basicGroupMemberCount; // basicGroupId -> member_count
  QHash<qint64, int> supergroupMemberCount; // supergroupId -> member_count
  QHash<qint64, bool> supergroupIsChannel; // supergroupId -> is_channel
  bool qrPending = true;
  QString phonePending;
  QString phoneState;
  int phoneCodeLength = 5;
  int phoneCodeTimeout = 60;

  auto send = [&](td::ClientManager::ClientId clientId,
                  td::td_api::object_ptr<td::td_api::Function> request) {
    manager.send(clientId, nextRequestId++, std::move(request));
  };

  send(qrClientId, td::td_api::make_object<td::td_api::getOption>("version"));
  send(phoneClientId, td::td_api::make_object<td::td_api::getOption>("version"));

  while (!isInterruptionRequested()) {
    {
      QMutexLocker locker(&m_mutex);
      while (!m_commands.isEmpty()) {
        const auto command = m_commands.dequeue();
        if (command.type == CommandType::SelectPhone) {
          activeClientId = phoneClientId;
          if (!phoneState.isEmpty()) {
            emit authorizationStateChanged(phoneState);
            if (phoneState == "waitCode") {
              emit authenticationCodeLengthChanged(phoneCodeLength);
              emit authenticationCodeTimeoutChanged(phoneCodeTimeout);
            }
          }
        }
        if (command.type == CommandType::SelectQr) activeClientId = qrClientId;
        if (command.type == CommandType::History) {
          const auto p = command.value.split(':');
          const qint64 chatId = command.chatId;
          const qint64 fromMessageId = p.size() > 0 ? p[0].toLongLong() : 0;
          const int limit = p.size() > 1 ? p[1].toInt() : 50;

          if (currentOpenedChatId != 0 && currentOpenedChatId != chatId) {
            send(activeClientId, td::td_api::make_object<td::td_api::closeChat>(currentOpenedChatId));
            currentOpenedChatId = 0;
          }
          if (chatId != 0 && currentOpenedChatId != chatId) {
            send(activeClientId, td::td_api::make_object<td::td_api::openChat>(chatId));
            currentOpenedChatId = chatId;
          }

          const auto reqId = nextRequestId;
          historyRequests.insert(reqId, chatId);
          send(activeClientId, td::td_api::make_object<td::td_api::getChatHistory>(chatId, fromMessageId, 0, limit, false));
        }
        if (command.type == CommandType::SendMessage) {
          auto textObj = td::td_api::make_object<td::td_api::formattedText>();
          textObj->text_ = command.value.toStdString();
          auto contentObj = td::td_api::make_object<td::td_api::inputMessageText>(std::move(textObj), nullptr, true);

          td::td_api::object_ptr<td::td_api::InputMessageReplyTo> replyObj;
          if (command.messageId != 0) {
            td::td_api::object_ptr<td::td_api::inputTextQuote> quoteObj;
            if (!command.quote.isEmpty()) {
              auto qText = td::td_api::make_object<td::td_api::formattedText>();
              qText->text_ = command.quote.toStdString();
              quoteObj = td::td_api::make_object<td::td_api::inputTextQuote>();
              quoteObj->text_ = std::move(qText);
            }
            replyObj = td::td_api::make_object<td::td_api::inputMessageReplyToMessage>(command.messageId, std::move(quoteObj), 0, std::string{});
          }

          send(activeClientId, td::td_api::make_object<td::td_api::sendMessage>(
              command.chatId,
              nullptr,
              std::move(replyObj),
              nullptr,
              nullptr,
              std::move(contentObj)
          ));
        }
        if (command.type == CommandType::SendMedia) {
          const QString path = command.value;
          const QString caption = command.extra;
          const QString ext = QFileInfo(path).suffix().toLower();
          auto captionObj = td::td_api::make_object<td::td_api::formattedText>();
          captionObj->text_ = caption.toStdString();

          const bool isImage = (ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "webp" || ext == "bmp" || ext == "gif");
          td::td_api::object_ptr<td::td_api::InputMessageContent> contentObj;

          if (isImage) {
            const QSize imgSize = QImageReader(path).size();
            const int imgW = (imgSize.isValid() && imgSize.width() > 0) ? imgSize.width() : 0;
            const int imgH = (imgSize.isValid() && imgSize.height() > 0) ? imgSize.height() : 0;

            auto inputPhotoObj = td::td_api::make_object<td::td_api::inputPhoto>(
                td::td_api::make_object<td::td_api::inputFileLocal>(path.toStdString()),
                nullptr,
                nullptr,
                std::vector<td::td_api::int32>{},
                imgW,
                imgH
            );
            contentObj = td::td_api::make_object<td::td_api::inputMessagePhoto>(
                std::move(inputPhotoObj),
                std::move(captionObj),
                false,
                nullptr,
                false
            );
          } else {
            auto inputDocObj = td::td_api::make_object<td::td_api::inputDocument>(
                td::td_api::make_object<td::td_api::inputFileLocal>(path.toStdString()),
                nullptr,
                false
            );
            contentObj = td::td_api::make_object<td::td_api::inputMessageDocument>(
                std::move(inputDocObj),
                std::move(captionObj)
            );
          }

          td::td_api::object_ptr<td::td_api::InputMessageReplyTo> replyObj;
          if (command.messageId != 0) {
            td::td_api::object_ptr<td::td_api::inputTextQuote> quoteObj;
            if (!command.quote.isEmpty()) {
              auto qText = td::td_api::make_object<td::td_api::formattedText>();
              qText->text_ = command.quote.toStdString();
              quoteObj = td::td_api::make_object<td::td_api::inputTextQuote>();
              quoteObj->text_ = std::move(qText);
            }
            replyObj = td::td_api::make_object<td::td_api::inputMessageReplyToMessage>(command.messageId, std::move(quoteObj), 0, std::string{});
          }

          send(activeClientId, td::td_api::make_object<td::td_api::sendMessage>(
              command.chatId,
              nullptr,
              std::move(replyObj),
              nullptr,
              nullptr,
              std::move(contentObj)
          ));
        }
        if (command.type == CommandType::ViewMessage) {
          std::vector<td::td_api::int53> ids{command.messageId};
          send(activeClientId, td::td_api::make_object<td::td_api::viewMessages>(
              command.chatId,
              std::move(ids),
              td::td_api::make_object<td::td_api::messageSourceChatHistory>(),
              true
          ));
        }
        if (command.type == CommandType::AddReaction) {
          auto rType = td::td_api::make_object<td::td_api::reactionTypeEmoji>(command.value.toStdString());
          send(activeClientId, td::td_api::make_object<td::td_api::addMessageReaction>(
              command.chatId,
              command.messageId,
              std::move(rType),
              false,
              true
          ));
        }
        if (command.type == CommandType::RemoveReaction) {
          auto rType = td::td_api::make_object<td::td_api::reactionTypeEmoji>(command.value.toStdString());
          send(activeClientId, td::td_api::make_object<td::td_api::removeMessageReaction>(
              command.chatId,
              command.messageId,
              std::move(rType)
          ));
        }
        if (command.type == CommandType::QrLogin) {
          activeClientId = qrClientId;
          if (qrReady) {
            send(qrClientId, td::td_api::make_object<td::td_api::requestQrCodeAuthentication>(std::vector<td::td_api::int53>{}));
          } else {
            qrPending = true;
          }
        }
        if (command.type == CommandType::PhoneNumber) {
          activeClientId = phoneClientId;
          if (phoneReady && phoneState == "waitPhoneNumber") {
            send(phoneClientId, td::td_api::make_object<td::td_api::setAuthenticationPhoneNumber>(command.value.toStdString(), td::td_api::make_object<td::td_api::phoneNumberAuthenticationSettings>()));
          } else if (phoneState.isEmpty()) {
            phonePending = command.value;
          } else if (phoneState == "waitCode") {
            emit authorizationStateChanged(phoneState);
            emit authenticationCodeLengthChanged(phoneCodeLength);
            emit authenticationCodeTimeoutChanged(phoneCodeTimeout);
          } else {
            emit errorOccurred(QStringLiteral("Phone authentication is not waiting for a phone number."));
          }
        }
        if (command.type == CommandType::Code)
          send(activeClientId, td::td_api::make_object<td::td_api::checkAuthenticationCode>(command.value.toStdString()));
        if (command.type == CommandType::ResendCode)
          send(activeClientId, td::td_api::make_object<td::td_api::resendAuthenticationCode>(td::td_api::make_object<td::td_api::resendCodeReasonUserRequest>()));
      }
    }

    auto response = manager.receive(0.2);
    if (!response.object) continue;
    const bool isQrClient = response.client_id == qrClientId;
    const bool isPhoneClient = response.client_id == phoneClientId;

    if (response.object->get_id() == td::td_api::updateAuthorizationState::ID) {
      auto *update = static_cast<td::td_api::updateAuthorizationState *>(response.object.get());
      const auto stateId = update->authorization_state_->get_id();
      if (isPhoneClient)
        phoneState = stateName(*update->authorization_state_);

      if (response.client_id == activeClientId)
        emit authorizationStateChanged(stateName(*update->authorization_state_));

      if (stateId == td::td_api::authorizationStateWaitPassword::ID && response.client_id == activeClientId)
        emit errorOccurred(QStringLiteral("This build does not support password authentication."));

      if (stateId == td::td_api::authorizationStateWaitTdlibParameters::ID &&
          ((isQrClient && !qrParametersSent) || (isPhoneClient && !phoneParametersSent))) {
        if (apiIdText.empty() || apiHash.empty()) {
          if (response.client_id == activeClientId)
            emit errorOccurred(QStringLiteral("Set SILKITE_API_ID and SILKITE_API_HASH before starting Silkite."));
          continue;
        }
        bool ok = false;
        const int apiId = QString::fromStdString(apiIdText).toInt(&ok);
        if (!ok || apiId <= 0) {
          if (response.client_id == activeClientId)
            emit errorOccurred(QStringLiteral("SILKITE_API_ID must be a positive integer."));
          continue;
        }
        const auto root = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/tdlib";
        const auto dataDir = root + (isQrClient ? "/qr-auth" : "/phone-auth");
        const auto filesDir = dataDir + "/files";
        QDir().mkpath(filesDir);
        send(response.client_id, td::td_api::make_object<td::td_api::setTdlibParameters>(false, dataDir.toStdString(), filesDir.toStdString(), envValue("SILKITE_DATABASE_KEY"), true, true, true, true, apiId, apiHash, "en", "Silkite", QSysInfo::prettyProductName().toStdString(), "0.1.0"));
        if (isQrClient) qrParametersSent = true;
        else phoneParametersSent = true;
      }

      if (isQrClient && stateId == td::td_api::authorizationStateWaitPhoneNumber::ID && qrPending) {
        qrReady = true;
        send(qrClientId, td::td_api::make_object<td::td_api::requestQrCodeAuthentication>(std::vector<td::td_api::int53>{}));
        qrPending = false;
      }

      if (isQrClient && stateId == td::td_api::authorizationStateWaitPhoneNumber::ID)
        qrReady = true;

      if (isPhoneClient && stateId == td::td_api::authorizationStateWaitPhoneNumber::ID)
        phoneReady = true;

      if (isPhoneClient && stateId == td::td_api::authorizationStateWaitPhoneNumber::ID && !phonePending.isEmpty()) {
        send(phoneClientId, td::td_api::make_object<td::td_api::setAuthenticationPhoneNumber>(phonePending.toStdString(), td::td_api::make_object<td::td_api::phoneNumberAuthenticationSettings>()));
        phonePending.clear();
      }

      if (stateId == td::td_api::authorizationStateReady::ID && response.client_id == activeClientId) {
        emit chatsReset();
        send(activeClientId, td::td_api::make_object<td::td_api::loadChats>(td::td_api::make_object<td::td_api::chatListMain>(), 100));
      }

      if (isQrClient && stateId == td::td_api::authorizationStateWaitOtherDeviceConfirmation::ID) {
        auto *qrState = static_cast<td::td_api::authorizationStateWaitOtherDeviceConfirmation *>(update->authorization_state_.get());
        emit qrCodeLinkChanged(QString::fromStdString(qrState->link_));
      }

      if (response.client_id == activeClientId && stateId == td::td_api::authorizationStateWaitCode::ID) {
        phonePending.clear();
        auto *codeState = static_cast<td::td_api::authorizationStateWaitCode *>(update->authorization_state_.get());
        int length = 5;
        if (codeState->code_info_ && codeState->code_info_->type_) {
          const auto typeId = codeState->code_info_->type_->get_id();
          if (typeId == td::td_api::authenticationCodeTypeTelegramMessage::ID) length = static_cast<td::td_api::authenticationCodeTypeTelegramMessage *>(codeState->code_info_->type_.get())->length_;
          else if (typeId == td::td_api::authenticationCodeTypeSms::ID) length = static_cast<td::td_api::authenticationCodeTypeSms *>(codeState->code_info_->type_.get())->length_;
          else if (typeId == td::td_api::authenticationCodeTypeCall::ID) length = static_cast<td::td_api::authenticationCodeTypeCall *>(codeState->code_info_->type_.get())->length_;
        }
        phoneCodeLength = length;
        phoneCodeTimeout = codeState->code_info_ ? codeState->code_info_->timeout_ : 60;
        emit authenticationCodeLengthChanged(phoneCodeLength);
        emit authenticationCodeTimeoutChanged(phoneCodeTimeout);
      }
      continue;
    }

    auto inspectChat = [&](const td::td_api::chat *c) {
      if (!c) return;
      const qint64 cid = c->id_;
      if (c->type_) {
        const auto typeId = c->type_->get_id();
        if (typeId == td::td_api::chatTypePrivate::ID) {
          const auto *p = static_cast<const td::td_api::chatTypePrivate *>(c->type_.get());
          chatUserIds[cid] = p->user_id_;
          if (!users.contains(p->user_id_)) {
            send(activeClientId, td::td_api::make_object<td::td_api::getUser>(p->user_id_));
          } else {
            emit chatUpdated({{"chatId", cid}, {"statusText", users[p->user_id_].statusText}, {"isOnline", users[p->user_id_].isOnline}});
          }
        } else if (typeId == td::td_api::chatTypeSecret::ID) {
          const auto *s = static_cast<const td::td_api::chatTypeSecret *>(c->type_.get());
          chatUserIds[cid] = s->user_id_;
          if (!users.contains(s->user_id_)) {
            send(activeClientId, td::td_api::make_object<td::td_api::getUser>(s->user_id_));
          } else {
            emit chatUpdated({{"chatId", cid}, {"statusText", users[s->user_id_].statusText}, {"isOnline", users[s->user_id_].isOnline}});
          }
        } else if (typeId == td::td_api::chatTypeBasicGroup::ID) {
          const auto *bg = static_cast<const td::td_api::chatTypeBasicGroup *>(c->type_.get());
          chatBasicGroupIds[cid] = bg->basic_group_id_;
          if (basicGroupMemberCount.contains(bg->basic_group_id_)) {
            emit chatUpdated({{"chatId", cid}, {"statusText", QStringLiteral("%1 members").arg(basicGroupMemberCount[bg->basic_group_id_])}, {"isOnline", false}});
          }
          send(activeClientId, td::td_api::make_object<td::td_api::getBasicGroup>(bg->basic_group_id_));
        } else if (typeId == td::td_api::chatTypeSupergroup::ID) {
          const auto *sg = static_cast<const td::td_api::chatTypeSupergroup *>(c->type_.get());
          chatSupergroupIds[cid] = sg->supergroup_id_;
          if (supergroupMemberCount.contains(sg->supergroup_id_)) {
            const bool isChan = supergroupIsChannel.value(sg->supergroup_id_, false);
            const QString desc = isChan
                ? QStringLiteral("%1 subscribers").arg(supergroupMemberCount[sg->supergroup_id_])
                : QStringLiteral("%1 members").arg(supergroupMemberCount[sg->supergroup_id_]);
            emit chatUpdated({{"chatId", cid}, {"statusText", desc}, {"isOnline", false}});
          }
          send(activeClientId, td::td_api::make_object<td::td_api::getSupergroup>(sg->supergroup_id_));
        }
      }
    };

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateNewChat::ID) { auto *chat = static_cast<td::td_api::updateNewChat *>(response.object.get())->chat_.get(); if (chat) { lastReadOutbox.insert(chat->id_, chat->last_read_outbox_message_id_); if (chat->photo_ && chat->photo_->small_) { const int fileId = chat->photo_->small_->id_; avatarFileChats.insert(fileId, chat->id_); send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileId, 1, 0, 0, false)); } inspectChat(chat); emit chatUpdated(toChatMap(chat)); } continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatTitle::ID) { auto *u = static_cast<td::td_api::updateChatTitle *>(response.object.get()); emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"name", QString::fromStdString(u->title_)}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatPhoto::ID) { auto *u = static_cast<td::td_api::updateChatPhoto *>(response.object.get()); if (u->photo_ && u->photo_->small_) { const int fileId = u->photo_->small_->id_; avatarFileChats.insert(fileId, u->chat_id_); send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileId, 1, 0, 0, false)); } continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateUnreadMessageCount::ID) { auto *u = static_cast<td::td_api::updateUnreadMessageCount *>(response.object.get()); Q_UNUSED(u); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatLastMessage::ID) { auto *u = static_cast<td::td_api::updateChatLastMessage *>(response.object.get()); emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"lastMessage", preview(u->last_message_.get())}, {"time", u->last_message_ ? QDateTime::fromSecsSinceEpoch(u->last_message_->date_).toLocalTime().toString("HH:mm") : QString()}, {"order", mainChatOrder(u->positions_)}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatDraftMessage::ID) { auto *u = static_cast<td::td_api::updateChatDraftMessage *>(response.object.get()); const qint64 order = mainChatOrder(u->positions_); if (order > 0) emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"order", order}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatPosition::ID) { auto *u = static_cast<td::td_api::updateChatPosition *>(response.object.get()); if (u->position_ && u->position_->list_ && u->position_->list_->get_id() == td::td_api::chatListMain::ID) emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"order", qint64(u->position_->order_)}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatReadInbox::ID) { auto *u = static_cast<td::td_api::updateChatReadInbox *>(response.object.get()); emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"unreadCount", u->unread_count_}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatReadOutbox::ID) { auto *u = static_cast<td::td_api::updateChatReadOutbox *>(response.object.get()); lastReadOutbox.insert(u->chat_id_, u->last_read_outbox_message_id_); emit chatReadOutboxUpdated(qint64(u->chat_id_), qint64(u->last_read_outbox_message_id_)); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatAction::ID) { auto *u = static_cast<td::td_api::updateChatAction *>(response.object.get()); emit chatTyping(qint64(u->chat_id_), u->action_ && u->action_->get_id() == td::td_api::chatActionTyping::ID); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateMessageReactions::ID) {
      auto *u = static_cast<td::td_api::updateMessageReactions *>(response.object.get());
      QVariantList list;
      for (const auto &r : u->reactions_) {
        if (!r || !r->type_) continue;
        if (r->type_->get_id() == td::td_api::reactionTypeEmoji::ID) {
          auto *re = static_cast<const td::td_api::reactionTypeEmoji *>(r->type_.get());
          QVariantMap item;
          item["emoji"] = QString::fromStdString(re->emoji_);
          item["count"] = r->total_count_;
          item["isChosen"] = r->is_chosen_;
          list.append(item);
        }
      }
      emit messageReactionsUpdated(qint64(u->chat_id_), qint64(u->message_id_), list);
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateMessageInteractionInfo::ID) {
      auto *u = static_cast<td::td_api::updateMessageInteractionInfo *>(response.object.get());
      if (u->interaction_info_ && u->interaction_info_->reactions_) {
        QVariantList list = parseReactions(u->interaction_info_->reactions_.get());
        emit messageReactionsUpdated(qint64(u->chat_id_), qint64(u->message_id_), list);
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateNewMessage::ID) {
      auto *u = static_cast<td::td_api::updateNewMessage *>(response.object.get());
      if (u->message_) {
        const auto chatId = qint64(u->message_->chat_id_);
        const bool read = lastReadOutbox.value(chatId, 0) >= qint64(u->message_->id_);
        emit chatUpdated({{"chatId", chatId}, {"lastMessage", preview(u->message_.get())}, {"time", QDateTime::fromSecsSinceEpoch(u->message_->date_).toLocalTime().toString("HH:mm")}, {"order", qint64(u->message_->id_)}});

        int fileIdToDownload = 0;
        QVariantMap msgMap = parseMessage(u->message_.get(), fileIdToDownload);
        msgMap["status"] = u->message_->is_outgoing_ ? (read ? QStringLiteral("✓✓") : QStringLiteral("✓")) : QString();

        if (fileIdToDownload != 0) {
          messageFiles.insert(fileIdToDownload, qMakePair(chatId, qint64(u->message_->id_)));
          send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileIdToDownload, 32, 0, 0, false));
        }

        emit messageReceived(chatId, msgMap);
        if (!u->message_->is_outgoing_ && currentOpenedChatId == chatId) {
          std::vector<td::td_api::int53> ids{u->message_->id_};
          send(activeClientId, td::td_api::make_object<td::td_api::viewMessages>(chatId, std::move(ids), td::td_api::make_object<td::td_api::messageSourceChatHistory>(), true));
        }
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateMessageSendSucceeded::ID) {
      auto *u = static_cast<td::td_api::updateMessageSendSucceeded *>(response.object.get());
      if (u->message_) {
        const auto chatId = qint64(u->message_->chat_id_);
        const bool read = lastReadOutbox.value(chatId, 0) >= qint64(u->message_->id_);

        int fileIdToDownload = 0;
        QVariantMap msgMap = parseMessage(u->message_.get(), fileIdToDownload);
        msgMap["status"] = read ? QStringLiteral("✓✓") : QStringLiteral("✓");

        if (fileIdToDownload != 0) {
          messageFiles.insert(fileIdToDownload, qMakePair(chatId, qint64(u->message_->id_)));
          send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileIdToDownload, 32, 0, 0, false));
        }

        emit messageSendSucceeded(chatId, qint64(u->old_message_id_), msgMap);
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::chats::ID) { auto *r = static_cast<td::td_api::chats *>(response.object.get()); for (const auto id : r->chat_ids_) send(activeClientId, td::td_api::make_object<td::td_api::getChat>(id)); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::chat::ID) { auto *chat = static_cast<td::td_api::chat *>(response.object.get()); lastReadOutbox.insert(chat->id_, chat->last_read_outbox_message_id_); emit chatReadOutboxUpdated(qint64(chat->id_), qint64(chat->last_read_outbox_message_id_)); if (chat->photo_ && chat->photo_->small_) { const int fileId = chat->photo_->small_->id_; avatarFileChats.insert(fileId, chat->id_); send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileId, 1, 0, 0, false)); } inspectChat(chat); emit chatUpdated(toChatMap(chat)); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateFile::ID) {
      auto *u = static_cast<td::td_api::updateFile *>(response.object.get());
      if (u->file_ && u->file_->local_ && u->file_->local_->is_downloading_completed_) {
        const int fid = u->file_->id_;
        const QString localPath = QString::fromStdString(u->file_->local_->path_);
        if (avatarFileChats.contains(fid)) {
          emit chatUpdated({{"chatId", avatarFileChats.value(fid)}, {"avatarPath", localPath}});
        }
        if (messageFiles.contains(fid)) {
          const auto pairs = messageFiles.values(fid);
          messageFiles.remove(fid);
          QString outPath = localPath;
          if (localPath.endsWith(".mp4", Qt::CaseInsensitive) || localPath.endsWith(".mov", Qt::CaseInsensitive) || localPath.endsWith(".webm", Qt::CaseInsensitive)) {
            outPath = ensureGifConverted(localPath);
          }
          for (const auto &pair : pairs) {
            emit messageFileUpdated(pair.first, pair.second, outPath);
          }
        }
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::messages::ID) {
      auto *r = static_cast<td::td_api::messages *>(response.object.get());
      QVariantList list;
      qint64 chatId = historyRequests.take(response.request_id);
      std::vector<td::td_api::int53> ids;
      for (auto it = r->messages_.rbegin(); it != r->messages_.rend(); ++it) {
        const auto &m = *it;
        if (!m) continue;
        if (!chatId) chatId = m->chat_id_;
        ids.push_back(m->id_);
        const bool read = lastReadOutbox.value(chatId, 0) >= qint64(m->id_);

        int fileIdToDownload = 0;
        QVariantMap msgMap = parseMessage(m.get(), fileIdToDownload);
        msgMap["status"] = m->is_outgoing_ ? (read ? QStringLiteral("✓✓") : QStringLiteral("✓")) : QString();

        if (fileIdToDownload != 0) {
          messageFiles.insert(fileIdToDownload, qMakePair(chatId, qint64(m->id_)));
          send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileIdToDownload, 32, 0, 0, false));
        }

        list.append(msgMap);
      }
      if (chatId && !ids.empty()) {
        send(activeClientId, td::td_api::make_object<td::td_api::viewMessages>(
            chatId, std::move(ids), td::td_api::make_object<td::td_api::messageSourceChatHistory>(), true));
      }
      emit messagesLoaded(chatId, list, r->messages_.size() >= 50);
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateUser::ID) {
      auto *u = static_cast<td::td_api::updateUser *>(response.object.get());
      if (u->user_) {
        const qint64 uid = u->user_->id_;
        const bool isBot = u->user_->type_ && u->user_->type_->get_id() == td::td_api::userTypeBot::ID;
        users[uid].isBot = isBot;
        if (u->user_->status_) {
          bool isOnline = false;
          users[uid].statusText = formatUserStatus(u->user_->status_.get(), isBot, &isOnline);
          users[uid].isOnline = isOnline;
        }
        for (auto it = chatUserIds.begin(); it != chatUserIds.end(); ++it) {
          if (it.value() == uid) {
            emit chatUpdated({{"chatId", it.key()}, {"statusText", users[uid].statusText}, {"isOnline", users[uid].isOnline}});
          }
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::user::ID) {
      auto *u = static_cast<td::td_api::user *>(response.object.get());
      const qint64 uid = u->id_;
      const bool isBot = u->type_ && u->type_->get_id() == td::td_api::userTypeBot::ID;
      users[uid].isBot = isBot;
      if (u->status_) {
        bool isOnline = false;
        users[uid].statusText = formatUserStatus(u->status_.get(), isBot, &isOnline);
        users[uid].isOnline = isOnline;
      }
      for (auto it = chatUserIds.begin(); it != chatUserIds.end(); ++it) {
        if (it.value() == uid) {
          emit chatUpdated({{"chatId", it.key()}, {"statusText", users[uid].statusText}, {"isOnline", users[uid].isOnline}});
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateUserStatus::ID) {
      auto *u = static_cast<td::td_api::updateUserStatus *>(response.object.get());
      const qint64 uid = u->user_id_;
      const bool isBot = users.contains(uid) ? users[uid].isBot : false;
      if (u->status_) {
        bool isOnline = false;
        users[uid].statusText = formatUserStatus(u->status_.get(), isBot, &isOnline);
        users[uid].isOnline = isOnline;
      }
      for (auto it = chatUserIds.begin(); it != chatUserIds.end(); ++it) {
        if (it.value() == uid) {
          emit chatUpdated({{"chatId", it.key()}, {"statusText", users[uid].statusText}, {"isOnline", users[uid].isOnline}});
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateBasicGroup::ID) {
      auto *u = static_cast<td::td_api::updateBasicGroup *>(response.object.get());
      if (u->basic_group_) {
        const qint64 bgId = u->basic_group_->id_;
        const int count = u->basic_group_->member_count_;
        basicGroupMemberCount[bgId] = count;
        for (auto it = chatBasicGroupIds.begin(); it != chatBasicGroupIds.end(); ++it) {
          if (it.value() == bgId) {
            emit chatUpdated({{"chatId", it.key()}, {"statusText", QStringLiteral("%1 members").arg(count)}, {"isOnline", false}});
          }
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::basicGroup::ID) {
      auto *bg = static_cast<td::td_api::basicGroup *>(response.object.get());
      const qint64 bgId = bg->id_;
      const int count = bg->member_count_;
      basicGroupMemberCount[bgId] = count;
      for (auto it = chatBasicGroupIds.begin(); it != chatBasicGroupIds.end(); ++it) {
        if (it.value() == bgId) {
          emit chatUpdated({{"chatId", it.key()}, {"statusText", QStringLiteral("%1 members").arg(count)}, {"isOnline", false}});
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateSupergroup::ID) {
      auto *u = static_cast<td::td_api::updateSupergroup *>(response.object.get());
      if (u->supergroup_) {
        const qint64 sgId = u->supergroup_->id_;
        const int count = u->supergroup_->member_count_;
        const bool isChan = u->supergroup_->is_channel_;
        supergroupMemberCount[sgId] = count;
        supergroupIsChannel[sgId] = isChan;
        for (auto it = chatSupergroupIds.begin(); it != chatSupergroupIds.end(); ++it) {
          if (it.value() == sgId) {
            const QString desc = isChan
                ? QStringLiteral("%1 subscribers").arg(count)
                : QStringLiteral("%1 members").arg(count);
            emit chatUpdated({{"chatId", it.key()}, {"statusText", desc}, {"isOnline", false}});
          }
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::supergroup::ID) {
      auto *sg = static_cast<td::td_api::supergroup *>(response.object.get());
      const qint64 sgId = sg->id_;
      const int count = sg->member_count_;
      const bool isChan = sg->is_channel_;
      supergroupMemberCount[sgId] = count;
      supergroupIsChannel[sgId] = isChan;
      for (auto it = chatSupergroupIds.begin(); it != chatSupergroupIds.end(); ++it) {
        if (it.value() == sgId) {
          const QString desc = isChan
              ? QStringLiteral("%1 subscribers").arg(count)
              : QStringLiteral("%1 members").arg(count);
          emit chatUpdated({{"chatId", it.key()}, {"statusText", desc}, {"isOnline", false}});
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateBasicGroupFullInfo::ID) {
      auto *u = static_cast<td::td_api::updateBasicGroupFullInfo *>(response.object.get());
      if (u->basic_group_full_info_) {
        const qint64 bgId = u->basic_group_id_;
        const int count = static_cast<int>(u->basic_group_full_info_->members_.size());
        if (count > 0) {
          basicGroupMemberCount[bgId] = count;
          for (auto it = chatBasicGroupIds.begin(); it != chatBasicGroupIds.end(); ++it) {
            if (it.value() == bgId) {
              emit chatUpdated({{"chatId", it.key()}, {"statusText", QStringLiteral("%1 members").arg(count)}, {"isOnline", false}});
            }
          }
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateSupergroupFullInfo::ID) {
      auto *u = static_cast<td::td_api::updateSupergroupFullInfo *>(response.object.get());
      if (u->supergroup_full_info_) {
        const qint64 sgId = u->supergroup_id_;
        const int count = u->supergroup_full_info_->member_count_;
        if (count > 0) {
          supergroupMemberCount[sgId] = count;
          const bool isChan = supergroupIsChannel.value(sgId, false);
          for (auto it = chatSupergroupIds.begin(); it != chatSupergroupIds.end(); ++it) {
            if (it.value() == sgId) {
              const QString desc = isChan
                  ? QStringLiteral("%1 subscribers").arg(count)
                  : QStringLiteral("%1 members").arg(count);
              emit chatUpdated({{"chatId", it.key()}, {"statusText", desc}, {"isOnline", false}});
            }
          }
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::error::ID) {
      auto *error = static_cast<td::td_api::error *>(response.object.get());
      emit errorOccurred(QString::fromStdString(error->message_));
    } else if (response.request_id != 0 && response.object->get_id() == td::td_api::optionValueString::ID) {
      auto *result = static_cast<td::td_api::optionValueString *>(response.object.get());
      if (response.client_id == activeClientId) emit versionReceived(QString::fromStdString(result->value_));
    }
  }
}
