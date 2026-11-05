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
  property bool typing: false

  onMessagesChanged: {
    // Whenever messages list changes (e.g. read status update, send/receive), keep position at the bottom
    Qt.callLater(function() {
      if (messageListView.count > 0 && (messageListView.atYEnd || messageListView.contentHeight <= messageListView.height)) {
        messageListView.positionViewAtEnd()
      }
    })
  }

  property bool hasConversation: chatName !== ""
  property string appVersion: ""
  property color glassColor: Qt.rgba(1, 1, 1, 0.08)
  property color glassBorder: Qt.rgba(1, 1, 1, 0.16)

  signal startMessaging()
  signal sendMessageRequested(string text)

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

    /* ShaderEffectSource {
      id: headerBackdrop
      anchors.fill: parent
      sourceItem: messagesArea
      sourceRect: Qt.rect(0, 0, width, height)
      live: true
      hideSource: false
      visible: false
    }

    FastBlur {
      anchors.fill: parent
      source: headerBackdrop
      radius: 32
      opacity: 0.9
    } */

    Rectangle {
      anchors.fill: parent
      z: -1
      color: Qt.rgba(0.10, 0.12, 0.15, 0.86)
      border.color: Qt.rgba(1, 1, 1, 0.14)
      border.width: 1
    }

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

    Rectangle {
      anchors.fill: parent
      z: -1
      color: Theme.windowBackground
    }

      ListView {
        id: messageListView
        z: 5
        clip: true
        anchors.fill: parent
        visible: root.hasConversation
        model: root.messages
        spacing: 6
        topMargin: 12
        bottomMargin: 12

        // Maintain bottom-anchored view so incoming/outgoing messages and status updates keep scroll pinned to bottom
        onCountChanged: {
          Qt.callLater(function() {
            if (messageListView.count > 0)
              messageListView.positionViewAtEnd()
          })
        }

        delegate: Item {
          id: msgDelegate
          width: ListView.view.width
          height: bubble.height + 4

          readonly property bool isOutgoing: Boolean(modelData.outgoing)
          readonly property bool hasReply: modelData.replyText !== undefined && modelData.replyText !== ""

          TextMetrics {
            id: bubbleMetrics
            text: modelData.text || ""
            font: bubbleText.font
          }

          TextMetrics {
            id: metaMetrics
            text: (modelData.time || "") + (msgDelegate.isOutgoing && modelData.status ? (" " + modelData.status) : "")
            font: metaTimeLabel.font
          }

          TextMetrics {
            id: replyMetrics
            text: hasReply ? (modelData.replySender ? (modelData.replySender + ": " + modelData.replyText) : modelData.replyText) : ""
            font: replyContentText.font
          }

          // Desktop capped maximum bubble width (Telegram/iMessage style: ~440px or 68% of screen)
          readonly property real maxBubbleWidth: Math.min(460, parent.width * 0.68)

          // Minimum pill width: replies require at least 210px to ensure preview text isn't cramped/truncated
          readonly property real minBubbleWidth: hasReply ? 210 : (msgDelegate.isOutgoing ? 175 : 160)

          // Natural inline content width calculation
          readonly property real inlineNeededWidth: bubbleMetrics.width + metaMetrics.width + 42
          readonly property real replyNeededWidth: hasReply ? (replyMetrics.width + 44) : 0
          readonly property bool fitsSingleLine: !hasReply && (inlineNeededWidth <= maxBubbleWidth)

          Rectangle {
            id: bubble
            z: 10
            anchors.right: msgDelegate.isOutgoing ? parent.right : undefined
            anchors.left: msgDelegate.isOutgoing ? undefined : parent.left
            anchors.rightMargin: msgDelegate.isOutgoing ? 18 : 0
            anchors.leftMargin: msgDelegate.isOutgoing ? 0 : 18

            // Width: Guaranteed minimum width so reply preview & text have sufficient room
            width: fitsSingleLine
              ? Math.max(minBubbleWidth, inlineNeededWidth)
              : Math.min(maxBubbleWidth, Math.max(minBubbleWidth, Math.max(replyNeededWidth, bubbleMetrics.width + 32)))

            // Height is strictly compact for 1-line messages (~34-36px pill)
            height: fitsSingleLine
              ? 36
              : (bubbleCol.implicitHeight + 14)

            // Modern capsule corners: 16px radius with subtle corner anchor
            topLeftRadius: 16
            topRightRadius: 16
            bottomLeftRadius: msgDelegate.isOutgoing ? 16 : 4
            bottomRightRadius: msgDelegate.isOutgoing ? 4 : 16

            color: msgDelegate.isOutgoing
              ? Qt.rgba(0.30, 0.48, 0.86, 0.72)
              : Qt.rgba(0.18, 0.20, 0.23, 0.76)
            border.width: 1
            border.color: msgDelegate.isOutgoing
              ? Qt.rgba(1, 1, 1, 0.30)
              : Qt.rgba(1, 1, 1, 0.22)

            layer.enabled: true

            // === 1-Line Compact Capsule Mode (Telegram/WhatsApp style) ===
            Item {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 12
              visible: msgDelegate.fitsSingleLine

              Label {
                id: singleLineText
                anchors.left: parent.left
                anchors.right: singleMetaRow.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.text || ""
                color: Theme.primaryText
                font.pixelSize: 15
                elide: Text.ElideNone
              }

              Row {
                id: singleMetaRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Label {
                  text: modelData.time || ""
                  color: Qt.rgba(1, 1, 1, 0.52)
                  font.pixelSize: 11
                }

                Label {
                  text: (msgDelegate.isOutgoing && modelData.status !== "") ? modelData.status : ""
                  color: Qt.rgba(1, 1, 1, 0.65)
                  font.pixelSize: 11
                  visible: text.length > 0
                }
              }
            }

            // === Multi-Line / Reply Message Mode ===
            Column {
              id: bubbleCol
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              anchors.topMargin: 7
              anchors.bottomMargin: 7
              visible: !msgDelegate.fitsSingleLine
              spacing: 4

              // Reply preview bubble block
              Rectangle {
                id: replyContainer
                width: parent.width
                visible: msgDelegate.hasReply
                implicitHeight: replyInnerCol.implicitHeight + 8
                radius: 6
                color: Qt.rgba(0, 0, 0, 0.14)

                Rectangle {
                  id: replyIndicator
                  width: 3
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.margins: 3
                  radius: 1.5
                  color: Qt.rgba(1, 1, 1, 0.75)
                }

                Column {
                  id: replyInnerCol
                  anchors.left: replyIndicator.right
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.leftMargin: 6
                  anchors.rightMargin: 6
                  anchors.topMargin: 4
                  anchors.bottomMargin: 4
                  spacing: 1

                  Label {
                    id: replySenderLabel
                    width: parent.width
                    visible: text.length > 0
                    text: modelData.replySender || (msgDelegate.isOutgoing ? "Reply" : root.chatName)
                    color: Qt.rgba(1, 1, 1, 0.95)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }

                  Label {
                    id: replyContentText
                    width: parent.width
                    text: modelData.replyText || ""
                    color: Qt.rgba(1, 1, 1, 0.70)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }
                }
              }

              Label {
                id: bubbleText
                width: parent.width
                text: modelData.text || ""
                color: Theme.primaryText
                wrapMode: Text.WordWrap
                font.pixelSize: 15
                lineHeight: 1.15
              }

              Row {
                anchors.right: parent.right
                spacing: 3
                visible: (modelData.time !== undefined && modelData.time !== "") || (msgDelegate.isOutgoing && modelData.status !== "")

                Label {
                  id: metaTimeLabel
                  text: modelData.time || ""
                  color: Qt.rgba(1, 1, 1, 0.52)
                  font.pixelSize: 11
                }

                Label {
                  text: (msgDelegate.isOutgoing && modelData.status !== "") ? modelData.status : ""
                  color: Qt.rgba(1, 1, 1, 0.65)
                  font.pixelSize: 11
                  visible: text.length > 0
                }
              }
            }

            DropShadow {
              anchors.fill: parent
              source: bubble
              radius: 12
              samples: 20
              color: Qt.rgba(0, 0, 0, 0.32)
              verticalOffset: 3
              z: -1
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

      Label {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.bottomMargin: 10
        visible: root.typing
        text: "Typing..."
        color: Theme.secondaryText
        font.pixelSize: 13
      }

  }

  // Message composer
  Rectangle {
    id: messageComposer
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.hasConversation ? Math.max(78, Math.min(168, messageInput.implicitHeight + 28)) : 0
    clip: true

      color: "transparent"

    /* ShaderEffectSource {
      id: composerBackdrop
      anchors.fill: parent
      sourceItem: messagesArea
      sourceRect: Qt.rect(0, 0, width, height)
      live: true
      hideSource: false
      visible: false
    }

    FastBlur {
      anchors.fill: parent
      source: composerBackdrop
      radius: 32
      opacity: 0.9
    } */

    Rectangle {
      anchors.fill: parent
      z: -1
      color: Qt.rgba(0.10, 0.12, 0.15, 0.86)
      border.color: Qt.rgba(1, 1, 1, 0.14)
      border.width: 1
    }

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

        TextArea {
          id: messageInput
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(40, Math.min(140, implicitHeight))
          Layout.maximumHeight: 140

          placeholderText: "Write a message..."
          color: Theme.primaryText
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          leftPadding: 18
          rightPadding: 16
          topPadding: 10
          bottomPadding: 10
          Keys.onReturnPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) {
              event.accepted = false
            } else {
              root.sendMessageRequested(text.trim())
              text = ""
              event.accepted = true
            }
          }

          background: Rectangle {
            id: messageInputGlass
            radius: 20
            color: Qt.rgba(0.18, 0.20, 0.23, 0.88)
            border.color: root.glassBorder
            border.width: 1

            layer.enabled: true
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
          onClicked: {
            if (messageInput.text.trim() !== "") {
              root.sendMessageRequested(messageInput.text.trim())
              messageInput.text = ""
            }
          }
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
