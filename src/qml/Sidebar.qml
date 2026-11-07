import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
  id: root

  property string currentPage: "chats"

  signal navigationRequested(string page)

  implicitWidth: 64
  width: implicitWidth

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

  // Floating liquid glass background container with rounded borders
  Rectangle {
    id: glassBody
    anchors.fill: parent
    radius: 18
    color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
    border.color: Theme.divider
    border.width: 1

    // Inner subtle border highlight matching UI aesthetic
    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: 17
      color: "transparent"
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1
    }

    ColumnLayout {
      id: columnContent
      anchors.fill: parent
      anchors.topMargin: 14
      anchors.bottomMargin: 14
      spacing: 12

      // Silkite Logo
      Image {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        source: "qrc:/qt/qml/Silkite/assets/logo-transparent.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
      }

      // Divider separator
      Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 28
        Layout.preferredHeight: 1
        color: Theme.divider
      }

      // Chats navigation icon
      ToolButton {
        Layout.alignment: Qt.AlignHCenter
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/chat.svg"
        icon.width: 22
        icon.height: 22
        icon.color: root.currentPage === "chats" ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 38
        implicitHeight: 38
        ToolTip.visible: hovered
        ToolTip.text: "Chats"
        ToolTip.delay: 400

        background: Rectangle {
          radius: 12
          color: root.currentPage === "chats" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "chats" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, root.currentPage === "chats" ? 0.35 : 0.08)
            border.width: 1
            visible: root.currentPage === "chats" || parent.parent.hovered
          }
        }
        onClicked: root.navigationRequested("chats")
      }

      // Contacts navigation icon
      ToolButton {
        Layout.alignment: Qt.AlignHCenter
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/people.svg"
        icon.width: 22
        icon.height: 22
        icon.color: root.currentPage === "contacts" ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 38
        implicitHeight: 38
        ToolTip.visible: hovered
        ToolTip.text: "Contacts"
        ToolTip.delay: 400

        background: Rectangle {
          radius: 12
          color: root.currentPage === "contacts" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "contacts" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, root.currentPage === "contacts" ? 0.35 : 0.08)
            border.width: 1
            visible: root.currentPage === "contacts" || parent.parent.hovered
          }
        }
        onClicked: root.navigationRequested("contacts")
      }

      // Calls navigation icon
      ToolButton {
        Layout.alignment: Qt.AlignHCenter
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/call.svg"
        icon.width: 22
        icon.height: 22
        icon.color: root.currentPage === "calls" ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 38
        implicitHeight: 38
        ToolTip.visible: hovered
        ToolTip.text: "Calls"
        ToolTip.delay: 400

        background: Rectangle {
          radius: 12
          color: root.currentPage === "calls" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "calls" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, root.currentPage === "calls" ? 0.35 : 0.08)
            border.width: 1
            visible: root.currentPage === "calls" || parent.parent.hovered
          }
        }
        onClicked: root.navigationRequested("calls")
      }

      // Flexible space between top navigation and bottom settings
      Item {
        Layout.fillHeight: true
      }

      // Settings icon
      ToolButton {
        Layout.alignment: Qt.AlignHCenter
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/settings.svg"
        icon.width: 22
        icon.height: 22
        icon.color: root.currentPage === "settings" ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 38
        implicitHeight: 38
        ToolTip.visible: hovered
        ToolTip.text: "Settings"
        ToolTip.delay: 400

        background: Rectangle {
          radius: 12
          color: root.currentPage === "settings" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "settings" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, root.currentPage === "settings" ? 0.35 : 0.08)
            border.width: 1
            visible: root.currentPage === "settings" || parent.parent.hovered
          }
        }
        onClicked: root.navigationRequested("settings")
      }
    }
  }
}
