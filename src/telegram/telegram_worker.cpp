#include "telegram_worker.h"

#include <QDir>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QSysInfo>
#include <QDateTime>
#include <QHash>

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
  if (message->content_->get_id() == td::td_api::messageText::ID)
    return QString::fromStdString(static_cast<const td::td_api::messageText *>(message->content_.get())->text_->text_);
  return QStringLiteral("Attachment");
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
void TelegramWorker::selectPhoneLogin() { enqueue({CommandType::SelectPhone, {}}); }
void TelegramWorker::selectQrLogin() { enqueue({CommandType::SelectQr, {}}); }
void TelegramWorker::loadConversation(qint64 chatId, qint64 fromMessageId, int limit) { enqueue({CommandType::History, QString::number(chatId) + ":" + QString::number(fromMessageId) + ":" + QString::number(limit)}); }

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
  QHash<int, qint64> avatarFileChats;
  QHash<qint64, qint64> lastReadOutbox;
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
          if (p.size() == 3) send(activeClientId, td::td_api::make_object<td::td_api::getChatHistory>(p[0].toLongLong(), p[1].toLongLong(), 0, p[2].toInt(), false));
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

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateNewChat::ID) { auto *chat = static_cast<td::td_api::updateNewChat *>(response.object.get())->chat_.get(); if (chat && chat->photo_ && chat->photo_->small_) { const int fileId = chat->photo_->small_->id_; avatarFileChats.insert(fileId, chat->id_); send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileId, 1, 0, 0, false)); } emit chatUpdated(toChatMap(chat)); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatTitle::ID) { auto *u = static_cast<td::td_api::updateChatTitle *>(response.object.get()); emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"name", QString::fromStdString(u->title_)}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateUnreadMessageCount::ID) { auto *u = static_cast<td::td_api::updateUnreadMessageCount *>(response.object.get()); Q_UNUSED(u); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatLastMessage::ID) { auto *u = static_cast<td::td_api::updateChatLastMessage *>(response.object.get()); emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"lastMessage", preview(u->last_message_.get())}, {"time", QDateTime::fromSecsSinceEpoch(u->last_message_->date_).toLocalTime().toString("HH:mm")}, {"order", mainChatOrder(u->positions_)}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatPosition::ID) { auto *u = static_cast<td::td_api::updateChatPosition *>(response.object.get()); if (u->position_ && u->position_->list_ && u->position_->list_->get_id() == td::td_api::chatListMain::ID) emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"order", qint64(u->position_->order_)}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatReadInbox::ID) { auto *u = static_cast<td::td_api::updateChatReadInbox *>(response.object.get()); emit chatUpdated({{"chatId", qint64(u->chat_id_)}, {"unreadCount", u->unread_count_}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateChatReadOutbox::ID) { auto *u = static_cast<td::td_api::updateChatReadOutbox *>(response.object.get()); lastReadOutbox.insert(u->chat_id_, u->last_read_outbox_message_id_); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateNewMessage::ID) { auto *u = static_cast<td::td_api::updateNewMessage *>(response.object.get()); if (u->message_) { const auto chatId = qint64(u->message_->chat_id_); emit chatUpdated({{"chatId", chatId}, {"lastMessage", preview(u->message_.get())}, {"time", QDateTime::fromSecsSinceEpoch(u->message_->date_).toLocalTime().toString("HH:mm")}, {"order", qint64(u->message_->id_)}}); emit messageReceived(chatId, {{"messageId", qint64(u->message_->id_)}, {"text", preview(u->message_.get())}, {"time", QDateTime::fromSecsSinceEpoch(u->message_->date_).toLocalTime().toString("HH:mm")}, {"outgoing", u->message_->is_outgoing_}, {"status", u->message_->is_outgoing_ ? QStringLiteral("✓") : QString()}}); } continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::chats::ID) { auto *r = static_cast<td::td_api::chats *>(response.object.get()); for (const auto id : r->chat_ids_) send(activeClientId, td::td_api::make_object<td::td_api::getChat>(id)); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::chat::ID) { auto *chat = static_cast<td::td_api::chat *>(response.object.get()); lastReadOutbox.insert(chat->id_, chat->last_read_outbox_message_id_); if (chat->photo_ && chat->photo_->small_) { const int fileId = chat->photo_->small_->id_; avatarFileChats.insert(fileId, chat->id_); send(activeClientId, td::td_api::make_object<td::td_api::downloadFile>(fileId, 1, 0, 0, false)); } emit chatUpdated(toChatMap(chat)); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::updateFile::ID) { auto *u = static_cast<td::td_api::updateFile *>(response.object.get()); if (u->file_ && u->file_->local_ && u->file_->local_->is_downloading_completed_ && avatarFileChats.contains(u->file_->id_)) emit chatUpdated({{"chatId", avatarFileChats.value(u->file_->id_)}, {"avatarPath", QString::fromStdString(u->file_->local_->path_)}}); continue; }
    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::messages::ID) { auto *r = static_cast<td::td_api::messages *>(response.object.get()); QVariantList list; qint64 chatId = 0; std::vector<td::td_api::int53> ids; for (const auto &m : r->messages_) { chatId = m->chat_id_; ids.push_back(m->id_); list.append(QVariantMap{{"messageId", qint64(m->id_)}, {"text", preview(m.get())}, {"time", QDateTime::fromSecsSinceEpoch(m->date_).toLocalTime().toString("HH:mm")}, {"outgoing", m->is_outgoing_}, {"status", m->is_outgoing_ ? QStringLiteral("✓") : QString()}}); } if (chatId && !ids.empty()) send(activeClientId, td::td_api::make_object<td::td_api::viewMessages>(chatId, std::move(ids), td::td_api::make_object<td::td_api::messageSourceChatHistory>(), true)); emit messagesLoaded(chatId, list, r->messages_.size() >= 50); continue; }

    if (response.client_id == activeClientId && response.object->get_id() == td::td_api::error::ID) {
      auto *error = static_cast<td::td_api::error *>(response.object.get());
      emit errorOccurred(QString::fromStdString(error->message_));
    } else if (response.request_id != 0 && response.object->get_id() == td::td_api::optionValueString::ID) {
      auto *result = static_cast<td::td_api::optionValueString *>(response.object.get());
      if (response.client_id == activeClientId) emit versionReceived(QString::fromStdString(result->value_));
    }
  }
}
