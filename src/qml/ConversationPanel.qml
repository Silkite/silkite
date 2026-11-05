import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
  id: root

  property string chatName: ""
  property string chatInitials: "?"
  property string avatarColor: "#526C8A"
  property string avatarPath: ""
  property string lastMessage: ""
  property var messages: []
  property bool hasConversation: chatName !== ""
  property string appVersion: ""
  property color glassColor: Qt.rgba(1, 1, 1, 0.08)
  property color glassBorder: Qt.rgba(1, 1, 1, 0.16)

  signal startMessaging()

  color: Theme.windowBackground

  // Conversation header
  Rectangle {
    id: conversationHeader
    z: 2
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.hasConversation ? 72 : 0
    clip: true

    color: "transparent"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20

        spacing: 12

        Rectangle {
          Layout.preferredWidth: 42
          Layout.preferredHeight: 42

          radius: 21
          color: root.avatarColor
          border.color: root.glassBorder
          border.width: 1
          clip: true

          Image {
            id: headerAvatarImage
            anchors.fill: parent
            anchors.margins: 1
            visible: false
            source: root.avatarPath === "" ? "" : "file://" + root.avatarPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
          }

          OpacityMask {
            anchors.fill: parent
            anchors.margins: 1
            visible: root.avatarPath !== ""
            source: headerAvatarImage
            maskSource: Rectangle {
              width: headerAvatarImage.width
              height: headerAvatarImage.height
              radius: width / 2
              color: "white"
            }
          }

          Label {
            anchors.centerIn: parent

            text: root.chatInitials
            visible: root.avatarPath === ""
            color: Theme.primaryText
            font.bold: true
          }
        }
        ColumnLayout {
          spacing: 3

          Label {
            text: root.chatName

            color: Theme.primaryText
            font.bold: true
            font.pixelSize: 15
          }

          Label {
            text: "Telegram conversation"

            color: Theme.secondaryText
            font.pixelSize: 11
          }
        }

        Item {
          Layout.fillWidth: true
        }

        ToolButton {
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/search.svg"
          icon.width: 22
          icon.height: 22
          focusPolicy: Qt.NoFocus
          padding: 8
          implicitWidth: 40
          implicitHeight: 40
          background: Rectangle {
            radius: width / 2
            color: parent.hovered ? Theme.accent : root.glassColor
            border.color: root.glassBorder
            border.width: 1
          }
        }

        ToolButton {
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/more.svg"
          icon.width: 22
          icon.height: 22
          focusPolicy: Qt.NoFocus
          padding: 8
          implicitWidth: 40
          implicitHeight: 40
          background: Rectangle {
            radius: width / 2
            color: parent.hovered ? Theme.accent : root.glassColor
            border.color: root.glassBorder
            border.width: 1
          }
        }
      }
  }

  // Messages area fills all space between the header and composer.
  Item {
    id: messagesArea
    z: 1
    clip: true
    anchors.top: conversationHeader.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: messageComposer.top

      ListView {
        clip: true
        anchors.fill: parent
        anchors.margins: 18
        visible: root.hasConversation
        model: root.messages
        delegate: Item {
          width: ListView.view.width
          height: bubble.implicitHeight + 8

          Rectangle {
            id: bubble
            anchors.right: modelData.outgoing ? parent.right : undefined
            anchors.left: modelData.outgoing ? undefined : parent.left
            width: Math.min(parent.width * 0.78, bubbleText.implicitWidth + 28)
            implicitHeight: bubbleText.implicitHeight + 18
            radius: 12
            color: modelData.outgoing ? Theme.accent : Theme.elevatedBackground

            Label {
              id: bubbleText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 10
              text: modelData.text + "\n" + modelData.time + (modelData.outgoing && modelData.status !== "" ? "  " + modelData.status : "")
              color: Theme.primaryText
              wrapMode: Text.WordWrap
            }
          }
        }
      }

      Label {
        anchors.centerIn: parent
        visible: root.hasConversation && root.messages.length === 0
        text: "Your conversation will appear here."
        color: Theme.secondaryText
      }

  }

  // Message composer
  Rectangle {
    id: messageComposer
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.hasConversation ? 78 : 0
    clip: true

      color: "transparent"

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        ToolButton {
          text: "+"
          font.pixelSize: 25
          focusPolicy: Qt.NoFocus
          padding: 8
          implicitWidth: 40
          implicitHeight: 40
          background: Rectangle {
            radius: width / 2
            color: parent.hovered ? Theme.accent : root.glassColor
            border.color: root.glassBorder
            border.width: 1
          }
        }

        TextField {
          Layout.fillWidth: true
          Layout.preferredHeight: 40

          placeholderText: "Write a message..."

          color: Theme.primaryText

          background: Rectangle {
            radius: height / 2
            color: root.glassColor
            border.color: root.glassBorder
            border.width: 1
          }
        }

        ToolButton {
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/send.svg"
          icon.width: 22
          icon.height: 22
          focusPolicy: Qt.NoFocus
          padding: 8
          implicitWidth: 40
          implicitHeight: 40
          background: Rectangle {
            radius: width / 2
            color: parent.hovered ? Theme.accent : root.glassColor
            border.color: root.glassBorder
            border.width: 1
          }
        }
      }
  }

  Button {
    z: 10
    anchors.centerIn: parent
    visible: !root.hasConversation
    text: "Start messaging"
    implicitHeight: 40
    onClicked: root.startMessaging()

    contentItem: Label {
      text: parent.text
      color: Theme.primaryText
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      leftPadding: 18
      rightPadding: 18
    }

    background: Rectangle {
      radius: height / 2
      color: parent.pressed
        ? Qt.darker(Theme.accent, 1.15)
        : (parent.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
    }
  }
}
