import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
  id: root

  property var chatModel
  property var selectedChatId: 0
  property bool pointerInside: false
  readonly property bool compactMode: width < 140

  // Natural header width for "Chats" title + margins
  readonly property real headerTitleWidth: chatsHeaderLabel.implicitWidth + (anchors.margins ? anchors.margins * 2 : 28)

  signal chatSelected(var chatId)

  NewFolderDialog {
    id: newFolderDialog
    organizationManager: chatOrganizationManager
  }

  ManageChatFoldersDialog {
    id: manageFoldersDialog
    organizationManager: chatOrganizationManager
  }

  // Outer soft ambient elevation shadow
  Rectangle {
    anchors.fill: glassBody
    anchors.topMargin: 2
    anchors.bottomMargin: -2
    anchors.leftMargin: -1
    anchors.rightMargin: -1
    radius: glassBody.radius + 1
    color: Qt.rgba(0, 0, 0, 0.18)
    z: -1
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
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    anchors.topMargin: 14
    anchors.bottomMargin: 14
    spacing: root.compactMode ? 8 : 12

    Label {
      id: chatsHeaderLabel
      visible: true
      text: "Chats"
      font.pixelSize: 22
      font.bold: true
      color: Theme.primaryText
      Layout.alignment: Qt.AlignLeft
    }

    // Chat Organization: Folder bar with "New Folder" & Folder pills
    FolderBar {
      id: folderBar
      Layout.fillWidth: true
      organizationManager: chatOrganizationManager
      chatModel: root.chatModel
      selectedChatId: root.selectedChatId

      onCreateFolderRequested: {
        newFolderDialog.open()
      }
    }

    TextField {
      id: searchField
      visible: !root.compactMode
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
        required property var folderNames

        readonly property bool isSelected: chatDelegate.chatId === root.selectedChatId

        width: chatList.width
        height: root.compactMode ? 56 : ((folderNames && folderNames.length > 0) ? 78 : 72)
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
          spacing: root.compactMode ? 0 : 11

          // Avatar
          Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: root.compactMode ? Qt.AlignHCenter : Qt.AlignVCenter

            Rectangle {
              id: avatarBox
              anchors.fill: parent
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

            // Compact unread indicator badge on avatar
            Rectangle {
              visible: root.compactMode && chatDelegate.unreadCount > 0
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.topMargin: -2
              anchors.rightMargin: -2
              width: Math.max(16, compactBadgeLabel.implicitWidth + 6)
              height: 16
              radius: 8
              color: chatDelegate.isSelected ? Theme.windowBackground : Theme.accent
              border.color: Qt.rgba(1, 1, 1, 0.3)
              border.width: 1

              Label {
                id: compactBadgeLabel
                anchors.centerIn: parent
                text: chatDelegate.unreadCount.toString()
                color: chatDelegate.isSelected ? Theme.primaryText : Theme.accentText
                font.pixelSize: 9
                font.bold: true
              }
            }
          }

          // Chat details
          ColumnLayout {
            visible: !root.compactMode
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

            // Folder tags row if chat belongs to folders
            RowLayout {
              visible: chatDelegate.folderNames && chatDelegate.folderNames.length > 0
              spacing: 4
              Layout.fillWidth: true

              Repeater {
                model: chatDelegate.folderNames || []
                delegate: Rectangle {
                  required property string modelData
                  height: 16
                  radius: 4
                  implicitWidth: tagLabel.implicitWidth + 8
                  color: chatDelegate.isSelected ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)

                  Label {
                    id: tagLabel
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.pixelSize: 9
                    color: chatDelegate.isSelected ? Theme.accentText : Theme.accent
                  }
                }
              }
            }
          }
        }

        // Right click context menu to organize chat
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          onClicked: {
            chatContextMenu.targetChatId = chatDelegate.chatId
            chatContextMenu.targetChatName = chatDelegate.name
            chatContextMenu.popup()
          }
        }
      }

      Menu {
        id: chatContextMenu
        property var targetChatId: 0
        property string targetChatName: ""

        background: Item {
          implicitWidth: 160
          Rectangle {
            anchors.fill: menuGlass
            anchors.topMargin: 2
            anchors.bottomMargin: -2
            anchors.leftMargin: -1
            anchors.rightMargin: -1
            radius: menuGlass.radius + 1
            color: Qt.rgba(0, 0, 0, 0.22)
            z: -1
          }
          Rectangle {
            id: menuGlass
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.94)
            border.color: Theme.divider
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: 11
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1
            }
          }
        }

        MenuItem {
          text: "Move to Folder..."
          contentItem: Text {
            text: parent.text
            color: Theme.primaryText
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            leftPadding: 12
            rightPadding: 12
          }
          background: Rectangle {
            color: parent.highlighted ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"
            radius: 8
          }
          onTriggered: {
            manageFoldersDialog.chatId = chatContextMenu.targetChatId
            manageFoldersDialog.chatName = chatContextMenu.targetChatName
            manageFoldersDialog.open()
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
