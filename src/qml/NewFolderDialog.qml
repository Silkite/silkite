import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Popup {
  id: root

  property var organizationManager: chatOrganizationManager
  property string selectedIcon: "📁"

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

      // Subtle inner border highlight
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

  contentItem: ColumnLayout {
    id: contentLayout
    spacing: 16
    anchors.fill: parent
    anchors.margins: 20

    // Header title row with close button
    RowLayout {
      Layout.fillWidth: true

      Label {
        text: "Create Folder"
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
      text: "Organize your contacts and chats into dedicated spaces."
      font.pixelSize: 12
      color: Theme.secondaryText
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    // Name Input
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      Label {
        text: "Folder Name"
        font.pixelSize: 12
        font.bold: true
        color: Theme.secondaryText
      }

      TextField {
        id: folderNameField
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        placeholderText: "e.g. Work, Family, Friends"
        placeholderTextColor: Qt.rgba(Theme.secondaryText.r, Theme.secondaryText.g, Theme.secondaryText.b, 0.5)
        color: Theme.primaryText
        selectByMouse: true

        background: Rectangle {
          radius: 10
          color: Theme.controlBackground
          border.color: folderNameField.activeFocus ? Theme.accent : Theme.divider
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 9
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, folderNameField.activeFocus ? 0.25 : 0.06)
            border.width: 1
          }
        }
      }
    }

    // Icon / Emoji selector
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      Label {
        text: "Choose Icon"
        font.pixelSize: 12
        font.bold: true
        color: Theme.secondaryText
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: ["📁", "💼", "👥", "❤️", "📢", "🎮", "💡", "🚀"]

          delegate: Rectangle {
            id: iconItem
            required property string modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 8
            color: root.selectedIcon === modelData 
                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                   : (iconMouse.containsMouse ? Theme.controlBackground : "transparent")
            border.color: root.selectedIcon === modelData ? Theme.accent : Theme.divider
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: iconItem.modelData
              font.pixelSize: 15
            }

            MouseArea {
              id: iconMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedIcon = iconItem.modelData
            }
          }
        }
      }
    }

    // Action Buttons
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 4
      spacing: 10

      Item { Layout.fillWidth: true }

      Button {
        id: cancelBtn
        Layout.preferredHeight: 34
        Layout.preferredWidth: 80
        background: Rectangle {
          radius: 10
          color: cancelBtn.down ? Theme.controlBackground : "transparent"
          border.color: cancelBtn.hovered ? Theme.primaryText : Theme.divider
          border.width: 1
        }
        contentItem: Text {
          text: "Cancel"
          color: Theme.primaryText
          font.pixelSize: 13
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        onClicked: root.close()
      }

      Button {
        id: createBtn
        Layout.preferredHeight: 34
        Layout.preferredWidth: 84
        enabled: folderNameField.text.trim().length > 0
        background: Rectangle {
          radius: 10
          color: createBtn.enabled 
                 ? (createBtn.down ? Qt.darker(Theme.accent, 1.1) : Theme.accent)
                 : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
        }
        contentItem: Text {
          text: "Create"
          color: Theme.accentText
          font.bold: true
          font.pixelSize: 13
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        onClicked: {
          var name = folderNameField.text.trim()
          if (name.length > 0) {
            var mgr = root.organizationManager !== undefined ? root.organizationManager : chatOrganizationManager
            if (mgr) {
              var newId = mgr.createFolder(name, root.selectedIcon)
              if (newId && newId.length > 0) {
                mgr.setActiveFolderId(newId)
              }
            }
            folderNameField.text = ""
            root.close()
          }
        }
      }
    }
  }

  onOpened: {
    folderNameField.text = ""
    folderNameField.forceActiveFocus()
  }
}
