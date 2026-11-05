import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property string currentPage: "chats"
  property bool chatListExpanded: true

  signal navigationRequested(string page)
  signal chatListToggleRequested()

  color: Theme.elevatedBackground

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 8

    Image {
      Layout.preferredWidth: 28
      Layout.preferredHeight: 28
      source: "qrc:/qt/qml/Silkite/assets/logo-transparent.png"
      fillMode: Image.PreserveAspectFit
      smooth: true
    }

    Rectangle {
      Layout.preferredWidth: 1
      Layout.fillHeight: true
      color: Theme.divider
    }

    ToolButton {
      icon.source: "qrc:/qt/qml/Silkite/assets/icons/chat.svg"
      icon.width: 22
      icon.height: 22
      focusPolicy: Qt.NoFocus
      implicitWidth: 40
      implicitHeight: 40

      background: Rectangle {
        radius: width / 2
        color: root.currentPage === "chats" || parent.hovered ? Theme.accent : "transparent"
      }
      onClicked: root.navigationRequested("chats")
    }
    ToolButton {
      icon.source: "qrc:/qt/qml/Silkite/assets/icons/people.svg"
      icon.width: 22
      icon.height: 22
      focusPolicy: Qt.NoFocus
      implicitWidth: 40
      implicitHeight: 40
      background: Rectangle {
        radius: width / 2
        color: root.currentPage === "contacts" || parent.hovered ? Theme.accent : "transparent"
      }
      onClicked: root.navigationRequested("contacts")
    }
    ToolButton {
      icon.source: "qrc:/qt/qml/Silkite/assets/icons/call.svg"
      icon.width: 22
      icon.height: 22
      focusPolicy: Qt.NoFocus
      implicitWidth: 40
      implicitHeight: 40
      background: Rectangle {
        radius: width / 2
        color: root.currentPage === "calls" || parent.hovered ? Theme.accent : "transparent"
      }
      onClicked: root.navigationRequested("calls")
    }
    Item {
      Layout.fillWidth: true
    }
    ToolButton {
      icon.source: "qrc:/qt/qml/Silkite/assets/icons/settings.svg"
      icon.width: 22
      icon.height: 22
      focusPolicy: Qt.NoFocus
      implicitWidth: 40
      implicitHeight: 40
      background: Rectangle {
        radius: width / 2
        color: root.currentPage === "settings" || parent.hovered ? Theme.accent : "transparent"
      }
      onClicked: root.navigationRequested("settings")
    }

    ToolButton {
      icon.source: "qrc:/qt/qml/Silkite/assets/icons/panel-left.svg"
      icon.width: 22
      icon.height: 22
      focusPolicy: Qt.NoFocus
      implicitWidth: 40
      implicitHeight: 40
      ToolTip.visible: hovered
      ToolTip.text: root.chatListExpanded ? "Hide chats" : "Show chats"
      background: Rectangle {
        radius: width / 2
        color: parent.hovered ? Theme.accent : "transparent"
      }
      onClicked: root.chatListToggleRequested()
    }


  }
}
