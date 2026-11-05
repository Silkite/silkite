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
  connect(&m_worker, &TelegramWorker::chatUpdated, this, &TelegramClient::chatUpdated);
  connect(&m_worker, &TelegramWorker::chatsReset, this, &TelegramClient::chatsReset);
  connect(&m_worker, &TelegramWorker::messagesLoaded, this, [this](qint64, const QVariantList &messages, bool) { m_conversationMessages = messages; emit conversationMessagesChanged(); });
  connect(&m_worker, &TelegramWorker::messageReceived, this, [this](qint64 chatId, const QVariantMap &message) { if (chatId != m_activeChatId) return; m_conversationMessages.append(message); emit conversationMessagesChanged(); });
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
void TelegramClient::loadConversation(qint64 chatId, qint64 fromMessageId) { m_activeChatId = chatId; m_conversationMessages.clear(); emit conversationMessagesChanged(); m_worker.loadConversation(chatId, fromMessageId); }
QVariantList TelegramClient::conversationMessages() const { return m_conversationMessages; }
