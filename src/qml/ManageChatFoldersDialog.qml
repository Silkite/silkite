import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Popup {
  id: root

  property var organizationManager: chatOrganizationManager
  property var chatId: 0
  property string chatName: ""
  property var folderList: []

  modal: true
  dim: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
  anchors.centerIn: Overlay.overlay

  width: 360
  implicitWidth: 360
  implicitHeight: contentLayout.implicitHeight + 40

  padding: 0
  topPadding: 0
  bottomPadding: 0
  leftPadding: 0
  rightPadding: 0

  background: Item {
    anchors.fill: parent

    DropShadow {
      anchors.fill: glassBody
      source: glassBody
      radius: 20
      samples: 28
      color: Qt.rgba(0, 0, 0, 0.45)
      verticalOffset: 6
      horizontalOffset: 0
    }

    Rectangle {
      id: glassBody
      anchors.fill: parent
      radius: 18
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.90)
      border.color: Theme.divider
      border.width: 1

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 17
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
      }
    }
  }

  function reloadFolders() {
    if (root.chatId && root.organizationManager) {
      root.folderList = root.organizationManager.getFoldersForChat(root.chatId)
    }
  }

  onOpened: reloadFolders()

  contentItem: ColumnLayout {
    id: contentLayout
    spacing: 14
    anchors.fill: parent
    anchors.margins: 20

    // Header title row with close button
    RowLayout {
      Layout.fillWidth: true

      Label {
        text: "Move to Folders"
        font.pixelSize: 18
        font.bold: true
        color: Theme.primaryText
        Layout.fillWidth: true
      }

      Rectangle {
        width: 26
        height: 26
        radius: 13
        color: closeMouse.containsMouse ? Theme.controlBackground : "transparent"

        Text {
          anchors.centerIn: parent
          text: "✕"
          font.pixelSize: 12
          color: Theme.secondaryText
        }

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.close()
        }
      }
    }

    Label {
      text: "Assign \"" + root.chatName + "\" to folders:"
      font.pixelSize: 12
      color: Theme.secondaryText
      elide: Text.ElideRight
      Layout.fillWidth: true
    }

    ListView {
      id: foldersView
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(220, Math.max(48, root.folderList.length * 48))
      model: root.folderList
      clip: true
      spacing: 6

      delegate: Rectangle {
        id: folderRow
        required property var modelData
        width: foldersView.width
        height: 42
        radius: 10
        color: modelData.hasChat 
               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
               : (rowMouse.containsMouse ? Theme.controlBackground : "transparent")
        border.color: modelData.hasChat ? Theme.accent : Theme.divider
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 10

          Text {
            text: folderRow.modelData.icon
            font.pixelSize: 16
          }

          Label {
            text: folderRow.modelData.name
            font.pixelSize: 13
            font.bold: folderRow.modelData.hasChat
            color: Theme.primaryText
            Layout.fillWidth: true
          }

          CheckBox {
            checked: folderRow.modelData.hasChat
            onClicked: {
              root.organizationManager.toggleChatInFolder(folderRow.modelData.id, root.chatId)
              root.reloadFolders()
            }
          }
        }

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.organizationManager.toggleChatInFolder(folderRow.modelData.id, root.chatId)
            root.reloadFolders()
          }
        }
      }
    }

    Label {
      visible: root.folderList.length === 0
      text: "No custom folders yet. Create one from the folder bar!"
      font.pixelSize: 12
      color: Theme.secondaryText
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    RowLayout {
      Layout.fillWidth: true
      Item { Layout.fillWidth: true }
      Button {
        Layout.preferredHeight: 34
        Layout.preferredWidth: 80
        background: Rectangle {
          radius: 10
          color: Theme.accent
        }
        contentItem: Text {
          text: "Done"
          color: Theme.accentText
          font.bold: true
          font.pixelSize: 13
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        onClicked: root.close()
      }
    }
  }
}
