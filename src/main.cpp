#include <QDebug>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>

#include "app_controller.h"
#include "models/chat_list_model.h"
#include "telegram/telegram_client.h"

int main(int argc, char *argv[]) {
  QQuickWindow::setDefaultAlphaBuffer(true);

  QGuiApplication app(argc, argv);

  app.setApplicationName("Silkite");
  app.setOrganizationName("Silkite");

  AppController appController;

  ChatListModel chatListModel;

  TelegramClient telegramClient;

  // listen tdlib
  QObject::connect(
      &telegramClient, &TelegramClient::versionReceived,
      [](const QString &version) { qInfo() << "TDLib version:" << version; });

  QObject::connect(
      &telegramClient, &TelegramClient::errorOccurred,
      [](const QString &error) { qWarning() << "TDLib error: " << error; });

  QQmlApplicationEngine engine;

  engine.rootContext()->setContextProperty("appController", &appController);
  engine.rootContext()->setContextProperty("chatListModel", &chatListModel);
  engine.rootContext()->setContextProperty("telegramClient", &telegramClient);

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.loadFromModule("Silkite", "Main");

  if (engine.rootObjects().isEmpty()) {
    return -1;
  }

  telegramClient.start();

  return app.exec();
}
