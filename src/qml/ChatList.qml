import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
  id: root

  property var chatModel
  property var selectedChatId: 0
  property bool pointerInside: false

  signal chatSelected(var chatId)

  // Floating elevation shadow
  DropShadow {
    anchors.fill: glassBody
    source: glassBody
    radius: 16
    samples: 24
    color: Qt.rgba(0, 0, 0, 0.40)
    verticalOffset: 3
    horizontalOffset: 1
  }

  // Liquid glass background container
  Rectangle {
    id: glassBody
    anchors.fill: parent
    radius: 18
    color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
    border.color: Theme.divider
    border.width: 1

    // Inner subtle border highlight
    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: 17
      color: "transparent"
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1
    }
  }

  HoverHandler {
    onHoveredChanged: root.pointerInside = hovered
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 12

    Label {
      text: "Chats"
      font.pixelSize: 22
      font.bold: true
      color: Theme.primaryText
    }

    TextField {
      id: searchField

      Layout.fillWidth: true
      Layout.preferredHeight: 38
      placeholderText: "Search chats..."
      color: Theme.primaryText
      selectByMouse: true

      onTextChanged: root.chatModel.filterText = text

      background: Rectangle {
        radius: 12
        color: Theme.controlBackground
        border.color: searchField.activeFocus ? Theme.accent : Theme.divider
        border.width: 1

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: 11
          color: "transparent"
          border.color: Qt.rgba(1, 1, 1, searchField.activeFocus ? 0.25 : 0.08)
          border.width: 1
        }
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
        required property string avatarPath
        required property int unreadCount

        readonly property bool isSelected: chatDelegate.chatId === root.selectedChatId

        width: chatList.width
        height: 72
        clip: true

        background: Rectangle {
          radius: 14
          color: chatDelegate.isSelected
                 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.9)
                 : (chatDelegate.hovered ? Theme.controlBackground : "transparent")
          border.color: chatDelegate.isSelected
                        ? Qt.rgba(1, 1, 1, 0.3)
                        : (chatDelegate.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 13
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, chatDelegate.isSelected ? 0.35 : 0.08)
            border.width: 1
            visible: chatDelegate.isSelected || chatDelegate.hovered
          }
        }

        onClicked: root.chatSelected(chatDelegate.chatId)

        contentItem: RowLayout {
          spacing: 11

          // Avatar
          Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: 22
            color: chatDelegate.avatarColor
            clip: true
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

            Image {
              id: avatarImage
              anchors.fill: parent
              anchors.margins: 1
              visible: false
              source: chatDelegate.avatarPath === "" ? "" : "file://" + chatDelegate.avatarPath
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
            }

            OpacityMask {
              anchors.fill: parent
              anchors.margins: 1
              visible: chatDelegate.avatarPath !== ""
              source: avatarImage
              maskSource: Rectangle {
                width: avatarImage.width
                height: avatarImage.height
                radius: width / 2
                color: "white"
              }
            }

            Label {
              anchors.centerIn: parent
              text: chatDelegate.initials
              visible: chatDelegate.avatarPath === ""
              color: "#FFFFFF"
              font.bold: true
              font.pixelSize: 15
            }
          }

          // Chat details
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
              Layout.fillWidth: true
              spacing: 5

              Label {
                text: chatDelegate.name
                color: chatDelegate.isSelected ? Theme.accentText : Theme.primaryText
                font.bold: true
                font.pixelSize: 14
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                maximumLineCount: 1
              }

              Label {
                text: chatDelegate.time
                color: chatDelegate.isSelected ? Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.75) : Theme.secondaryText
                font.pixelSize: 11
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 5

              Label {
                text: chatDelegate.lastMessage
                color: chatDelegate.isSelected ? Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.85) : Theme.secondaryText
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                maximumLineCount: 1
                font.pixelSize: 13
              }

              Rectangle {
                Layout.preferredWidth: Math.max(20, unreadCountLabel.implicitWidth + 8)
                Layout.preferredHeight: 20
                radius: 10
                color: chatDelegate.isSelected ? Theme.windowBackground : Theme.accent
                border.color: Qt.rgba(1, 1, 1, 0.2)
                border.width: 1

                visible: chatDelegate.unreadCount > 0

                Label {
                  id: unreadCountLabel
                  anchors.centerIn: parent
                  text: chatDelegate.unreadCount.toString()
                  color: chatDelegate.isSelected ? Theme.primaryText : Theme.accentText
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
