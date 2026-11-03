#include "telegram_client.h"

TelegramClient::TelegramClient(QObject *parent) : QObject(parent), m_worker(this) {
  connect(&m_worker, &TelegramWorker::versionReceived, this, &TelegramClient::versionReceived);
  connect(&m_worker, &TelegramWorker::authorizationStateChanged, this, [this](const QString &state) {
    if (m_authorizationState != state) {
      m_authorizationState = state;
      emit authorizationStateChanged();
    }
    emit authorizationStateUpdated(state);
  });
  connect(&m_worker, &TelegramWorker::errorOccurred, this, &TelegramClient::errorOccurred);
}

QString TelegramClient::authorizationState() const { return m_authorizationState; }

void TelegramClient::start() {
  if (!m_worker.isRunning()) m_worker.start();
}

void TelegramClient::submitPhoneNumber(const QString &phoneNumber) {
  if (!phoneNumber.trimmed().isEmpty()) m_worker.submitPhoneNumber(phoneNumber.trimmed());
}

void TelegramClient::submitCode(const QString &code) {
  if (!code.trimmed().isEmpty()) m_worker.submitCode(code.trimmed());
}
