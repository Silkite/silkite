#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>

#include "app_controller.h"

int main(int argc, char *argv[]) {
  QQuickWindow::setDefaultAlphaBuffer(true);

  QGuiApplication app(argc, argv);

  app.setApplicationName("Silkite");
  app.setOrganizationName("Silkite");

  AppController appController;

  QQmlApplicationEngine engine;

  engine.rootContext()->setContextProperty("appController", &appController);

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.loadFromModule("Silkite", "Main");

  return app.exec();
}
