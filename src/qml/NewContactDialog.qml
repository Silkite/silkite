import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
  id: root

  title: ""
  modal: true
  focus: true
  x: Math.round((parent.width - width) / 2)
  y: Math.round((parent.height - height) / 2)
  width: Math.min(parent.width - 40, 380)

  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  background: Item {
    Rectangle {
      anchors.fill: dialogGlass
      anchors.topMargin: 2
      anchors.bottomMargin: -2
      anchors.leftMargin: -1
      anchors.rightMargin: -1
      radius: dialogGlass.radius + 1
      color: Qt.rgba(0, 0, 0, 0.22)
      z: -1
    }
    Rectangle {
      id: dialogGlass
      anchors.fill: parent
      radius: 16
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.95)
      border.color: Theme.divider
      border.width: 1

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 15
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
      }
    }
  }

  contentItem: ColumnLayout {
    spacing: 14

    Label {
      text: "New Contact"
      font.pixelSize: 18
      font.bold: true
      color: Theme.primaryText
      Layout.alignment: Qt.AlignHCenter
      topPadding: 4
      bottomPadding: 4
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      Label {
        text: "Phone Number"
        font.pixelSize: 12
        color: Theme.secondaryText
      }

      TextField {
        id: phoneField
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        placeholderText: "+1 234 567 8900"
        color: Theme.primaryText
        font.pixelSize: 14
        leftPadding: 12
        rightPadding: 12
        selectByMouse: true
        background: Rectangle {
          radius: 10
          color: Theme.controlBackground
          border.color: phoneField.activeFocus ? Theme.accent : Theme.divider
          border.width: 1
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      Label {
        text: "First Name"
        font.pixelSize: 12
        color: Theme.secondaryText
      }

      TextField {
        id: firstNameField
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        placeholderText: "First name"
        color: Theme.primaryText
        font.pixelSize: 14
        leftPadding: 12
        rightPadding: 12
        selectByMouse: true
        background: Rectangle {
          radius: 10
          color: Theme.controlBackground
          border.color: firstNameField.activeFocus ? Theme.accent : Theme.divider
          border.width: 1
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      Label {
        text: "Last Name (optional)"
        font.pixelSize: 12
        color: Theme.secondaryText
      }

      TextField {
        id: lastNameField
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        placeholderText: "Last name"
        color: Theme.primaryText
        font.pixelSize: 14
        leftPadding: 12
        rightPadding: 12
        selectByMouse: true
        background: Rectangle {
          radius: 10
          color: Theme.controlBackground
          border.color: lastNameField.activeFocus ? Theme.accent : Theme.divider
          border.width: 1
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 8
      spacing: 10

      Button {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        text: "Cancel"
        contentItem: Label {
          text: parent.text
          color: Theme.primaryText
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          font.pixelSize: 13
        }
        background: Rectangle {
          radius: 10
          color: parent.hovered ? Theme.controlBackground : "transparent"
          border.color: Theme.divider
          border.width: 1
        }
        onClicked: root.close()
      }

      Button {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        text: "Add"
        enabled: phoneField.text.trim().length > 3 && firstNameField.text.trim().length > 0
        contentItem: Label {
          text: parent.text
          color: parent.enabled ? Theme.accentText : Theme.secondaryText
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          font.pixelSize: 13
          font.bold: true
        }
        background: Rectangle {
          radius: 10
          color: parent.enabled ? (parent.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : Theme.controlBackground
          opacity: parent.enabled ? 1.0 : 0.5
        }
        onClicked: {
          telegramClient.addContact(phoneField.text.trim(), firstNameField.text.trim(), lastNameField.text.trim())
          phoneField.clear()
          firstNameField.clear()
          lastNameField.clear()
          root.close()
        }
      }
    }
  }

  onOpened: {
    phoneField.forceActiveFocus()
  }
}
