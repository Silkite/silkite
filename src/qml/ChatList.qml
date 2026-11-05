import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property var chatModel
  property var selectedChatId: 0

  signal chatSelected(var chatId)

  color: Theme.panelBackground

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 12

    Label {
      text: "Chats"
      font.pixelSize: 23
      font.bold: true
      color: Theme.primaryText
    }

    TextField {
      id: searchField

      Layout.fillWidth: true
      placeholderText: "Search chats..."
      color: Theme.primaryText
      selectByMouse: true

      onTextChanged: root.chatModel.filterText = text

      background: Rectangle {
        radius: 9
        color: Theme.elevatedBackground
      }
    }

    ListView {
      id: chatList

      Layout.fillWidth: true
      Layout.fillHeight: true

      model: root.chatModel 
      spacing: 5
      clip: true

      delegate: ItemDelegate {
        id: chatDelegate

        required property string name
        required property var chatId
        required property string lastMessage
        required property string time
        required property string initials
        required property string avatarColor
        required property int unreadCount

        width: chatList.width
        height: 76
        clip: true

        background: Rectangle {
          radius: 9

          color: chatDelegate.chatId === root.selectedChatId
                 ? Theme.accent
                 : "transparent"
        }

        onClicked: root.chatSelected(chatDelegate.chatId)

        contentItem: RowLayout {
          spacing: 10

          // Avatar
          Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: 22
            color: chatDelegate.avatarColor

            Label {
              anchors.centerIn: parent
              text: chatDelegate.initials
              color: Theme.primaryText
              font.bold: true
            }
          }

          // Chat details
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
              Layout.fillWidth: true
              spacing: 5

              Label {
                text: chatDelegate.name
                color: Theme.primaryText
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            Layout.minimumWidth: 0
            maximumLineCount: 1
              }

              Label {
                text: chatDelegate.time
                color: Theme.secondaryText
                font.pixelSize: 10
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 5

              Label {
                text: chatDelegate.lastMessage
                color: Theme.secondaryText
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                maximumLineCount: 1
              }

              Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: Theme.accent

                visible: chatDelegate.unreadCount > 0

                Label {
                  anchors.centerIn: parent
                  text: chatDelegate.unreadCount.toString()
                  color: Theme.accentText
                  font.pixelSize: 10
                  font.bold: true
                }
              }
            }
          }
        }
      }

      Label {
        anchors.centerIn: parent
        visible: chatList.count === 0
        text: "No chats found"
        color: Theme.secondaryText
        font.pixelSize: 14
      }
    }
  }
}
