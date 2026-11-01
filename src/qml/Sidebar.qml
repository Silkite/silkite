import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property string currentPage: "chats"

  signal navigationRequested(string page)

  color: "#202630"

  ColumnLayout {
    anchors.fill: parent
    anchors.topMargin: 18
    anchors.bottomMargin: 16
    spacing: 18

    Label {
      text: "S"
      font.pixelSize: 26
      font.bold: true
      color: "#82AFFF"

      Layout.alignment: Qt.AlignHCenter
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      color: "#39424F"
    }

    ToolButton {
      text: "◉"
      font.pixelSize: 23
      Layout.alignment: Qt.AlignHCenter

      background: Rectangle {
        radius: 10
        color: root.currentPage === "chats" ? "#414D5D" : "transparent"
      }
      onClicked: root.navigationRequested("chats")
    }
    ToolButton {
      text: "♧"
      font.pixelSize: 23
      Layout.alignment: Qt.AlignHCenter
      background: Rectangle {
        radius: 10
        color: root.currentPage === "contacts" ? "#414D5D" : "transparent"
      }
      onClicked: root.navigationRequested("contacts")
    }
    ToolButton {
      text: "◎"
      font.pixelSize: 23
      Layout.alignment: Qt.AlignHCenter
      background: Rectangle {
        radius: 10
        color: root.currentPage === "calls" ? "#414D5D" : "transparent"
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
        color: root.currentPage === "settings" ? "#414D5D" : "transparent"
      }
      onClicked: root.navigationRequested("settings")
    }


  }
}
