#pragma once

#include <QObject>
#include <QString>
#include <qtmetamacros.h>

class AppController : public QObject {
  Q_OBJECT

  Q_PROPERTY(QString appName READ appName CONSTANT)

  Q_PROPERTY(QString appVersion READ appVersion CONSTANT)

  Q_PROPERTY(QString lastMessage READ lastMessage NOTIFY lastMessageChanged)

public:
  explicit AppController(QObject *parent = nullptr);

  QString appName() const;
  QString appVersion() const;
  QString lastMessage() const;

  Q_INVOKABLE void simulateIncomingMessage();

  // Clipboard operations
  Q_INVOKABLE void copyText(const QString &text);
  Q_INVOKABLE void copyImage(const QString &filePath);
  Q_INVOKABLE bool clipboardHasImage() const;
  Q_INVOKABLE bool clipboardHasFiles() const;
  Q_INVOKABLE QString getClipboardFilePath();
  Q_INVOKABLE void clearClipboardCache();

signals:
  void lastMessageChanged();
  void messageReceived(const QString &message);

private:
  QString m_appName;
  QString m_appVersion;
  QString m_lastMessage;

  int m_messageCount = 0;
};
