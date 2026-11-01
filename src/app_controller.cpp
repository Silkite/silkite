#include "app_controller.h"

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
