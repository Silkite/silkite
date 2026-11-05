import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property string chatName: ""
  property string chatInitials: "?"
  property string avatarColor: "#526C8A"
  property string lastMessage: ""
  property var messages: []
  property bool hasConversation: chatName !== ""
  property string appVersion: ""

  color: Theme.windowBackground

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // Conversation header
    Rectangle {
      visible: root.hasConversation
      Layout.fillWidth: true
      Layout.preferredHeight: 72

      color: Theme.elevatedBackground

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
            color: Theme.primaryText
            font.bold: true
          }
        }
        ColumnLayout {
          spacing: 3

          Label {
            text: root.chatName

            color: Theme.primaryText
            font.bold: true
            font.pixelSize: 15
          }

          Label {
            text: "Telegram conversation"

            color: Theme.secondaryText
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

      ListView {
        anchors.fill: parent
        anchors.margins: 18
        model: root.messages
        delegate: Label {
          width: ListView.view.width
          text: modelData.time + "  " + modelData.text
          color: Theme.primaryText
          horizontalAlignment: modelData.outgoing ? Text.AlignRight : Text.AlignLeft
          wrapMode: Text.WordWrap
          padding: 8
        }
        Label {
          anchors.centerIn: parent
          visible: root.hasConversation && root.messages.length === 0
          text: "Your conversation will appear here."
          color: Theme.secondaryText
        }

        Label {
          id: emptyLogo
          anchors.centerIn: parent
          visible: !root.hasConversation
          text: "Silkite"
          color: Theme.primaryText
          font.pixelSize: 44
          font.bold: true
          opacity: 0.12
        }

        Label {
          anchors.horizontalCenter: emptyLogo.horizontalCenter
          anchors.top: emptyLogo.bottom
          anchors.topMargin: 6
          visible: !root.hasConversation
          text: "v" + root.appVersion
          color: Theme.primaryText
          font.pixelSize: 13
          opacity: 0.12
        }
      }
    }

    // Message composer
    Rectangle {
      visible: root.hasConversation
      Layout.fillWidth: true
      Layout.preferredHeight: 78

      color: Theme.elevatedBackground

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

          color: Theme.primaryText

          background: Rectangle {
            radius: 10
            color: Theme.windowBackground
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
