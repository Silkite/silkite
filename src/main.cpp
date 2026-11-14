#include <QDebug>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include "app_controller.h"
#include "models/chat_list_model.h"
#include "models/chat_organization_manager.h"
#include "models/contact_list_model.h"
#include "models/global_search_model.h"
#include "theme/theme_manager.h"
#include "telegram/telegram_client.h"
#include "notifications/notification_portal_manager.h"
#include "notifications/notification_service.h"

int main(int argc, char *argv[]) {
  QQuickWindow::setDefaultAlphaBuffer(true);

  QGuiApplication app(argc, argv);

  app.setApplicationName("Silkite");
  app.setOrganizationName("Silkite");

  AppController appController;
  ThemeManager themeManager;

  ChatOrganizationManager chatOrganizationManager;
  ChatListModel chatListModel;
  chatListModel.setOrganizationManager(&chatOrganizationManager);

  ContactListModel contactListModel;
  GlobalSearchModel globalSearchModel;

  TelegramClient telegramClient;

  // listen tdlib
  QObject::connect(
      &telegramClient, &TelegramClient::versionReceived,
      [](const QString &version) { qInfo() << "TDLib version:" << version; });

  QObject::connect(
      &telegramClient, &TelegramClient::errorOccurred,
      [](const QString &error) { qWarning() << "TDLib error: " << error; });
  QObject::connect(&telegramClient, &TelegramClient::chatsReset, &chatListModel, &ChatListModel::clearChats);
  QObject::connect(&telegramClient, &TelegramClient::chatUpdated, &chatListModel, &ChatListModel::upsertChat);
  QObject::connect(&telegramClient, &TelegramClient::chatDeleted, &chatListModel, &ChatListModel::removeChat);
  QObject::connect(&telegramClient, &TelegramClient::chatDeleted, &chatOrganizationManager, &ChatOrganizationManager::removeChatFromAllFolders);

  // Connect contacts signals
  QObject::connect(&telegramClient, &TelegramClient::contactsReset, &contactListModel, &ContactListModel::clearContacts);
  QObject::connect(&telegramClient, &TelegramClient::contactUpdated, &contactListModel, &ContactListModel::upsertContact);
  QObject::connect(&telegramClient, &TelegramClient::contactStatusUpdated, &contactListModel, &ContactListModel::updateContactStatus);
  QObject::connect(&telegramClient, &TelegramClient::contactAvatarUpdated, &contactListModel, &ContactListModel::updateContactAvatar);
  QObject::connect(&telegramClient, &TelegramClient::contactChatHistoryChecked, &contactListModel, &ContactListModel::setContactHasChatHistory);
  QObject::connect(&telegramClient, &TelegramClient::contactRemoved, &contactListModel, &ContactListModel::removeContact);

  // Connect global search signals
  QObject::connect(&telegramClient, &TelegramClient::localSearchResults, &globalSearchModel, &GlobalSearchModel::setLocalResults);
  QObject::connect(&telegramClient, &TelegramClient::globalSearchResults, &globalSearchModel, &GlobalSearchModel::setGlobalResults);

  // Notification management (Qt D-Bus via XDG portal)
  NotificationPortalManager portalManager;
  NotificationService notificationService(&portalManager, &chatListModel, &telegramClient);
  QObject::connect(&telegramClient, &TelegramClient::messageReceived,
                   &notificationService, &NotificationService::onIncomingMessage);

  QQmlApplicationEngine engine;

  engine.rootContext()->setContextProperty("appController", &appController);
  engine.rootContext()->setContextProperty("Theme", &themeManager);
  engine.rootContext()->setContextProperty("chatOrganizationManager", &chatOrganizationManager);
  engine.rootContext()->setContextProperty("chatListModel", &chatListModel);
  engine.rootContext()->setContextProperty("contactListModel", &contactListModel);
  engine.rootContext()->setContextProperty("globalSearchModel", &globalSearchModel);
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
