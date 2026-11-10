#include <QCoreApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QDebug>

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QQmlEngine engine;
    QQmlComponent component(&engine);
    component.setData("import QtQuick\nimport QtCore\nItem { Settings { id: s; property string split: \"none\" } }", QUrl());
    if (component.isError()) {
        qDebug() << component.errors();
        return 1;
    }
    qDebug() << "Settings is supported!";
    return 0;
}
