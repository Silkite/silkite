#include "telegram_client.h"
#include "src/telegram/telegram_worker.h"

TelegramClient::TelegramClient(QObject *parent) : QObject(parent) {
  connect(&m_worker, &TelegramWorker::versionReceived, this,
          &TelegramClient::versionReceived);

  connect(&m_worker, &TelegramWorker::errorOccurred, this,
          &TelegramClient::errorOccured);
}

TelegramClient::~TelegramClient() {
  if (m_worker.isRunning()) {
    m_worker.requestInterruption();
    m_worker.wait();
  }
}

void TelegramClient::start() {
  if (!m_worker.isRunning()) {
    m_worker.start();
  }
}
