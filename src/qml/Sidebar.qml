import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQuick.Shapes

Item {
  id: root

  property string currentPage: "chats"

  signal navigationRequested(string page)
  signal profileRequested()

  implicitWidth: 50
  width: implicitWidth

  // Floating liquid glass background container with rounded borders
  Shape {
    id: glassBody
    anchors.fill: parent
    layer.enabled: true
    layer.smooth: true
    layer.samples: 8

    ShapePath {
      fillColor: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
      strokeColor: "transparent"
      strokeWidth: 0
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      startX: 0
      startY: 0
      PathLine { x: glassBody.width; y: 0 }
      PathArc { x: glassBody.width - 10; y: 10; radiusX: 10; radiusY: 10; useLargeArc: false; direction: PathArc.Counterclockwise }
      PathLine { x: glassBody.width - 10; y: glassBody.height }
      PathLine { x: 0; y: glassBody.height }
      PathLine { x: 0; y: 0 }
    }

    ColumnLayout {
      id: columnContent
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: -5
      spacing: 5

      // Chats navigation icon
      ToolButton {
        Layout.alignment: Qt.AlignHCenter
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/chat.svg"
        icon.width: 20
        icon.height: 20
        padding: 0
        icon.color: root.currentPage === "chats" ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 32
        implicitHeight: 32
        ToolTip.visible: hovered
        ToolTip.text: "Chats"
        ToolTip.delay: 400

        background: Rectangle {
          antialiasing: true
          layer.enabled: true
          layer.smooth: true
          layer.samples: 4
          radius: 10
          color: root.currentPage === "chats" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "chats" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            anchors.fill: parent
            anchors.margins: 1
            radius: 9
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
        icon.width: 20
        icon.height: 20
        padding: 0
        icon.color: root.currentPage === "contacts" ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 32
        implicitHeight: 32
        ToolTip.visible: hovered
        ToolTip.text: "Contacts"
        ToolTip.delay: 400

        background: Rectangle {
          antialiasing: true
          layer.enabled: true
          layer.smooth: true
          layer.samples: 4
          radius: 10
          color: root.currentPage === "contacts" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "contacts" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            anchors.fill: parent
            anchors.margins: 1
            radius: 9
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
        icon.width: 20
        icon.height: 20
        padding: 0
        icon.color: root.currentPage === "calls" ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 32
        implicitHeight: 32
        ToolTip.visible: hovered
        ToolTip.text: "Calls"
        ToolTip.delay: 400

        background: Rectangle {
          antialiasing: true
          layer.enabled: true
          layer.smooth: true
          layer.samples: 4
          radius: 10
          color: root.currentPage === "calls" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "calls" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            anchors.fill: parent
            anchors.margins: 1
            radius: 9
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, root.currentPage === "calls" ? 0.35 : 0.08)
            border.width: 1
            visible: root.currentPage === "calls" || parent.parent.hovered
          }
        }
        onClicked: root.navigationRequested("calls")
      }

      // Settings icon
      ToolButton {
        Layout.alignment: Qt.AlignHCenter
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/settings.svg"
        icon.width: 20
        icon.height: 20
        padding: 0
        icon.color: root.currentPage === "settings" ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 32
        implicitHeight: 32
        ToolTip.visible: hovered
        ToolTip.text: "Settings"
        ToolTip.delay: 400

        background: Rectangle {
          antialiasing: true
          layer.enabled: true
          layer.smooth: true
          layer.samples: 4
          radius: 10
          color: root.currentPage === "settings" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "settings" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            anchors.fill: parent
            anchors.margins: 1
            radius: 9
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, root.currentPage === "settings" ? 0.35 : 0.08)
            border.width: 1
            visible: root.currentPage === "settings" || parent.parent.hovered
          }
        }
        onClicked: root.navigationRequested("settings")
      }

      // Profile avatar button below settings
      ToolButton {
        id: profileBtn
        Layout.alignment: Qt.AlignHCenter
        padding: 0
        focusPolicy: Qt.NoFocus
        implicitWidth: 32
        implicitHeight: 32
        ToolTip.visible: hovered
        ToolTip.text: "My Profile"
        ToolTip.delay: 400

        readonly property var myProf: (typeof telegramClient !== "undefined" && telegramClient.myProfile) ? telegramClient.myProfile : null
        readonly property string avatarPath: myProf && myProf.avatarPath ? myProf.avatarPath : ""
        readonly property string initials: myProf && myProf.initials ? myProf.initials : "?"
        readonly property string avatarColor: myProf && myProf.avatarColor ? myProf.avatarColor : "#526C8A"

        contentItem: Item {
          anchors.fill: parent

          Item {
            anchors.centerIn: parent
            width: 20
            height: 20

            Rectangle {
              id: avatarBg
              anchors.fill: parent
              radius: 10
              color: profileBtn.avatarPath !== "" ? "transparent" : profileBtn.avatarColor
              clip: true

              Text {
                anchors.centerIn: parent
                text: profileBtn.initials
                color: "#FFFFFF"
                font.pixelSize: 10
                font.bold: true
                visible: profileBtn.avatarPath === ""
              }

              Image {
                id: avatarImg
                anchors.fill: parent
                source: profileBtn.avatarPath !== "" ? ("file://" + profileBtn.avatarPath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                visible: profileBtn.avatarPath !== "" && status === Image.Ready
                layer.enabled: true
                layer.effect: OpacityMask {
                  maskSource: Rectangle {
                    width: avatarBg.width
                    height: avatarBg.height
                    radius: 10
                  }
                }
              }
            }
          }
        }

        background: Rectangle {
          antialiasing: true
          layer.enabled: true
          layer.smooth: true
          layer.samples: 4
          radius: 10
          color: root.currentPage === "profile" ? Theme.accent : (parent.hovered ? Theme.controlBackground : "transparent")
          border.color: root.currentPage === "profile" ? Qt.rgba(1, 1, 1, 0.25) : (parent.hovered ? Theme.divider : "transparent")
          border.width: 1

          Rectangle {
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            anchors.fill: parent
            anchors.margins: 1
            radius: 9
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, root.currentPage === "profile" ? 0.35 : 0.08)
            border.width: 1
            visible: root.currentPage === "profile" || parent.parent.hovered
          }
        }

        onClicked: root.profileRequested()
      }
    }
  }
}
