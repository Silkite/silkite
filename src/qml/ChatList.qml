import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property var chatModel
  property int selectedChatIndex: 0

  signal chatSelected(int index)

  color: "#29313C"

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 12
    
    Label {
      text: "Chats"

      font.pixelSize: 23
      font.bold: true

      color: "#FFFFFF"
    }

    TextField {
      id: searchField

      Layout.fillWidth: true

      placeholderText: "Search chats ..."
      color: "#FFFFFF"

      background: Rectangle {
        radius: 9
        color: "#202630"
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
        required property string lastMessage
        required property string time
        required property string initials
        required property string avatarColor
        required property int index

        width: chatList.width
        height: 76

        background: Rectangle {
          radius: 9

          color: index === root.selectedChatIndex ? "#414D5D" : "transparent"
        }

        onClicked: {
          root.chatSelected(index)
        }

        contentItem: RowLayout {
          spacing: 10
          Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44

            radius: 22

            color: chatDelegate.avatarColor

            Label {
              anchors.centerIn: parent

              text: chatDelegate.initials

              color: "#FFFFFF"
              font.bold: true
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
              Layout.fillWidth: true

              Label {
                text: chatDelegate.name

                color: "#FFFFFF"
                font.bold: true

                elide: Text.ElideRight

                Layout.fillWidth: true
              }

              Label {
                text: chatDelegate.time

                color: "#AAB3C0"
                font.pixelSize: 10
              }
            }

            Label {
              text: chatDelegate.lastMessage

              color: "#AAB3C0"

              elide: Text.ElideRight

              Layout.fillWidth: true
            }
          }
        }
      }
    }
  }
}
