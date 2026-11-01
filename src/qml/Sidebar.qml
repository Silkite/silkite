import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

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
      onClicked: root.navigationRequested("chats")
      Layout.alignment: Qt.AlignHCenter
    }
    ToolButton {
      text: "♧"
      font.pixelSize: 23
      onClicked: root.navigationRequested("contacts")
      Layout.alignment: Qt.AlignHCenter
    }
    ToolButton {
      text: "◎"
      font.pixelSize: 23
      onClicked: root.navigationRequested("calls")
      Layout.alignment: Qt.AlignHCenter
    }
    Item {
      Layout.fillHeight: true
    }
    ToolButton {
      text: "⚙"
      font.pixelSize: 23
      onClicked: root.navigationRequested("settings")
      Layout.alignment: Qt.AlignHCenter
    }


  }
}
