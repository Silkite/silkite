#include "app_controller.h"

#include <QGuiApplication>
#include <QClipboard>
#include <QMimeData>
#include <QImage>
#include <QUrl>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>

AppController::AppController(QObject *parent)
    : QObject(parent), m_appName("Silkite"), m_appVersion("0.1.0"),
      m_lastMessage("No messages received yet") {}

QString AppController::appName() const { return m_appName; }
QString AppController::appVersion() const { return m_appVersion; }
QString AppController::lastMessage() const { return m_lastMessage; }

void AppController::simulateIncomingMessage() {
  ++m_messageCount;
  m_lastMessage =
      "Hello from Silkite! Message " + QString::number(m_messageCount);

  emit lastMessageChanged();
  emit messageReceived(m_lastMessage);
}

void AppController::copyText(const QString &text) {
  if (auto *cb = QGuiApplication::clipboard()) {
    cb->setText(text);
  }
}

void AppController::copyImage(const QString &filePath) {
  if (filePath.isEmpty()) return;
  QImage img(filePath);
  if (!img.isNull()) {
    if (auto *cb = QGuiApplication::clipboard()) {
      cb->setImage(img);
    }
  }
}

bool AppController::clipboardHasImage() const {
  if (auto *cb = QGuiApplication::clipboard()) {
    const QMimeData *mime = cb->mimeData();
    return mime && mime->hasImage();
  }
  return false;
}

bool AppController::clipboardHasFiles() const {
  if (auto *cb = QGuiApplication::clipboard()) {
    const QMimeData *mime = cb->mimeData();
    if (mime && mime->hasUrls()) {
      for (const auto &url : mime->urls()) {
        if (url.isLocalFile() && QFileInfo::exists(url.toLocalFile())) {
          return true;
        }
      }
    }
  }
  return false;
}

QString AppController::getClipboardFilePath() {
  auto *cb = QGuiApplication::clipboard();
  if (!cb) return {};
  const QMimeData *mime = cb->mimeData();
  if (!mime) return {};

  // 1. Check if files/URLs are copied
  if (mime->hasUrls()) {
    for (const auto &url : mime->urls()) {
      if (url.isLocalFile()) {
        const QString local = url.toLocalFile();
        if (QFileInfo::exists(local)) {
          return local;
        }
      }
    }
  }

  // 2. Check if raw image data is copied (e.g. screenshot, web image)
  if (mime->hasImage()) {
    QImage img = qvariant_cast<QImage>(mime->imageData());
    if (!img.isNull()) {
      const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/clipboard";
      QDir().mkpath(cacheDir);
      const QString filePath = cacheDir + "/paste_" + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".png";
      if (img.save(filePath, "PNG")) {
        return filePath;
      }
    }
  }

  return {};
}
