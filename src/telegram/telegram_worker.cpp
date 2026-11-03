#include "telegram_worker.h"
#include "td/telegram/td_api.h"

#include <qobject.h>

#include <td/telegram/Client.h>
#include <td/telegram/td_api.hpp>

#include <QString>

TelegramWorker::TelegramWorker(QObject *parent) : QThread(parent) {}

void TelegramWorker::run() {
  td::ClientManager manager;

  const auto clientId = manager.create_client_id();

  constexpr td::ClientManager::RequestId requestId = 1;

  // this method is used so that response doesn't block the GUI thread
  manager.send(clientId, requestId,
               td::td_api::make_object<td::td_api::getOption>("version"));

  while (!isInterruptionRequested()) {
    auto response = manager.receive(1.0);

    if (!response.object) {
      continue;
    }

    if (response.request_id != requestId) {
      continue;
    }

    if (response.object->get_id() == td::td_api::optionValueString::ID) {
      auto *result =
          static_cast<td::td_api::optionValueString *>(response.object.get());

      emit versionReceived(QString::fromStdString(result->value_));

      return;
    }

    if (response.object->get_id() == td::td_api::error::ID) {
      auto *error = static_cast<td::td_api::error *>(response.object.get());

      emit errorOccurred(QString::fromStdString(error->message_));

      return;
    }

    emit errorOccurred(QStringLiteral("Unexpected response fropm TDlib lol"));

    return;
  }
}
