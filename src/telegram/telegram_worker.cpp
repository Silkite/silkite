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
  if (contentId == td::td_api::messageSticker::ID) {
    auto *s = static_cast<const td::td_api::messageSticker *>(message->content_.get());
    if (s->sticker_ && !s->sticker_->emoji_.empty()) {
      return QString::fromStdString(s->sticker_->emoji_) + QStringLiteral(" Sticker");
    }
    return QStringLiteral("Sticker");
  }
  if (contentId == td::td_api::messageAnimatedEmoji::ID) {
    auto *ae = static_cast<const td::td_api::messageAnimatedEmoji *>(message->content_.get());
    if (!ae->emoji_.empty()) {
      return QString::fromStdString(ae->emoji_);
    }
    return QStringLiteral("Emoji");
  }
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
      if (cid == td::td_api::messageSticker::ID) {
        auto *s = static_cast<const td::td_api::messageSticker *>(reply->content_.get());
        if (s->sticker_ && !s->sticker_->emoji_.empty()) {
          return QString::fromStdString(s->sticker_->emoji_) + QStringLiteral(" Sticker");
        }
        return QStringLiteral("Sticker");
      }
      if (cid == td::td_api::messageAnimatedEmoji::ID) {
        auto *ae = static_cast<const td::td_api::messageAnimatedEmoji *>(reply->content_.get());
        if (!ae->emoji_.empty()) {
          return QString::fromStdString(ae->emoji_);
        }
        return QStringLiteral("Emoji");
      }
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

  if (message->sending_state_) {
    const auto stateId = message->sending_state_->get_id();
    if (stateId == td::td_api::messageSendingStateFailed::ID) {
      auto *f = static_cast<const td::td_api::messageSendingStateFailed *>(message->sending_state_.get());
      map["status"] = QStringLiteral("!");
      map["sendError"] = f->error_ ? QString::fromStdString(f->error_->message_) : QStringLiteral("Failed to send message");
    } else if (stateId == td::td_api::messageSendingStatePending::ID) {
      map["status"] = QStringLiteral("🕒");
    }
  }

  if (!message->content_) return map;
  const auto contentId = message->content_->get_id();

  if (contentId == td::td_api::messageText::ID) {
    auto *t = static_cast<const td::td_api::messageText *>(message->content_.get());
    const QString txt = QString::fromStdString(t->text_->text_);
    map["text"] = txt;
    // Check if message consists of exactly a single emoji (supports standard emoji & extended pictographs)
    static const QRegularExpression singleEmojiRegex(QStringLiteral("^(\\p{Emoji_Presentation}|\\p{Extended_Pictographic}|\\p{Emoji}\\x{FE0F})$"));
    map["isSingleEmoji"] = singleEmojiRegex.match(txt.trimmed()).hasMatch();
  } else if (contentId == td::td_api::messageAnimatedEmoji::ID) {
    auto *ae = static_cast<const td::td_api::messageAnimatedEmoji *>(message->content_.get());
    const QString emo = QString::fromStdString(ae->emoji_);
    map["text"] = emo;
    map["isSingleEmoji"] = true;
    map["mediaType"] = QStringLiteral("none");
    if (ae->animated_emoji_ && ae->animated_emoji_->sticker_) {
      const auto &stk = ae->animated_emoji_->sticker_;
      map["stickerEmoji"] = emo;
      map["mediaWidth"] = ae->animated_emoji_->sticker_width_ > 0 ? ae->animated_emoji_->sticker_width_ : stk->width_;
      map["mediaHeight"] = ae->animated_emoji_->sticker_height_ > 0 ? ae->animated_emoji_->sticker_height_ : stk->height_;
      if (stk->thumbnail_ && stk->thumbnail_->file_) {
        const int tfid = stk->thumbnail_->file_->id_;
        const QString tPath = stk->thumbnail_->file_->local_ ? QString::fromStdString(stk->thumbnail_->file_->local_->path_) : QString();
        if (!tPath.isEmpty() && QFile::exists(tPath)) {
          map["filePath"] = tPath;
        } else if (tfid != 0) {
          fileIdToDownload = tfid;
          map["isDownloading"] = true;
        }
      }
      if (stk->sticker_) {
        const int fid = stk->sticker_->id_;
        map["fileId"] = fid;
        const QString localPath = stk->sticker_->local_ ? QString::fromStdString(stk->sticker_->local_->path_) : QString();
        if (!localPath.isEmpty() && (stk->sticker_->local_->is_downloading_completed_ || QFile::exists(localPath))) {
          map["filePath"] = localPath;
          map["isDownloading"] = false;
        } else {
          fileIdToDownload = fid;
          map["isDownloading"] = true;
        }
      }
    }
  } else if (contentId == td::td_api::messageSticker::ID) {
    auto *s = static_cast<const td::td_api::messageSticker *>(message->content_.get());
    map["mediaType"] = QStringLiteral("sticker");
    if (s->sticker_) {
      map["mediaWidth"] = s->sticker_->width_;
      map["mediaHeight"] = s->sticker_->height_;
      if (!s->sticker_->emoji_.empty()) {
        const QString sEmoji = QString::fromStdString(s->sticker_->emoji_);
        map["stickerEmoji"] = sEmoji;
        map["text"] = sEmoji;
      }
      if (s->sticker_->thumbnail_ && s->sticker_->thumbnail_->file_) {
        const int tfid = s->sticker_->thumbnail_->file_->id_;
        const QString tPath = s->sticker_->thumbnail_->file_->local_ ? QString::fromStdString(s->sticker_->thumbnail_->file_->local_->path_) : QString();
        if (!tPath.isEmpty() && QFile::exists(tPath)) {
          map["filePath"] = tPath;
        } else if (tfid != 0) {
          fileIdToDownload = tfid;
          map["isDownloading"] = true;
        }
      }
      if (s->sticker_->sticker_) {
        const int fid = s->sticker_->sticker_->id_;
        map["fileId"] = fid;
        const QString localPath = s->sticker_->sticker_->local_ ? QString::fromStdString(s->sticker_->sticker_->local_->path_) : QString();
        if (!localPath.isEmpty() && (s->sticker_->sticker_->local_->is_downloading_completed_ || QFile::exists(localPath))) {
          map["filePath"] = localPath;
          map["isDownloading"] = false;
        } else {
          fileIdToDownload = fid;
          map["isDownloading"] = true;
        }
      }
    }
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

qint64 userStatusOrderSecs(const td::td_api::UserStatus *status, bool isOnline) {
  if (isOnline) {
    return std::numeric_limits<qint64>::max(); // online top priority
  }
  if (!status) return 0;
  switch (status->get_id()) {
  case td::td_api::userStatusOnline::ID:
    return std::numeric_limits<qint64>::max();
  case td::td_api::userStatusOffline::ID: {
    auto *offline = static_cast<const td::td_api::userStatusOffline *>(status);
    return offline->was_online_ > 0 ? qint64(offline->was_online_) : 0;
  }
  case td::td_api::userStatusRecently::ID:
    return QDateTime::currentSecsSinceEpoch() - 3600; // ~1 hour ago weight
  case td::td_api::userStatusLastWeek::ID:
    return QDateTime::currentSecsSinceEpoch() - 86400 * 5;
  case td::td_api::userStatusLastMonth::ID:
    return QDateTime::currentSecsSinceEpoch() - 86400 * 20;
  default:
    return 0;
  }
}

QVariantMap toUserContactMap(const td::td_api::user *u, const QString &statusText, bool isOnline, qint64 lastSeenSecs, const QString &avatarPath) {
  if (!u) return {};
  const QString fn = QString::fromStdString(u->first_name_);
  const QString ln = QString::fromStdString(u->last_name_);
  QString fullName = (fn + " " + ln).trimmed();
  if (fullName.isEmpty()) fullName = QString::fromStdString(u->phone_number_);
  if (fullName.isEmpty()) fullName = QStringLiteral("Unknown");

  const QString initials = fullName.left(2).toUpper();

  QString username;
  if (u->usernames_ && !u->usernames_->active_usernames_.empty()) {
    username = QString::fromStdString(u->usernames_->active_usernames_[0]);
  } else if (u->usernames_ && !u->usernames_->editable_username_.empty()) {
    username = QString::fromStdString(u->usernames_->editable_username_);
  }

  return {
    {"userId", qint64(u->id_)},
    {"firstName", fn},
    {"lastName", ln},
    {"fullName", fullName},
    {"name", fullName},
    {"username", username},
    {"phoneNumber", QString::fromStdString(u->phone_number_)},
    {"statusText", statusText},
    {"isOnline", isOnline},
    {"lastSeenSecs", lastSeenSecs},
    {"initials", initials},
    {"avatarColor", QStringLiteral("#526C8A")},
    {"avatarPath", avatarPath},
    {"hasChatHistory", false}
  };
}

static bool isMemberStatus(const td::td_api::ChatMemberStatus *status) {
  if (!status) return true;
  const auto id = status->get_id();
  if (id == td::td_api::chatMemberStatusMember::ID ||
      id == td::td_api::chatMemberStatusAdministrator::ID) {
    return true;
  }
  if (id == td::td_api::chatMemberStatusCreator::ID) {
    auto *creator = static_cast<const td::td_api::chatMemberStatusCreator *>(status);
    return creator->is_member_;
  }
  if (id == td::td_api::chatMemberStatusRestricted::ID) {
    auto *restricted = static_cast<const td::td_api::chatMemberStatusRestricted *>(status);
    return restricted->is_member_;
  }
  if (id == td::td_api::chatMemberStatusLeft::ID ||
      id == td::td_api::chatMemberStatusBanned::ID) {
    return false;
  }
  return true;
}

QVariantMap toChatMap(const td::td_api::chat *chat) {
  if (!chat) return {};
  const QString name = QString::fromStdString(chat->title_);
  QString avatarPath;
  if (chat->photo_ && chat->photo_->small_ && chat->photo_->small_->local_ && chat->photo_->small_->local_->is_downloading_completed_)
    avatarPath = QString::fromStdString(chat->photo_->small_->local_->path_);
  const bool hasHist = (chat->last_message_ != nullptr);
  qint64 order = 0;
  const bool isPrivate = chat->type_ && chat->type_->get_id() == td::td_api::chatTypePrivate::ID;
  if (!isPrivate || hasHist) {
    for (const auto &position : chat->positions_)
      if (position && position->list_ && position->list_->get_id() == td::td_api::chatListMain::ID)
        order = position->order_;
  }
  bool canSendMessages = true;
  if (chat->permissions_) {
    canSendMessages = chat->permissions_->can_send_basic_messages_;
  }
  if (chat->type_ && chat->type_->get_id() == td::td_api::chatTypeSupergroup::ID) {
    auto *sg = static_cast<const td::td_api::chatTypeSupergroup *>(chat->type_.get());
    if (sg->is_channel_) {
      canSendMessages = chat->permissions_ ? chat->permissions_->can_send_basic_messages_ : false;
    }
  }
  QString chatTypeStr = QStringLiteral("group");
  qint64 targetUserId = 0;
  if (chat->type_) {
    const auto tid = chat->type_->get_id();
    if (tid == td::td_api::chatTypePrivate::ID) {
      chatTypeStr = QStringLiteral("user");
      targetUserId = static_cast<const td::td_api::chatTypePrivate *>(chat->type_.get())->user_id_;
    } else if (tid == td::td_api::chatTypeSecret::ID) {
      chatTypeStr = QStringLiteral("user");
      targetUserId = static_cast<const td::td_api::chatTypeSecret *>(chat->type_.get())->user_id_;
    } else if (tid == td::td_api::chatTypeSupergroup::ID) {
      auto *sg = static_cast<const td::td_api::chatTypeSupergroup *>(chat->type_.get());
      chatTypeStr = sg->is_channel_ ? QStringLiteral("channel") : QStringLiteral("group");
    } else if (tid == td::td_api::chatTypeBasicGroup::ID) {
      chatTypeStr = QStringLiteral("group");
    }
  }

  bool isMember = true;
  bool isMuted = false;
  if (chat->notification_settings_) {
    isMuted = (chat->notification_settings_->mute_for_ > 0);
  }

  return {{"chatId", qint64(chat->id_)}, {"name", name}, {"lastMessage", preview(chat->last_message_.get())},
          {"time", chat->last_message_ ? QDateTime::fromSecsSinceEpoch(chat->last_message_->date_).toLocalTime().toString("HH:mm") : QString()},
          {"initials", name.trimmed().isEmpty() ? QStringLiteral("?") : name.trimmed().left(2).toUpper()},
          {"avatarColor", QStringLiteral("#526C8A")}, {"avatarPath", avatarPath},
          {"unreadCount", chat->unread_count_}, {"order", order},
          {"canSendMessages", canSendMessages},
          {"canBeDeletedOnlyForSelf", chat->can_be_deleted_only_for_self_},
          {"canBeDeletedForAllUsers", chat->can_be_deleted_for_all_users_},
          {"type", chatTypeStr},
          {"userId", targetUserId},
          {"isMember", isMember},
          {"isMuted", isMuted}};
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

void TelegramWorker::addContact(const QString &phoneNumber, const QString &firstName, const QString &lastName) {
  Command cmd;
  cmd.type = CommandType::AddContact;
  cmd.value = phoneNumber;
  cmd.extra = firstName;
  cmd.quote = lastName;
  enqueue(std::move(cmd));
}

void TelegramWorker::createNewGroup(const QString &title, const QList<qint64> &userIds) {
  Command cmd;
  cmd.type = CommandType::CreateGroup;
  cmd.value = title;
  cmd.userIds = userIds;
  enqueue(std::move(cmd));
}

void TelegramWorker::createPrivateChatForUser(qint64 userId) {
  Command cmd;
  cmd.type = CommandType::CreatePrivateChat;
  cmd.chatId = userId; // store userId in chatId field
  enqueue(std::move(cmd));
}

void TelegramWorker::deleteContact(qint64 userId) {
  Command cmd;
  cmd.type = CommandType::DeleteContact;
  cmd.chatId = userId;
  enqueue(std::move(cmd));
}

void TelegramWorker::loadContacts() {
  Command cmd;
  cmd.type = CommandType::LoadContacts;
  enqueue(std::move(cmd));
}

void TelegramWorker::loadUserProfile(qint64 userId, qint64 chatId) {
  Command cmd;
  cmd.type = CommandType::LoadUserProfile;
  cmd.chatId = userId;
  cmd.messageId = chatId; // repurpose messageId field to carry chatId if provided
  enqueue(std::move(cmd));
}

void TelegramWorker::blockUser(qint64 userId, bool block) {
  Command cmd;
  cmd.type = CommandType::BlockUser;
  cmd.chatId = userId;
  cmd.flag = block;
  enqueue(std::move(cmd));
}

void TelegramWorker::deleteChat(qint64 chatId) {
  Command cmd;
  cmd.type = CommandType::DeleteChat;
  cmd.chatId = chatId;
  enqueue(std::move(cmd));
}

void TelegramWorker::deleteChatHistory(qint64 chatId, bool removeFromChatList, bool revoke) {
  Command cmd;
  cmd.type = CommandType::DeleteChatHistory;
  cmd.chatId = chatId;
  cmd.flag = removeFromChatList;
  cmd.revoke = revoke;
  enqueue(std::move(cmd));
}

void TelegramWorker::logOut() {
  Command cmd;
  cmd.type = CommandType::LogOut;
  enqueue(std::move(cmd));
}

void TelegramWorker::searchLocal(const QString &query) {
  Command cmd;
  cmd.type = CommandType::SearchLocal;
  cmd.value = query;
  enqueue(std::move(cmd));
}

void TelegramWorker::searchGlobal(const QString &query) {
  Command cmd;
  cmd.type = CommandType::SearchGlobal;
  cmd.value = query;
  enqueue(std::move(cmd));
}

void TelegramWorker::addRecentlyFoundChat(qint64 chatId) {
  Command cmd;
  cmd.type = CommandType::AddRecentlyFoundChat;
  cmd.chatId = chatId;
  enqueue(std::move(cmd));
}

void TelegramWorker::joinChat(qint64 chatId) {
  Command cmd;
  cmd.type = CommandType::JoinChat;
  cmd.chatId = chatId;
  enqueue(std::move(cmd));
}

void TelegramWorker::leaveChat(qint64 chatId) {
  Command cmd;
  cmd.type = CommandType::LeaveChat;
  cmd.chatId = chatId;
  enqueue(std::move(cmd));
}

void TelegramWorker::toggleChatMute(qint64 chatId, bool mute) {
  Command cmd;
  cmd.type = CommandType::ToggleChatMute;
  cmd.chatId = chatId;
  cmd.flag = mute;
  enqueue(std::move(cmd));
}

void TelegramWorker::setProfilePhoto(const QString &filePath) {
  Command cmd;
  cmd.type = CommandType::SetProfilePhoto;
  cmd.value = filePath;
  enqueue(std::move(cmd));
}

void TelegramWorker::setName(const QString &firstName, const QString &lastName) {
  Command cmd;
  cmd.type = CommandType::SetName;
  cmd.value = firstName;
  cmd.extra = lastName;
  enqueue(std::move(cmd));
}

void TelegramWorker::setBio(const QString &bio) {
  Command cmd;
  cmd.type = CommandType::SetBio;
  cmd.value = bio;
  enqueue(std::move(cmd));
}

void TelegramWorker::setUsername(const QString &username) {
  Command cmd;
  cmd.type = CommandType::SetUsername;
  cmd.value = username;
  enqueue(std::move(cmd));
}

void TelegramWorker::enqueue(Command command) {
  QMutexLocker locker(&m_mutex);
  m_commands.enqueue(std::move(command));
}

void TelegramWorker::run() {
  td::ClientManager::execute(td::td_api::make_object<td::td_api::setLogVerbosityLevel>(1));
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
    qint64 lastSeenSecs = 0;
    QString avatarPath;
  };
  QHash<qint64, UserInfo> users; // userId -> UserInfo
  QHash<int, qint64> avatarFileUsers; // fileId -> userId
  QSet<qint64> contactUserIds;
  QHash<qint64, qint64> userPrivateChats; // userId -> chatId
  QHash<qint64, bool> chatHasHistory; // chatId -> bool
  QHash<td::ClientManager::RequestId, qint64> pendingPrivateChatRequests; // reqId -> userId
  struct PendingGroupCreation {
    QString title;
    QList<qint64> userIds;
    bool isSupergroupFallback = false;
  };
  QHash<td::ClientManager::RequestId, PendingGroupCreation> pendingCreateGroupRequests;
  QHash<qint64, qint64> chatUserIds; // chatId -> userId
  QHash<qint64, qint64> chatBasicGroupIds; // chatId -> basicGroupId
  QHash<qint64, qint64> chatSupergroupIds; // chatId -> supergroupId
  QHash<qint64, int> basicGroupMemberCount; // basicGroupId -> member_count
  QHash<qint64, int> supergroupMemberCount; // supergroupId -> member_count
  QHash<qint64, bool> supergroupIsChannel; // supergroupId -> is_channel
  QHash<td::ClientManager::RequestId, qint64> pendingProfilePhotoRequests; // reqId -> userId
  QHash<td::ClientManager::RequestId, qint64> pendingUserFullInfoRequests; // reqId -> userId
  QHash<td::ClientManager::RequestId, bool> pendingProfileChatRequests; // reqId -> true
  QHash<td::ClientManager::RequestId, qint64> pendingCanSendMessageRequests; // reqId -> userId
  QHash<td::ClientManager::RequestId, QString> pendingLocalSearchRequests; // reqId -> query
  QHash<td::ClientManager::RequestId, QString> pendingGlobalSearchRequests; // reqId -> query
  QHash<td::ClientManager::RequestId, QString> pendingPublicChatRequests; // reqId -> query
  QHash<qint64, QVariantMap> cachedChats; // chatId -> chat map
  qint64 myUserId = 0;
  td::ClientManager::RequestId myUserIdReqId = 0;
  QHash<int, qint64> profilePhotoFiles; // fileId -> userId
  QHash<qint64, QVariantMap> userFullProfiles; // userId -> full profile map
  QHash<qint64, QVariantList> userPhotoGalleries; // userId -> list of photo objects
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
        if (command.type == CommandType::AddContact) {
          auto imported = td::td_api::make_object<td::td_api::importedContact>();
          imported->phone_number_ = command.value.toStdString();
          imported->first_name_ = command.extra.toStdString();
          imported->last_name_ = command.quote.toStdString();
          std::vector<td::td_api::object_ptr<td::td_api::importedContact>> vec;
          vec.push_back(std::move(imported));
          send(activeClientId, td::td_api::make_object<td::td_api::importContacts>(std::move(vec)));
        }
        if (command.type == CommandType::CreateGroup) {
          if (m_isAccountRestricted) {
            qWarning() << "[TelegramWorker] Blocked CreateGroup because account is restricted";
            emit groupCreationFailed(m_accountRestrictionError.isEmpty() ? QStringLiteral("USER_RESTRICTED") : m_accountRestrictionError);
            continue;
          }
          std::vector<td::td_api::int53> uids;
          for (qint64 uid : command.userIds) {
            if (uid > 0) {
              uids.push_back(uid);
            }
          }
          if (uids.empty()) {
            qWarning() << "[TelegramWorker] Cannot create group: no valid user IDs provided";
            emit errorOccurred(QStringLiteral("Please select at least one contact to create a group."));
            continue;
          }
          const auto reqId = nextRequestId;
          pendingCreateGroupRequests[reqId] = PendingGroupCreation{command.value, command.userIds, false};
          qDebug() << "[TelegramWorker] Sending createNewBasicGroupChat:" << command.value << "with member count:" << uids.size();
          send(activeClientId, td::td_api::make_object<td::td_api::createNewBasicGroupChat>(std::move(uids), command.value.toStdString(), 0));
        }
        if (command.type == CommandType::CreatePrivateChat) {
          const qint64 uid = command.chatId;
          const auto reqId = nextRequestId;
          pendingPrivateChatRequests[reqId] = uid;
          send(activeClientId, td::td_api::make_object<td::td_api::createPrivateChat>(uid, false));
          const auto canSendReqId = nextRequestId;
          pendingCanSendMessageRequests[canSendReqId] = uid;
          send(activeClientId, td::td_api::make_object<td::td_api::canSendMessageToUser>(uid, false));
        }
        if (command.type == CommandType::DeleteContact) {
          const qint64 uid = command.chatId;
          std::vector<td::td_api::int53> uids{uid};
          send(activeClientId, td::td_api::make_object<td::td_api::removeContacts>(std::move(uids)));
          contactUserIds.remove(uid);
          emit contactRemoved(uid);
        }
        if (command.type == CommandType::LoadContacts) {
          send(activeClientId, td::td_api::make_object<td::td_api::getContacts>());
        }
        if (command.type == CommandType::LoadUserProfile) {
          qint64 uid = command.chatId;
          const qint64 cid = command.messageId;
          if (uid == 0 && cid != 0 && chatUserIds.contains(cid)) {
            uid = chatUserIds.value(cid);
          }
          if (uid != 0) {
            send(activeClientId, td::td_api::make_object<td::td_api::getUser>(uid));
            const auto fullReqId = nextRequestId;
            pendingUserFullInfoRequests[fullReqId] = uid;
            send(activeClientId, td::td_api::make_object<td::td_api::getUserFullInfo>(uid));
            const auto photoReqId = nextRequestId;
            pendingProfilePhotoRequests[photoReqId] = uid;
            send(activeClientId, td::td_api::make_object<td::td_api::getUserProfilePhotos>(uid, 0, 20));
          } else if (cid != 0) {
            const auto chatReqId = nextRequestId;
            pendingProfileChatRequests[chatReqId] = true;
            send(activeClientId, td::td_api::make_object<td::td_api::getChat>(cid));
          }
        }
        if (command.type == CommandType::BlockUser) {
          const qint64 uid = command.chatId;
          const bool block = command.flag;
          td::td_api::object_ptr<td::td_api::BlockList> blockList;
          if (block) {
            blockList = td::td_api::make_object<td::td_api::blockListMain>();
          }
          send(activeClientId, td::td_api::make_object<td::td_api::setMessageSenderBlockList>(
            td::td_api::make_object<td::td_api::messageSenderUser>(uid),
            std::move(blockList)
          ));
          emit userBlockedStatusChanged(uid, block);
        }
        if (command.type == CommandType::DeleteChatHistory) {
          const qint64 cid = command.chatId;
          if (command.revoke && chatSupergroupIds.contains(cid)) {
            send(activeClientId, td::td_api::make_object<td::td_api::deleteChat>(cid));
          } else {
            send(activeClientId, td::td_api::make_object<td::td_api::deleteChatHistory>(cid, command.flag, command.revoke));
            if (!command.revoke && chatSupergroupIds.contains(cid)) {
              send(activeClientId, td::td_api::make_object<td::td_api::leaveChat>(cid));
            }
          }
          emit chatDeleted(cid);
        }
        if (command.type == CommandType::DeleteChat) {
          const qint64 cid = command.chatId;
          send(activeClientId, td::td_api::make_object<td::td_api::deleteChat>(cid));
          emit chatDeleted(cid);
        }
        if (command.type == CommandType::LogOut) {
          send(activeClientId, td::td_api::make_object<td::td_api::logOut>());
        }
        if (command.type == CommandType::SearchLocal) {
          const QString query = command.value.trimmed();
          const auto reqId = nextRequestId;
          pendingLocalSearchRequests[reqId] = query;
          send(activeClientId, td::td_api::make_object<td::td_api::searchChats>(query.toStdString(), nullptr, 30));
        }
        if (command.type == CommandType::SearchGlobal) {
          const QString rawQuery = command.value.trimmed();
          QString cleanQuery = rawQuery;
          if (cleanQuery.startsWith(QLatin1Char('@'))) {
            cleanQuery = cleanQuery.mid(1).trimmed();
          }
          if (rawQuery.startsWith(QLatin1Char('@')) && !cleanQuery.isEmpty()) {
            const auto singleReqId = nextRequestId;
            pendingPublicChatRequests[singleReqId] = rawQuery;
            send(activeClientId, td::td_api::make_object<td::td_api::searchPublicChat>(cleanQuery.toStdString()));
          }
          const auto reqId = nextRequestId;
          pendingGlobalSearchRequests[reqId] = rawQuery;
          send(activeClientId, td::td_api::make_object<td::td_api::searchPublicChats>(cleanQuery.toStdString(), nullptr));
        }
        if (command.type == CommandType::AddRecentlyFoundChat) {
          if (command.chatId != 0) {
            send(activeClientId, td::td_api::make_object<td::td_api::addRecentlyFoundChat>(command.chatId));
          }
        }
        if (command.type == CommandType::JoinChat) {
          if (command.chatId != 0) {
            send(activeClientId, td::td_api::make_object<td::td_api::joinChat>(command.chatId));
            send(activeClientId, td::td_api::make_object<td::td_api::getChat>(command.chatId));
          }
        }
        if (command.type == CommandType::LeaveChat) {
          if (command.chatId != 0) {
            send(activeClientId, td::td_api::make_object<td::td_api::leaveChat>(command.chatId));
            send(activeClientId, td::td_api::make_object<td::td_api::getChat>(command.chatId));
          }
        }
        if (command.type == CommandType::ToggleChatMute) {
          if (command.chatId != 0) {
            auto settings = td::td_api::make_object<td::td_api::chatNotificationSettings>();
            settings->use_default_mute_for_ = false;
            settings->mute_for_ = command.flag ? 315360000 : 0;
            send(activeClientId, td::td_api::make_object<td::td_api::setChatNotificationSettings>(command.chatId, std::move(settings)));
          }
        }
        if (command.type == CommandType::SetProfilePhoto) {
          const QString path = command.value.trimmed();
          if (!path.isEmpty()) {
            auto inputFile = td::td_api::make_object<td::td_api::inputFileLocal>(path.toStdString());
            auto chatPhoto = td::td_api::make_object<td::td_api::inputChatPhotoStatic>(std::move(inputFile));
            send(activeClientId, td::td_api::make_object<td::td_api::setProfilePhoto>(std::move(chatPhoto), false));
          }
        }
        if (command.type == CommandType::SetName) {
          send(activeClientId, td::td_api::make_object<td::td_api::setName>(command.value.toStdString(), command.extra.toStdString()));
        }
        if (command.type == CommandType::SetBio) {
          send(activeClientId, td::td_api::make_object<td::td_api::setBio>(command.value.toStdString()));
        }
        if (command.type == CommandType::SetUsername) {
          send(activeClientId, td::td_api::make_object<td::td_api::setUsername>(command.value.toStdString()));
        }
      }
    }

    auto response = manager.receive(0.0);
    if (!response.object) {
      response = manager.receive(0.02);
      if (!response.object) continue;
    }
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

      if (stateId == td::td_api::authorizationStateReady::ID) {
        if (activeClientId != response.client_id) {
          activeClientId = response.client_id;
          emit authorizationStateChanged(QStringLiteral("ready"));
        }
        emit chatsReset();
        emit contactsReset();
        send(activeClientId, td::td_api::make_object<td::td_api::loadChats>(td::td_api::make_object<td::td_api::chatListMain>(), 30));
        myUserIdReqId = nextRequestId;
        send(activeClientId, td::td_api::make_object<td::td_api::getMe>());
      }

      if (stateId == td::td_api::authorizationStateLoggingOut::ID ||
          stateId == td::td_api::authorizationStateClosing::ID ||
          stateId == td::td_api::authorizationStateClosed::ID) {
        m_isAccountRestricted = false;
        m_accountRestrictionError.clear();
        emit accountRestrictedChanged(false, {});
        if (currentOpenedChatId != 0) {
          currentOpenedChatId = 0;
        }
        avatarFileChats.clear();
        messageFiles.clear();
        lastReadOutbox.clear();
        historyRequests.clear();
        users.clear();
        avatarFileUsers.clear();
        contactUserIds.clear();
        userPrivateChats.clear();
        chatHasHistory.clear();
        pendingPrivateChatRequests.clear();
        pendingCreateGroupRequests.clear();
        chatUserIds.clear();
        chatBasicGroupIds.clear();
        chatSupergroupIds.clear();
        basicGroupMemberCount.clear();
        supergroupMemberCount.clear();
        supergroupIsChannel.clear();
        phonePending.clear();

        // Wipe cached login QR and any temporary session images
        const auto qrDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/auth";
        QDir(qrDir).removeRecursively();

        emit chatsReset();
        emit contactsReset();
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
      const bool hasHist = (c->last_message_ != nullptr);
      chatHasHistory[cid] = hasHist;

      if (c->type_) {
        const auto typeId = c->type_->get_id();
        if (typeId == td::td_api::chatTypePrivate::ID) {
          const auto *p = static_cast<const td::td_api::chatTypePrivate *>(c->type_.get());
          chatUserIds[cid] = p->user_id_;
          userPrivateChats[p->user_id_] = cid;
          emit contactChatHistoryChecked(p->user_id_, cid, hasHist);
          if (!users.contains(p->user_id_)) {
            send(activeClientId, td::td_api::make_object<td::td_api::getUser>(p->user_id_));
          } else {
            emit chatUpdated({{"chatId", cid}, {"statusText", users[p->user_id_].statusText}, {"isOnline", users[p->user_id_].isOnline}});
          }
        } else if (typeId == td::td_api::chatTypeSecret::ID) {
          const auto *s = static_cast<const td::td_api::chatTypeSecret *>(c->type_.get());
          chatUserIds[cid] = s->user_id_;
          userPrivateChats[s->user_id_] = cid;
          emit contactChatHistoryChecked(s->user_id_, cid, hasHist);
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
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatLastMessage::ID) {
      auto *u = static_cast<td::td_api::updateChatLastMessage *>(response.object.get());
      const bool hasHist = (u->last_message_ != nullptr);
      chatHasHistory[u->chat_id_] = hasHist;
      if (chatUserIds.contains(u->chat_id_)) {
        emit contactChatHistoryChecked(chatUserIds.value(u->chat_id_), u->chat_id_, hasHist);
      }
      qint64 order = mainChatOrder(u->positions_);
      if (!hasHist) {
        order = 0;
      }
      emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"lastMessage", preview(u->last_message_.get())}, {"time", u->last_message_ ? QDateTime::fromSecsSinceEpoch(u->last_message_->date_).toLocalTime().toString("HH:mm") : QString()}, {"order", order}});
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatDraftMessage::ID) {
      auto *u = static_cast<td::td_api::updateChatDraftMessage *>(response.object.get());
      const qint64 order = mainChatOrder(u->positions_);
      if (order > 0 && chatHasHistory.value(u->chat_id_, false))
        emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"order", order}});
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatPosition::ID) {
      auto *u = static_cast<td::td_api::updateChatPosition *>(response.object.get());
      if (u->position_ && u->position_->list_ && u->position_->list_->get_id() == td::td_api::chatListMain::ID) {
        const qint64 cid = qint64(u->chat_id_);
        const bool hasHist = chatHasHistory.value(cid, false);
        const qint64 order = hasHist ? qint64(u->position_->order_) : 0;
        emit chatUpdated({{"chatId", cid}, {"order", order}});
        if (order == 0) {
          emit chatDeleted(cid);
        }
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatRemovedFromList::ID) {
      auto *u = static_cast<td::td_api::updateChatRemovedFromList *>(response.object.get());
      if (u->chat_list_ && u->chat_list_->get_id() == td::td_api::chatListMain::ID) {
        emit chatDeleted(qint64(u->chat_id_));
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatReadInbox::ID) { auto *u = static_cast<td::td_api::updateChatReadInbox *>(response.object.get()); emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"unreadCount", u->unread_count_}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatReadOutbox::ID) { auto *u = static_cast<td::td_api::updateChatReadOutbox *>(response.object.get()); lastReadOutbox.insert(u->chat_id_, u->last_read_outbox_message_id_); emit chatReadOutboxUpdated(qint64(u->chat_id_), qint64(u->last_read_outbox_message_id_)); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatAction::ID) { auto *u = static_cast<td::td_api::updateChatAction *>(response.object.get()); emit chatTyping(qint64(u->chat_id_), u->action_ && u->action_->get_id() == td::td_api::chatActionTyping::ID); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatPermissions::ID) {
      auto *u = static_cast<td::td_api::updateChatPermissions *>(response.object.get());
      if (u->permissions_) {
        emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"canSendMessages", u->permissions_->can_send_basic_messages_}});
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatNotificationSettings::ID) {
      auto *u = static_cast<td::td_api::updateChatNotificationSettings *>(response.object.get());
      if (u->notification_settings_) {
        emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"isMuted", u->notification_settings_->mute_for_ > 0}});
      }
      continue;
    }
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
        const bool hasHistory = chatHasHistory.value(chatId, false);
        if (hasHistory || !u->message_->is_outgoing_) {
          chatHasHistory[chatId] = true;
          emit chatUpdated({{"chatId", chatId}, {"lastMessage", preview(u->message_.get())}, {"time", QDateTime::fromSecsSinceEpoch(u->message_->date_).toLocalTime().toString("HH:mm")}, {"order", qint64(u->message_->id_)}});
        }

        int fileIdToDownload = 0;
        QVariantMap msgMap = parseMessage(u->message_.get(), fileIdToDownload);
        if (u->message_->sending_state_) {
          if (u->message_->sending_state_->get_id() == td::td_api::messageSendingStateFailed::ID) {
            auto *f = static_cast<const td::td_api::messageSendingStateFailed *>(u->message_->sending_state_.get());
            msgMap["status"] = QStringLiteral("!");
            msgMap["sendError"] = f->error_ ? QString::fromStdString(f->error_->message_) : QStringLiteral("Failed to send message");
          } else if (u->message_->sending_state_->get_id() == td::td_api::messageSendingStatePending::ID) {
            msgMap["status"] = QStringLiteral("🕒");
          }
        } else {
          msgMap["status"] = u->message_->is_outgoing_ ? (read ? QStringLiteral("✓✓") : QStringLiteral("✓")) : QString();
        }

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

        chatHasHistory[chatId] = true;
        if (chatUserIds.contains(chatId)) {
          emit contactChatHistoryChecked(chatUserIds.value(chatId), chatId, true);
        }
        emit messageSendSucceeded(chatId, qint64(u->old_message_id_), msgMap);
        emit chatUpdated({{"chatId", chatId}, {"lastMessage", preview(u->message_.get())}, {"time", QDateTime::fromSecsSinceEpoch(u->message_->date_).toLocalTime().toString("HH:mm")}, {"order", qint64(u->message_->id_)}});
        send(activeClientId, td::td_api::make_object<td::td_api::addChatToList>(chatId, td::td_api::make_object<td::td_api::chatListMain>()));
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateMessageSendFailed::ID) {
      auto *u = static_cast<td::td_api::updateMessageSendFailed *>(response.object.get());
      if (u->message_) {
        const auto chatId = qint64(u->message_->chat_id_);
        const QString errStr = u->error_ ? QString::fromStdString(u->error_->message_) : QStringLiteral("Failed to send message");
        qWarning() << "Message send failed in chat" << chatId << ":" << errStr;

        const bool isRestricted = errStr.contains(QStringLiteral("USER_RESTRICTED")) ||
                                  errStr.contains(QStringLiteral("PEER_FLOOD")) ||
                                  errStr.contains(QStringLiteral("CHAT_WRITE_FORBIDDEN")) ||
                                  errStr.contains(QStringLiteral("USER_PRIVACY_RESTRICTED"));

        if (errStr.contains(QStringLiteral("USER_RESTRICTED")) || errStr.contains(QStringLiteral("PEER_FLOOD"))) {
          m_isAccountRestricted = true;
          m_accountRestrictionError = errStr;
          emit accountRestrictedChanged(true, errStr);
        }

        if (isRestricted || !chatHasHistory.value(chatId, false)) {
          std::vector<td::td_api::int53> ids{u->message_->id_};
          send(activeClientId, td::td_api::make_object<td::td_api::deleteMessages>(chatId, std::move(ids), true));
        }

        if (!chatHasHistory.value(chatId, false)) {
          emit chatUpdated({{"chatId", chatId}, {"lastMessage", QString()}, {"order", 0}});
        }

        int fileIdToDownload = 0;
        QVariantMap msgMap = parseMessage(u->message_.get(), fileIdToDownload);
        msgMap["status"] = QStringLiteral("!");
        msgMap["sendError"] = errStr;

        emit messageSendFailed(chatId, qint64(u->old_message_id_), msgMap, errStr);
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::chats::ID) {
      auto *r = static_cast<td::td_api::chats *>(response.object.get());
      const bool isLocalSearch = pendingLocalSearchRequests.contains(response.request_id);
      const bool isGlobalSearch = pendingGlobalSearchRequests.contains(response.request_id);
      const QString searchQuery = isLocalSearch ? pendingLocalSearchRequests.take(response.request_id)
                                : (isGlobalSearch ? pendingGlobalSearchRequests.take(response.request_id) : QString());

      QVariantList foundList;
      for (const auto id : r->chat_ids_) {
        send(activeClientId, td::td_api::make_object<td::td_api::getChat>(id));
        if (cachedChats.contains(id)) {
          foundList.append(cachedChats.value(id));
        }
      }

      if (isLocalSearch) {
        emit localSearchResults(searchQuery, foundList);
      } else if (isGlobalSearch) {
        emit globalSearchResults(searchQuery, foundList);
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::chat::ID) {
      auto *chat = static_cast<td::td_api::chat *>(response.object.get());
      lastReadOutbox.insert(chat->id_, chat->last_read_outbox_message_id_);
      emit chatReadOutboxUpdated(qint64(chat->id_), qint64(chat->last_read_outbox_message_id_));
      if (chat->photo_ && chat->photo_->small_) {
        const int fileId = chat->photo_->small_->id_;
        avatarFileChats.insert(fileId, chat->id_);
        send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileId, 1, 0, 0, false));
      }
      inspectChat(chat);
      auto cMap = toChatMap(chat);
      cachedChats.insert(chat->id_, cMap);
      emit chatUpdated(cMap);

      if (pendingPublicChatRequests.contains(response.request_id)) {
        const QString q = pendingPublicChatRequests.take(response.request_id);
        emit globalSearchResults(q, QVariantList{cMap});
      }

      if (pendingProfileChatRequests.remove(response.request_id)) {
        if (chatUserIds.contains(chat->id_)) {
          const qint64 uid = chatUserIds.value(chat->id_);
          send(activeClientId, td::td_api::make_object<td::td_api::getUser>(uid));
          const auto fullReqId = nextRequestId;
          pendingUserFullInfoRequests[fullReqId] = uid;
          send(activeClientId, td::td_api::make_object<td::td_api::getUserFullInfo>(uid));
          const auto photoReqId = nextRequestId;
          pendingProfilePhotoRequests[photoReqId] = uid;
          send(activeClientId, td::td_api::make_object<td::td_api::getUserProfilePhotos>(uid, 0, 20));
        }
      }
      continue;
    }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateFile::ID) {
      auto *u = static_cast<td::td_api::updateFile *>(response.object.get());
      if (u->file_ && u->file_->local_ && u->file_->local_->is_downloading_completed_) {
        const int fid = u->file_->id_;
        const QString localPath = QString::fromStdString(u->file_->local_->path_);
        if (avatarFileChats.contains(fid)) {
          emit chatUpdated({{"chatId", avatarFileChats.value(fid)}, {"avatarPath", localPath}});
        }
        if (avatarFileUsers.contains(fid)) {
          const qint64 uid = avatarFileUsers.value(fid);
          users[uid].avatarPath = localPath;
          emit contactAvatarUpdated(uid, localPath);
          if (userFullProfiles.contains(uid)) {
            userFullProfiles[uid]["avatarPath"] = localPath;
            emit userProfileLoaded(uid, userFullProfiles[uid]);
          }
          if (myUserId != 0 && uid == myUserId) {
            emit myUserUpdated(userFullProfiles[uid]);
          }
        }
        if (profilePhotoFiles.contains(fid)) {
          const qint64 uid = profilePhotoFiles.value(fid);
          if (userPhotoGalleries.contains(uid)) {
            QVariantList photos = userPhotoGalleries.value(uid);
            bool updated = false;
            for (int i = 0; i < photos.size(); ++i) {
              QVariantMap pMap = photos[i].toMap();
              if (pMap.value("fileId").toInt() == fid) {
                pMap["filePath"] = localPath;
                photos[i] = pMap;
                updated = true;
                break;
              }
            }
            if (updated) {
              userPhotoGalleries[uid] = photos;
              emit userProfilePhotosLoaded(uid, photos);
            }
          }
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
        if (m->sending_state_) {
          if (m->sending_state_->get_id() == td::td_api::messageSendingStateFailed::ID) {
            auto *f = static_cast<const td::td_api::messageSendingStateFailed *>(m->sending_state_.get());
            msgMap["status"] = QStringLiteral("!");
            msgMap["sendError"] = f->error_ ? QString::fromStdString(f->error_->message_) : QStringLiteral("Failed to send message");
          } else if (m->sending_state_->get_id() == td::td_api::messageSendingStatePending::ID) {
            msgMap["status"] = QStringLiteral("🕒");
          }
        } else {
          msgMap["status"] = m->is_outgoing_ ? (read ? QStringLiteral("✓✓") : QStringLiteral("✓")) : QString();
        }

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
          users[uid].lastSeenSecs = userStatusOrderSecs(u->user_->status_.get(), isOnline);
        }
        if (u->user_->profile_photo_ && u->user_->profile_photo_->small_) {
          const int fileId = u->user_->profile_photo_->small_->id_;
          avatarFileUsers.insert(fileId, uid);
          if (u->user_->profile_photo_->small_->local_ && u->user_->profile_photo_->small_->local_->is_downloading_completed_) {
            users[uid].avatarPath = QString::fromStdString(u->user_->profile_photo_->small_->local_->path_);
          } else {
            send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileId, 1, 0, 0, false));
          }
        }
        for (auto it = chatUserIds.begin(); it != chatUserIds.end(); ++it) {
          if (it.value() == uid) {
            emit chatUpdated({{"chatId", it.key()}, {"statusText", users[uid].statusText}, {"isOnline", users[uid].isOnline}});
          }
        }
        if (u->user_->is_contact_) {
          contactUserIds.insert(uid);
          auto cmap = toUserContactMap(u->user_.get(), users[uid].statusText, users[uid].isOnline, users[uid].lastSeenSecs, users[uid].avatarPath);
          if (userPrivateChats.contains(uid)) {
            const qint64 cid = userPrivateChats.value(uid);
            cmap["chatId"] = cid;
            cmap["hasChatHistory"] = chatHasHistory.value(cid, false);
          }
          userFullProfiles[uid]["userId"] = uid;
          userFullProfiles[uid]["firstName"] = cmap.value("firstName");
          userFullProfiles[uid]["lastName"] = cmap.value("lastName");
          userFullProfiles[uid]["fullName"] = cmap.value("fullName");
          userFullProfiles[uid]["username"] = cmap.value("username");
          userFullProfiles[uid]["phoneNumber"] = cmap.value("phoneNumber");
          userFullProfiles[uid]["statusText"] = cmap.value("statusText");
          userFullProfiles[uid]["isOnline"] = cmap.value("isOnline");
          userFullProfiles[uid]["avatarPath"] = cmap.value("avatarPath");
          userFullProfiles[uid]["initials"] = cmap.value("initials");
          userFullProfiles[uid]["avatarColor"] = cmap.value("avatarColor");
          userFullProfiles[uid]["isContact"] = u->user_->is_contact_;
          emit userProfileLoaded(uid, userFullProfiles[uid]);
          emit contactUpdated(cmap);
        } else if (contactUserIds.contains(uid)) {
          contactUserIds.remove(uid);
          emit contactRemoved(uid);
        } else {
          auto cmap = toUserContactMap(u->user_.get(), users[uid].statusText, users[uid].isOnline, users[uid].lastSeenSecs, users[uid].avatarPath);
          userFullProfiles[uid]["userId"] = uid;
          userFullProfiles[uid]["firstName"] = cmap.value("firstName");
          userFullProfiles[uid]["lastName"] = cmap.value("lastName");
          userFullProfiles[uid]["fullName"] = cmap.value("fullName");
          userFullProfiles[uid]["username"] = cmap.value("username");
          userFullProfiles[uid]["phoneNumber"] = cmap.value("phoneNumber");
          userFullProfiles[uid]["statusText"] = cmap.value("statusText");
          userFullProfiles[uid]["isOnline"] = cmap.value("isOnline");
          userFullProfiles[uid]["avatarPath"] = cmap.value("avatarPath");
          userFullProfiles[uid]["initials"] = cmap.value("initials");
          userFullProfiles[uid]["avatarColor"] = cmap.value("avatarColor");
          userFullProfiles[uid]["isContact"] = u->user_->is_contact_;
          emit userProfileLoaded(uid, userFullProfiles[uid]);
        }
        if (myUserId != 0 && uid == myUserId) {
          emit myUserUpdated(userFullProfiles[uid]);
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::user::ID) {
      auto *u = static_cast<td::td_api::user *>(response.object.get());
      const qint64 uid = u->id_;
      if (response.request_id != 0 && response.request_id == myUserIdReqId) {
        myUserId = uid;
      }
      if (myUserId == uid && u->restriction_info_ && !u->restriction_info_->restriction_reason_.empty()) {
        m_isAccountRestricted = true;
        m_accountRestrictionError = QString::fromStdString(u->restriction_info_->restriction_reason_);
        emit accountRestrictedChanged(true, m_accountRestrictionError);
      }
      const bool isBot = u->type_ && u->type_->get_id() == td::td_api::userTypeBot::ID;
      users[uid].isBot = isBot;
      if (u->status_) {
        bool isOnline = false;
        users[uid].statusText = formatUserStatus(u->status_.get(), isBot, &isOnline);
        users[uid].isOnline = isOnline;
        users[uid].lastSeenSecs = userStatusOrderSecs(u->status_.get(), isOnline);
      }
      if (u->profile_photo_ && u->profile_photo_->small_) {
        const int fileId = u->profile_photo_->small_->id_;
        avatarFileUsers.insert(fileId, uid);
        if (u->profile_photo_->small_->local_ && u->profile_photo_->small_->local_->is_downloading_completed_) {
          users[uid].avatarPath = QString::fromStdString(u->profile_photo_->small_->local_->path_);
        } else {
          send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileId, 1, 0, 0, false));
        }
      }
      for (auto it = chatUserIds.begin(); it != chatUserIds.end(); ++it) {
        if (it.value() == uid) {
          emit chatUpdated({{"chatId", it.key()}, {"statusText", users[uid].statusText}, {"isOnline", users[uid].isOnline}});
        }
      }

      auto cmap = toUserContactMap(u, users[uid].statusText, users[uid].isOnline, users[uid].lastSeenSecs, users[uid].avatarPath);
      if (userPrivateChats.contains(uid)) {
        const qint64 cid = userPrivateChats.value(uid);
        cmap["chatId"] = cid;
        cmap["hasChatHistory"] = chatHasHistory.value(cid, false);
      }
      userFullProfiles[uid]["userId"] = uid;
      userFullProfiles[uid]["firstName"] = cmap.value("firstName");
      userFullProfiles[uid]["lastName"] = cmap.value("lastName");
      userFullProfiles[uid]["fullName"] = cmap.value("fullName");
      userFullProfiles[uid]["username"] = cmap.value("username");
      userFullProfiles[uid]["phoneNumber"] = cmap.value("phoneNumber");
      userFullProfiles[uid]["statusText"] = cmap.value("statusText");
      userFullProfiles[uid]["isOnline"] = cmap.value("isOnline");
      userFullProfiles[uid]["avatarPath"] = cmap.value("avatarPath");
      userFullProfiles[uid]["initials"] = cmap.value("initials");
      userFullProfiles[uid]["avatarColor"] = cmap.value("avatarColor");
      userFullProfiles[uid]["isContact"] = u->is_contact_;
      emit userProfileLoaded(uid, userFullProfiles[uid]);

      if (myUserId != 0 && uid == myUserId) {
        emit myUserUpdated(userFullProfiles[uid]);
      }

      if (u->is_contact_) {
        contactUserIds.insert(uid);
        emit contactUpdated(cmap);
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
        users[uid].lastSeenSecs = userStatusOrderSecs(u->status_.get(), isOnline);
      }
      for (auto it = chatUserIds.begin(); it != chatUserIds.end(); ++it) {
        if (it.value() == uid) {
          emit chatUpdated({{"chatId", it.key()}, {"statusText", users[uid].statusText}, {"isOnline", users[uid].isOnline}});
        }
      }
      if (contactUserIds.contains(uid)) {
        emit contactStatusUpdated(uid, users[uid].statusText, users[uid].isOnline, users[uid].lastSeenSecs);
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateBasicGroup::ID) {
      auto *u = static_cast<td::td_api::updateBasicGroup *>(response.object.get());
      if (u->basic_group_) {
        const qint64 bgId = u->basic_group_->id_;
        const int count = u->basic_group_->member_count_;
        const bool member = isMemberStatus(u->basic_group_->status_.get());
        basicGroupMemberCount[bgId] = count;
        for (auto it = chatBasicGroupIds.begin(); it != chatBasicGroupIds.end(); ++it) {
          if (it.value() == bgId) {
            emit chatUpdated({{"chatId", it.key()}, {"statusText", QStringLiteral("%1 members").arg(count)}, {"isOnline", false}, {"isMember", member}});
          }
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::basicGroup::ID) {
      auto *bg = static_cast<td::td_api::basicGroup *>(response.object.get());
      const qint64 bgId = bg->id_;
      const int count = bg->member_count_;
      const bool member = isMemberStatus(bg->status_.get());
      basicGroupMemberCount[bgId] = count;
      for (auto it = chatBasicGroupIds.begin(); it != chatBasicGroupIds.end(); ++it) {
        if (it.value() == bgId) {
          emit chatUpdated({{"chatId", it.key()}, {"statusText", QStringLiteral("%1 members").arg(count)}, {"isOnline", false}, {"isMember", member}});
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
        const bool member = isMemberStatus(u->supergroup_->status_.get());
        supergroupMemberCount[sgId] = count;
        supergroupIsChannel[sgId] = isChan;
        for (auto it = chatSupergroupIds.begin(); it != chatSupergroupIds.end(); ++it) {
          if (it.value() == sgId) {
            const QString desc = isChan
                ? QStringLiteral("%1 subscribers").arg(count)
                : QStringLiteral("%1 members").arg(count);
            emit chatUpdated({{"chatId", it.key()}, {"statusText", desc}, {"isOnline", false}, {"isMember", member}});
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
      const bool member = isMemberStatus(sg->status_.get());
      supergroupMemberCount[sgId] = count;
      supergroupIsChannel[sgId] = isChan;
      for (auto it = chatSupergroupIds.begin(); it != chatSupergroupIds.end(); ++it) {
        if (it.value() == sgId) {
          const QString desc = isChan
              ? QStringLiteral("%1 subscribers").arg(count)
              : QStringLiteral("%1 members").arg(count);
          emit chatUpdated({{"chatId", it.key()}, {"statusText", desc}, {"isOnline", false}, {"isMember", member}});
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

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateUserFullInfo::ID) {
      auto *u = static_cast<td::td_api::updateUserFullInfo *>(response.object.get());
      const qint64 uid = u->user_id_;
      if (u->user_full_info_) {
        auto *info = u->user_full_info_.get();
        QString bio;
        if (info->bio_) bio = QString::fromStdString(info->bio_->text_);

        QString birthdateStr;
        if (info->birthdate_) {
          const int d = info->birthdate_->day_;
          const int m = info->birthdate_->month_;
          const int y = info->birthdate_->year_;
          if (y > 0) birthdateStr = QStringLiteral("%1/%2/%3").arg(d, 2, 10, QChar('0')).arg(m, 2, 10, QChar('0')).arg(y);
          else birthdateStr = QStringLiteral("%1/%2").arg(d, 2, 10, QChar('0')).arg(m, 2, 10, QChar('0'));
        }

        QString note;
        if (info->note_) note = QString::fromStdString(info->note_->text_);

        const bool isBlocked = (info->block_list_ != nullptr);
        const int groupsInCommon = info->group_in_common_count_;

        userFullProfiles[uid]["userId"] = uid;
        userFullProfiles[uid]["bio"] = bio;
        userFullProfiles[uid]["birthdate"] = birthdateStr;
        userFullProfiles[uid]["note"] = note;
        userFullProfiles[uid]["isBlocked"] = isBlocked;
        userFullProfiles[uid]["groupsInCommon"] = groupsInCommon;
        userFullProfiles[uid]["canBeCalled"] = info->can_be_called_;
        userFullProfiles[uid]["supportsVideoCalls"] = info->supports_video_calls_;

        emit userProfileLoaded(uid, userFullProfiles[uid]);
        emit userBlockedStatusChanged(uid, isBlocked);
        if (myUserId != 0 && uid == myUserId) {
          emit myUserUpdated(userFullProfiles[uid]);
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::userFullInfo::ID) {
      auto *info = static_cast<td::td_api::userFullInfo *>(response.object.get());
      const qint64 uid = pendingUserFullInfoRequests.take(response.request_id);
      if (uid != 0 && info) {
        QString bio;
        if (info->bio_) bio = QString::fromStdString(info->bio_->text_);

        QString birthdateStr;
        if (info->birthdate_) {
          const int d = info->birthdate_->day_;
          const int m = info->birthdate_->month_;
          const int y = info->birthdate_->year_;
          if (y > 0) birthdateStr = QStringLiteral("%1/%2/%3").arg(d, 2, 10, QChar('0')).arg(m, 2, 10, QChar('0')).arg(y);
          else birthdateStr = QStringLiteral("%1/%2").arg(d, 2, 10, QChar('0')).arg(m, 2, 10, QChar('0'));
        }

        QString note;
        if (info->note_) note = QString::fromStdString(info->note_->text_);

        const bool isBlocked = (info->block_list_ != nullptr);
        const int groupsInCommon = info->group_in_common_count_;

        userFullProfiles[uid]["userId"] = uid;
        userFullProfiles[uid]["bio"] = bio;
        userFullProfiles[uid]["birthdate"] = birthdateStr;
        userFullProfiles[uid]["note"] = note;
        userFullProfiles[uid]["isBlocked"] = isBlocked;
        userFullProfiles[uid]["groupsInCommon"] = groupsInCommon;
        userFullProfiles[uid]["canBeCalled"] = info->can_be_called_;
        userFullProfiles[uid]["supportsVideoCalls"] = info->supports_video_calls_;

        emit userProfileLoaded(uid, userFullProfiles[uid]);
        emit userBlockedStatusChanged(uid, isBlocked);
        if (myUserId != 0 && uid == myUserId) {
          emit myUserUpdated(userFullProfiles[uid]);
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::chatPhotos::ID) {
      auto *photosObj = static_cast<td::td_api::chatPhotos *>(response.object.get());
      const qint64 uid = pendingProfilePhotoRequests.take(response.request_id);
      if (uid != 0 && photosObj) {
        QVariantList photoList;
        for (const auto &p : photosObj->photos_) {
          if (!p) continue;
          QVariantMap pMap;
          pMap["id"] = qint64(p->id_);
          pMap["addedDate"] = p->added_date_;
          int bigFileId = 0;
          QString localPath;
          if (!p->sizes_.empty()) {
            auto &biggest = p->sizes_.back();
            if (biggest && biggest->photo_) {
              bigFileId = biggest->photo_->id_;
              pMap["width"] = biggest->width_;
              pMap["height"] = biggest->height_;
              if (biggest->photo_->local_ && biggest->photo_->local_->is_downloading_completed_) {
                localPath = QString::fromStdString(biggest->photo_->local_->path_);
              }
            }
          }
          pMap["fileId"] = bigFileId;
          pMap["filePath"] = localPath;
          if (bigFileId != 0) {
            profilePhotoFiles[bigFileId] = uid;
            if (localPath.isEmpty()) {
              send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(bigFileId, 16, 0, 0, false));
            }
          }
          photoList.append(pMap);
        }
        userPhotoGalleries[uid] = photoList;
        emit userProfilePhotosLoaded(uid, photoList);
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::users::ID) {
      auto *uList = static_cast<td::td_api::users *>(response.object.get());
      for (const auto uid : uList->user_ids_) {
        contactUserIds.insert(uid);
        send(activeClientId, td::td_api::make_object<td::td_api::getUser>(uid));
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::importedContacts::ID) {
      auto *imp = static_cast<td::td_api::importedContacts *>(response.object.get());
      for (const auto uid : imp->user_ids_) {
        contactUserIds.insert(uid);
        send(activeClientId, td::td_api::make_object<td::td_api::getUser>(uid));
      }
      continue;
    }

    if (pendingCreateGroupRequests.contains(response.request_id)) {
      auto pending = pendingCreateGroupRequests.take(response.request_id);

      if (response.object->get_id() == td::td_api::createdBasicGroupChat::ID ||
          response.object->get_id() == td::td_api::chat::ID) {
        qint64 cid = 0;
        if (response.object->get_id() == td::td_api::createdBasicGroupChat::ID) {
          cid = static_cast<td::td_api::createdBasicGroupChat *>(response.object.get())->chat_id_;
        } else {
          cid = static_cast<td::td_api::chat *>(response.object.get())->id_;
          // Supergroup created: try adding selected members
          if (!pending.userIds.isEmpty()) {
            std::vector<td::td_api::int53> memberUids;
            for (qint64 uid : pending.userIds) {
              if (uid > 0) memberUids.push_back(uid);
            }
            if (!memberUids.empty()) {
              send(activeClientId, td::td_api::make_object<td::td_api::addChatMembers>(cid, std::move(memberUids)));
            }
          }
        }

        // Add to main chat list so TDLib maintains position
        send(activeClientId, td::td_api::make_object<td::td_api::addChatToList>(cid, td::td_api::make_object<td::td_api::chatListMain>()));

        // Mark chat open
        send(activeClientId, td::td_api::make_object<td::td_api::openChat>(cid));

        // Request full chat object from TDLib
        send(activeClientId, td::td_api::make_object<td::td_api::getChat>(cid));

        const qint64 order = QDateTime::currentMSecsSinceEpoch() * 1000LL;
        const QString name = pending.title.trimmed().isEmpty() ? QStringLiteral("New Group") : pending.title.trimmed();
        chatHasHistory[cid] = true;
        emit chatUpdated({
            {"chatId", cid},
            {"name", name},
            {"initials", name.left(2).toUpper()},
            {"avatarColor", QStringLiteral("#526C8A")},
            {"order", order},
            {"unreadCount", 0},
            {"lastMessage", QStringLiteral("Group created")},
            {"statusText", QStringLiteral("Group")}
        });

        emit groupChatCreated(cid);
        continue;
      } else if (response.object->get_id() == td::td_api::error::ID) {
        auto *err = static_cast<td::td_api::error *>(response.object.get());
        const QString errStr = QString::fromStdString(err->message_);
        qWarning() << "[TelegramWorker] Group creation error:" << errStr;

        // If basic group creation failed due to member addition restriction, attempt supergroup fallback
        if (!pending.isSupergroupFallback && (errStr == QStringLiteral("USER_RESTRICTED") || errStr.contains(QStringLiteral("PRIVACY")))) {
          qInfo() << "[TelegramWorker] Attempting fallback to createNewSupergroupChat for title:" << pending.title;
          const auto nextReqId = nextRequestId;
          pending.isSupergroupFallback = true;
          pendingCreateGroupRequests[nextReqId] = pending;
          send(activeClientId, td::td_api::make_object<td::td_api::createNewSupergroupChat>(
              pending.title.toStdString(), false, false, "", nullptr, 0, false));
          continue;
        }

        QString friendlyError;
        if (errStr == QStringLiteral("USER_RESTRICTED")) {
          friendlyError = QStringLiteral("Your account is restricted from creating groups. Check @SpamBot on Telegram.");
        } else if (errStr.contains(QStringLiteral("PRIVACY"))) {
          friendlyError = QStringLiteral("Restricted by member privacy settings.");
        } else if (errStr == QStringLiteral("USERS_TOO_FEW")) {
          friendlyError = QStringLiteral("Select at least one contact to create a group.");
        } else {
          friendlyError = QStringLiteral("Failed to create group: %1").arg(errStr);
        }

        if (errStr == QStringLiteral("USER_RESTRICTED") || errStr == QStringLiteral("PEER_FLOOD")) {
          m_isAccountRestricted = true;
          m_accountRestrictionError = errStr;
          emit accountRestrictedChanged(true, errStr);
        }

        emit groupCreationFailed(friendlyError);
        emit errorOccurred(friendlyError);
        continue;
      }
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::createdBasicGroupChat::ID) {
      auto *cbg = static_cast<td::td_api::createdBasicGroupChat *>(response.object.get());
      const qint64 cid = qint64(cbg->chat_id_);
      chatHasHistory[cid] = true;
      send(activeClientId, td::td_api::make_object<td::td_api::addChatToList>(cid, td::td_api::make_object<td::td_api::chatListMain>()));
      send(activeClientId, td::td_api::make_object<td::td_api::openChat>(cid));
      send(activeClientId, td::td_api::make_object<td::td_api::getChat>(cid));
      emit groupChatCreated(cid);
      continue;
    }

    if (pendingPrivateChatRequests.contains(response.request_id)) {
      const qint64 uid = pendingPrivateChatRequests.take(response.request_id);
      if (response.object->get_id() == td::td_api::chat::ID) {
        auto *c = static_cast<td::td_api::chat *>(response.object.get());
        const qint64 cid = c->id_;
        userPrivateChats[uid] = cid;
        chatUserIds[cid] = uid;
        const bool hasHist = (c->last_message_ != nullptr);
        chatHasHistory[cid] = hasHist;
        inspectChat(c);
        send(activeClientId, td::td_api::make_object<td::td_api::openChat>(cid));
        if (hasHist) {
          emit chatUpdated(toChatMap(c));
          send(activeClientId, td::td_api::make_object<td::td_api::addChatToList>(cid, td::td_api::make_object<td::td_api::chatListMain>()));
        } else {
          auto cMap = toChatMap(c);
          cMap["order"] = 0;
          emit chatUpdated(cMap);
        }
        emit contactChatHistoryChecked(uid, cid, hasHist);
        emit privateChatCreated(uid, cid);
      } else if (response.object->get_id() == td::td_api::error::ID) {
        auto *err = static_cast<td::td_api::error *>(response.object.get());
        const QString errStr = QString::fromStdString(err->message_);
        if (errStr == QStringLiteral("USER_RESTRICTED") || errStr == QStringLiteral("PEER_FLOOD")) {
          m_isAccountRestricted = true;
          m_accountRestrictionError = errStr;
          emit accountRestrictedChanged(true, errStr);
        }
        emit errorOccurred(errStr);
      }
      continue;
    }

    if (pendingCanSendMessageRequests.contains(response.request_id)) {
      const qint64 uid = pendingCanSendMessageRequests.take(response.request_id);
      if (response.object->get_id() == td::td_api::canSendMessageToUserResultUserRestrictsNewChats::ID ||
          response.object->get_id() == td::td_api::canSendMessageToUserResultUserIsDeleted::ID) {
        const qint64 cid = userPrivateChats.value(uid, 0);
        if (cid != 0) {
          emit chatUpdated({{"chatId", cid}, {"canSendMessages", false}});
        }
      }
      continue;
    }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::error::ID) {
      auto *error = static_cast<td::td_api::error *>(response.object.get());
      const QString errStr = QString::fromStdString(error->message_);
      if (errStr == QStringLiteral("USER_RESTRICTED") || errStr == QStringLiteral("PEER_FLOOD")) {
        m_isAccountRestricted = true;
        m_accountRestrictionError = errStr;
        emit accountRestrictedChanged(true, errStr);
      }
      emit errorOccurred(errStr);
    } else if (response.request_id != 0 && response.object->get_id() == td::td_api::optionValueString::ID) {
      auto *result = static_cast<td::td_api::optionValueString *>(response.object.get());
      if (response.client_id == activeClientId) emit versionReceived(QString::fromStdString(result->value_));
    }
  }
}
