import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property string currentPage: "chats"

  signal navigationRequested(string page)

  color: Theme.elevatedBackground

  ColumnLayout {
    anchors.fill: parent
    anchors.topMargin: 18
    anchors.bottomMargin: 16
    spacing: 18

    Label {
      text: "S"
      font.pixelSize: 26
      font.bold: true
      color: Theme.accent

      Layout.alignment: Qt.AlignHCenter
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      color: Theme.divider
    }

    ToolButton {
      text: "◉"
      font.pixelSize: 23
      Layout.alignment: Qt.AlignHCenter

      background: Rectangle {
        radius: 10
        color: root.currentPage === "chats" ? Theme.accent : "transparent"
      }
      onClicked: root.navigationRequested("chats")
    }
    ToolButton {
      text: "♧"
      font.pixelSize: 23
      Layout.alignment: Qt.AlignHCenter
      background: Rectangle {
        radius: 10
        color: root.currentPage === "contacts" ? Theme.accent : "transparent"
      }
      onClicked: root.navigationRequested("contacts")
    }
    ToolButton {
      text: "◎"
      font.pixelSize: 23
      Layout.alignment: Qt.AlignHCenter
      background: Rectangle {
        radius: 10
        color: root.currentPage === "calls" ? Theme.accent : "transparent"
      }
      onClicked: root.navigationRequested("calls")
    }
    Item {
      Layout.fillHeight: true
    }
    ToolButton {
      text: "⚙"
      font.pixelSize: 23
      Layout.alignment: Qt.AlignHCenter
      background: Rectangle {
        radius: 10
        color: root.currentPage === "settings" ? Theme.accent : "transparent"
      }
      onClicked: root.navigationRequested("settings")
    }


  }
}
