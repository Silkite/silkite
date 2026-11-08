import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Popup {
  id: root

  property var chatId: 0
  property string chatName: ""
  property bool canDeleteForAllUsers: false
  property bool deleteForAll: false

  signal chatDeletionConfirmed(var targetChatId, bool revoke)

  function openForChat(targetChatId, targetChatName, canDeleteForEveryone) {
    chatId = targetChatId
    chatName = targetChatName || "this chat"
    canDeleteForAllUsers = !!canDeleteForEveryone
    deleteForAll = false
    open()
  }

  modal: true
  dim: true
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
  anchors.centerIn: Overlay.overlay

  width: 380
  implicitWidth: 380
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
      radius: 24
      samples: 30
      color: Qt.rgba(0, 0, 0, 0.45)
      verticalOffset: 6
      horizontalOffset: 0
    }

    Rectangle {
      id: glassBody
      anchors.fill: parent
      radius: 18
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.94)
      border.color: Theme.divider
      border.width: 1

      // Subtle inner highlight
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

    // Header title row with trash icon and close button
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        width: 32
        height: 32
        radius: 16
        color: Qt.rgba(255, 82, 82, 0.15)
        border.color: Qt.rgba(255, 82, 82, 0.3)
        border.width: 1

        Image {
          anchors.centerIn: parent
          width: 16
          height: 16
          source: "qrc:/qt/qml/Silkite/assets/icons/delete.svg"
          fillMode: Image.PreserveAspectFit
        }
      }

      Label {
        text: "Delete Chat"
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

    // Message body
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      Label {
        text: root.chatName.length > 0 && root.chatName !== "this chat"
              ? "Are you sure you want to delete the chat with \"" + root.chatName + "\"?"
              : "Are you sure you want to delete this chat?"
        font.pixelSize: 14
        color: Theme.primaryText
        wrapMode: Text.Wrap
        Layout.fillWidth: true
      }

      Label {
        text: "This action cannot be undone."
        font.pixelSize: 12
        color: Theme.secondaryText
        wrapMode: Text.Wrap
        Layout.fillWidth: true
      }
    }

    // Checkbox card for "Also delete for [User]" (Telegram dual-deletion method)
    Rectangle {
      id: dualDeleteOptionCard
      visible: root.canDeleteForAllUsers
      Layout.fillWidth: true
      implicitHeight: dualDeleteLayout.implicitHeight + 16
      radius: 12
      color: dualDeleteMouse.containsMouse
             ? Qt.rgba(Theme.controlBackground.r, Theme.controlBackground.g, Theme.controlBackground.b, 0.8)
             : Theme.controlBackground
      border.color: root.deleteForAll ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45) : Theme.divider
      border.width: 1

      MouseArea {
        id: dualDeleteMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.deleteForAll = !root.deleteForAll
      }

      RowLayout {
        id: dualDeleteLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        // Custom stylized Checkbox box
        Rectangle {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          radius: 6
          color: root.deleteForAll ? Theme.accent : "transparent"
          border.color: root.deleteForAll ? Theme.accent : Theme.divider
          border.width: root.deleteForAll ? 0 : 1.5

          Image {
            anchors.centerIn: parent
            width: 12
            height: 12
            visible: root.deleteForAll
            source: "qrc:/qt/qml/Silkite/assets/icons/checkmark.svg"
            fillMode: Image.PreserveAspectFit
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Label {
            text: root.chatName.length > 0 && root.chatName !== "this chat"
                  ? "Also delete for " + root.chatName
                  : "Also delete for everyone"
            font.pixelSize: 13
            font.bold: true
            color: Theme.primaryText
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Label {
            text: root.deleteForAll
                  ? "Deletes history and removes the chat for both participants"
                  : "Deletes history and removes the chat for you only"
            font.pixelSize: 11
            color: Theme.secondaryText
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }
        }
      }
    }

    // Info card if deletion is only available for self
    Rectangle {
      visible: !root.canDeleteForAllUsers
      Layout.fillWidth: true
      implicitHeight: singleDeleteLayout.implicitHeight + 16
      radius: 10
      color: Theme.controlBackground
      border.color: Theme.divider
      border.width: 1

      RowLayout {
        id: singleDeleteLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Label {
          text: "ℹ"
          font.pixelSize: 14
          color: Theme.secondaryText
        }

        Label {
          text: "This chat will be removed from your chatbar and deleted only for your account."
          font.pixelSize: 12
          color: Theme.secondaryText
          wrapMode: Text.Wrap
          Layout.fillWidth: true
        }
      }
    }

    // Action buttons row
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
        id: deleteBtn
        Layout.preferredHeight: 34
        Layout.preferredWidth: 92
        background: Rectangle {
          radius: 10
          color: deleteBtn.down ? "#D32F2F" : (deleteBtn.hovered ? "#F44336" : "#E53935")
          border.color: Qt.rgba(255, 255, 255, 0.2)
          border.width: 1
        }
        contentItem: RowLayout {
          spacing: 6
          anchors.centerIn: parent

          Image {
            source: "qrc:/qt/qml/Silkite/assets/icons/delete.svg"
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            fillMode: Image.PreserveAspectFit
          }

          Text {
            text: "Delete"
            color: "#FFFFFF"
            font.bold: true
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
          }
        }
        onClicked: {
          var targetId = root.chatId
          var revoke = root.canDeleteForAllUsers && root.deleteForAll
          root.chatDeletionConfirmed(targetId, revoke)
          if (typeof telegramClient !== "undefined" && targetId !== 0) {
            telegramClient.deleteChatHistory(targetId, true, revoke)
          }
          root.close()
        }
      }
    }
  }
}
