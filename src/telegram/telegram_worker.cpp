#include "telegram_worker.h"

#include <QDir>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QSysInfo>

#include <cstdlib>
#include <string>

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
  case td::td_api::authorizationStateWaitTdlibParameters::ID:
    return "waitTdlibParameters";
  case td::td_api::authorizationStateWaitPhoneNumber::ID:
    return "waitPhoneNumber";
  case td::td_api::authorizationStateWaitCode::ID:
    return "waitCode";
  case td::td_api::authorizationStateWaitPassword::ID:
    return "waitPassword";
  case td::td_api::authorizationStateReady::ID:
    return "ready";
  case td::td_api::authorizationStateLoggingOut::ID:
    return "loggingOut";
  case td::td_api::authorizationStateClosing::ID:
    return "closing";
  case td::td_api::authorizationStateClosed::ID:
    return "closed";
  default:
    return "authorizing";
  }
}
} // namespace

TelegramWorker::TelegramWorker(QObject *parent) : QThread(parent) {}

TelegramWorker::~TelegramWorker() {
  requestInterruption();
  if (isRunning())
    wait();
}

void TelegramWorker::submitPhoneNumber(const QString &phoneNumber) {
  enqueue({CommandType::PhoneNumber, phoneNumber});
}

void TelegramWorker::submitCode(const QString &code) {
  enqueue({CommandType::Code, code});
}

void TelegramWorker::submitQrLogin() {
  enqueue({CommandType::QrLogin, {}});
}

void TelegramWorker::enqueue(Command command) {
  QMutexLocker locker(&m_mutex);
  m_commands.enqueue(std::move(command));
}

void TelegramWorker::run() {
  td::ClientManager manager;
  const auto clientId = manager.create_client_id();
  td::ClientManager::RequestId nextRequestId = 1;
  const auto apiIdText = envValue("SILKITE_API_ID");
  const auto apiHash = envValue("SILKITE_API_HASH");
  bool parametersSent = false;
  bool qrLoginPending = false;

  auto send = [&](td::td_api::object_ptr<td::td_api::Function> request) {
    manager.send(clientId, nextRequestId++, std::move(request));
  };

  // Start the TDLib client and obtain its version. This first request causes
  // TDLib to emit updateAuthorizationState and begin initialization.
  send(td::td_api::make_object<td::td_api::getOption>("version"));

  while (!isInterruptionRequested()) {
    {
      QMutexLocker locker(&m_mutex);
      while (!m_commands.isEmpty()) {
        const auto command = m_commands.dequeue();
        if (command.type == CommandType::PhoneNumber) {
          send(
              td::td_api::make_object<td::td_api::setAuthenticationPhoneNumber>(
                  command.value.toStdString(),
                  td::td_api::make_object<
                      td::td_api::phoneNumberAuthenticationSettings>()));
        }
        if (command.type == CommandType::Code) {
          send(td::td_api::make_object<td::td_api::checkAuthenticationCode>(
              command.value.toStdString()));
        }

        if (command.type == CommandType::QrLogin) {
          // TDLib accepts this request only after it has emitted
          // authorizationStateWaitPhoneNumber.
          qrLoginPending = true;
        }
      }
    }

    auto response = manager.receive(0.2);
    if (!response.object)
      continue;

    if (response.object->get_id() == td::td_api::updateAuthorizationState::ID) {
      auto *update = static_cast<td::td_api::updateAuthorizationState *>(
          response.object.get());
      emit authorizationStateChanged(stateName(*update->authorization_state_));
      if (update->authorization_state_->get_id() ==
              td::td_api::authorizationStateWaitTdlibParameters::ID &&
          !parametersSent) {
        if (apiIdText.empty() || apiHash.empty()) {
          emit errorOccurred(
              QStringLiteral("Set SILKITE_API_ID and SILKITE_API_HASH before "
                             "starting Silkite."));
          continue;
        }
        bool ok = false;
        const int apiId = QString::fromStdString(apiIdText).toInt(&ok);
        if (!ok || apiId <= 0) {
          emit errorOccurred(
              QStringLiteral("SILKITE_API_ID must be a positive integer."));
          continue;
        }
        const auto dataDir =
            QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) +
            "/tdlib";
        QDir().mkpath(dataDir);
        const auto filesDir = dataDir + "/files";
        QDir().mkpath(filesDir);
        const auto key = envValue("SILKITE_DATABASE_KEY");
        send(td::td_api::make_object<td::td_api::setTdlibParameters>(
            false, dataDir.toStdString(), filesDir.toStdString(), key, true,
            true, true, true, apiId, apiHash, "en", "Silkite",
            QSysInfo::prettyProductName().toStdString(), "0.1.0"));
        parametersSent = true;
      }

      if (update->authorization_state_->get_id() ==
              td::td_api::authorizationStateWaitPhoneNumber::ID &&
          qrLoginPending) {
        send(td::td_api::make_object<td::td_api::requestQrCodeAuthentication>(
            std::vector<td::td_api::int53>{}));
        qrLoginPending = false;
      }

      if (update->authorization_state_->get_id() ==
          td::td_api::authorizationStateWaitOtherDeviceConfirmation::ID) {
        auto *qrState = static_cast<
            td::td_api::authorizationStateWaitOtherDeviceConfirmation *>(
            update->authorization_state_.get());

        emit qrCodeLinkChanged(QString::fromStdString(qrState->link_));
      }
      continue;
    }

    if (response.object->get_id() == td::td_api::error::ID) {
      auto *error = static_cast<td::td_api::error *>(response.object.get());
      emit errorOccurred(QString::fromStdString(error->message_));
    } else if (response.request_id != 0 &&
               response.object->get_id() == td::td_api::optionValueString::ID) {
      auto *result =
          static_cast<td::td_api::optionValueString *>(response.object.get());
      emit versionReceived(QString::fromStdString(result->value_));
    }
  }
}
