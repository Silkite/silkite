import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property string chatName: "Select a conversation"
  property string chatInitials: "?"
  property string avatarColor: "#526C8A"
  property string lastMessage: ""

  color: "#1C222B"

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // Conversation header
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 72

      color: "#252D38"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20

        spacing: 12

        Rectangle {
          Layout.preferredWidth: 42
          Layout.preferredHeight: 42

          radius: 21
          color: root.avatarColor

          Label {
            anchors.centerIn: parent

            text: root.chatInitials
            color: "white"
            font.bold: true
          }
        }
        ColumnLayout {
          spacing: 3

          Label {
            text: root.chatName

            color: "white"
            font.bold: true
            font.pixelSize: 15
          }

          Label {
            text: "Telegram conversation"

            color: "#AAB3C0"
            font.pixelSize: 11
          }
        }

        Item {
          Layout.fillWidth: true
        }

        ToolButton {
          text: "⌕"
          font.pixelSize: 24
        }

        ToolButton {
          text: "⋮"
          font.pixelSize: 24
        }
      }
    }

    // Messages area
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 14

        Label {
          text: "Welcome to Silkite"

          color: "#FFFFFF"
          font.pixelSize: 20
          font.bold: true

          Layout.alignment: Qt.AlignHCenter
        }

        Label {
          text: "Your conversation will appear here."

          color: "#AAB3C0"

          Layout.alignment: Qt.AlignHCenter
        }
      }
    }

    // Message composer
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 78

      color: "#252D38"

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        ToolButton {
          text: "+"
          font.pixelSize: 25
        }

        TextField {
          Layout.fillWidth: true

          placeholderText: "Write a message..."

          color: "white"

          background: Rectangle {
            radius: 10
            color: "#1C222B"
          }
        }

        ToolButton {
          text: "➤"
          font.pixelSize: 21
        }
      }
    }
  }
}
