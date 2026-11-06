import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
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

  // Active reply target state
  property var activeReply: null // { messageId, sender, text }

  function setReplyTarget(msgId, senderName, previewText) {
    activeReply = {
      messageId: msgId,
      sender: senderName,
      text: previewText
    }
    messageInput.forceActiveFocus()
  }

  function clearReplyTarget() {
    activeReply = null
  }

  function replyTargetName(msgData, isOutgoing) {
    if (!msgData) return ""
    var sender = msgData.replySender
    if (sender && sender !== "" && sender !== "Reply") {
      return sender
    }
    var replyId = msgData.replyToMessageId
    if (replyId && root.messages) {
      for (var i = 0; i < root.messages.length; ++i) {
        var m = root.messages[i]
        if (m.messageId === replyId) {
          return m.outgoing ? "You" : root.chatName
        }
      }
    }
    return isOutgoing ? (root.chatName || "You") : "You"
  }

  function replyPreviewText(msgData) {
    if (!msgData) return ""
    if (msgData.replyText && msgData.replyText !== "") {
      return msgData.replyText
    }
    var replyId = msgData.replyToMessageId
    if (replyId && root.messages) {
      for (var i = 0; i < root.messages.length; ++i) {
        var m = root.messages[i]
        if (m.messageId === replyId) {
          if (m.caption && m.caption.trim() !== "") return m.caption
          if (m.text && m.text.trim() !== "") return m.text
          if (m.mediaType && m.mediaType !== "none") {
            if (m.mediaType === "photo") return "Photo"
            if (m.mediaType === "video") return "Video"
            if (m.mediaType === "animation") return "GIF"
            if (m.mediaType === "audio") return "Audio"
            if (m.mediaType === "document") return m.fileName || "Document"
          }
        }
      }
    }
    return ""
  }

  signal startMessaging()
  signal sendMessageRequested(string text, var replyToMessageId, string quoteText)
  signal sendMediaRequested(string filePath, string caption, var replyToMessageId, string quoteText)

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
      color: "transparent"
      border.color: "transparent"
      border.width: 0
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
          readonly property bool hasReply: (modelData.replyToMessageId && modelData.replyToMessageId > 0) || (modelData.replyText !== undefined && modelData.replyText !== "")
          readonly property bool hasMedia: modelData.mediaType !== undefined && modelData.mediaType !== "none" && modelData.mediaType !== ""
          readonly property bool isVisualMedia: modelData.mediaType === "photo" || modelData.mediaType === "video" || modelData.mediaType === "animation"
          readonly property bool isPhoto: modelData.mediaType === "photo"
          readonly property bool isVideo: modelData.mediaType === "video"
          readonly property bool isAnimation: modelData.mediaType === "animation"
          readonly property bool isDoc: modelData.mediaType === "document" || modelData.mediaType === "audio"
          readonly property bool hasCaption: Boolean(modelData.caption && modelData.caption.trim().length > 0)
          readonly property bool isBorderlessMedia: isVisualMedia && !hasCaption && !hasReply

          // Target dimensions for photos and videos based on aspect ratio
          readonly property real targetMediaWidth: {
            if (!isVisualMedia) return 0
            var maxW = Math.min(380, parent.width * 0.68)
            var minW = 220
            var w = modelData.mediaWidth || 0
            var h = modelData.mediaHeight || 0
            if (w <= 0 || h <= 0) {
              if (borderlessImage.implicitWidth > 0 && borderlessImage.implicitHeight > 0) {
                w = borderlessImage.implicitWidth
                h = borderlessImage.implicitHeight
              } else if (captionedImage.implicitWidth > 0 && captionedImage.implicitHeight > 0) {
                w = captionedImage.implicitWidth
                h = captionedImage.implicitHeight
              }
            }
            if (w > 0 && h > 0) {
              var ratio = w / h
              if (ratio >= 1.0) {
                return Math.max(minW, Math.min(maxW, 280 * ratio))
              } else {
                var targetH = Math.min(340, 280 / ratio)
                return Math.max(minW, Math.min(maxW, targetH * ratio))
              }
            }
            return 320
          }

          readonly property real targetMediaHeight: {
            if (!isVisualMedia) return 0
            var maxH = 360
            var minH = 160
            var w = modelData.mediaWidth || 0
            var h = modelData.mediaHeight || 0
            if (w <= 0 || h <= 0) {
              if (borderlessImage.implicitWidth > 0 && borderlessImage.implicitHeight > 0) {
                w = borderlessImage.implicitWidth
                h = borderlessImage.implicitHeight
              } else if (captionedImage.implicitWidth > 0 && captionedImage.implicitHeight > 0) {
                w = captionedImage.implicitWidth
                h = captionedImage.implicitHeight
              }
            }
            if (w > 0 && h > 0) {
              var ratio = w / h
              return Math.max(minH, Math.min(maxH, targetMediaWidth / ratio))
            }
            return 220
          }

          TextMetrics {
            id: bubbleMetrics
            text: modelData.caption ? modelData.caption : (modelData.text || "")
            font: bubbleText.font
          }

          TextMetrics {
            id: metaMetrics
            text: (modelData.time || "") + (msgDelegate.isOutgoing && modelData.status ? (" " + modelData.status) : "")
            font: metaTimeLabel.font
          }

          TextMetrics {
            id: replyContentMetrics
            text: hasReply ? root.replyPreviewText(modelData) : ""
            font: replyContentText.font
          }

          TextMetrics {
            id: replySenderMetrics
            text: hasReply ? root.replyTargetName(modelData, msgDelegate.isOutgoing) : ""
            font: replySenderLabel.font
          }

          // Desktop capped maximum bubble width (Telegram/iMessage style: ~440px or 68% of screen)
          readonly property real maxBubbleWidth: Math.min(460, parent.width * 0.68)

          // Natural inline content width calculation
          readonly property real inlineNeededWidth: bubbleMetrics.width + metaMetrics.width + 42
          readonly property real replyNeededWidth: hasReply ? (Math.max(replyContentMetrics.width, replySenderMetrics.width) + 38) : 0
          readonly property real textNeededWidth: bubbleMetrics.width + 36

          // The component size takes whichever component is bigger:
          // 1) visual media width (if message has image/video/gif)
          // 2) replied target length (if message has a reply)
          // 3) message text / caption length (+ metadata timestamps)
          readonly property real naturalContentWidth: {
            var w = Math.max(inlineNeededWidth, textNeededWidth)
            if (hasReply) {
              w = Math.max(w, replyNeededWidth)
            }
            if (isVisualMedia) {
              w = Math.max(w, targetMediaWidth)
            }
            if (isDoc) {
              w = Math.max(w, 260)
            }
            return w
          }

          // Minimum pill width: base baseline width so compact bubbles don't collapse
          readonly property real minBubbleWidth: isVisualMedia ? targetMediaWidth : (isDoc ? 260 : (hasReply ? 200 : (msgDelegate.isOutgoing ? 175 : 160)))

          readonly property bool fitsSingleLine: !hasMedia && !hasReply && (inlineNeededWidth <= maxBubbleWidth)

          Rectangle {
            id: bubble
            z: 10
            anchors.right: msgDelegate.isOutgoing ? parent.right : undefined
            anchors.left: msgDelegate.isOutgoing ? undefined : parent.left
            anchors.rightMargin: msgDelegate.isOutgoing ? 18 : 0
            anchors.leftMargin: msgDelegate.isOutgoing ? 0 : 18

            // Width: length is set to the bigger size of the components (reply target, message text, or media)
            width: isBorderlessMedia
              ? targetMediaWidth
              : Math.min(maxBubbleWidth, Math.max(minBubbleWidth, naturalContentWidth))

            // Height
            height: isBorderlessMedia
              ? targetMediaHeight
              : (fitsSingleLine
                  ? 36
                  : (bubbleCol.implicitHeight + (isVisualMedia ? 0 : 14)))

            // Modern capsule corners: 16px radius with subtle corner anchor
            // Visual borderless media always uses uniform 16px radius on all 4 corners
            topLeftRadius: 16
            topRightRadius: 16
            bottomLeftRadius: isBorderlessMedia ? 16 : (msgDelegate.isOutgoing ? 16 : 4)
            bottomRightRadius: isBorderlessMedia ? 16 : (msgDelegate.isOutgoing ? 4 : 16)

            color: isBorderlessMedia
              ? "transparent"
              : (msgDelegate.isOutgoing
                  ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.88)
                  : Theme.elevatedBackground)
            border.width: isBorderlessMedia ? 0 : 1
            border.color: msgDelegate.isOutgoing ? Qt.lighter(Theme.accent, 1.18) : Theme.divider
            clip: isBorderlessMedia

            layer.enabled: !isBorderlessMedia

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
                  color: Theme.secondaryText
                  font.pixelSize: 11
                }

                Label {
                  text: (msgDelegate.isOutgoing && modelData.status !== "") ? modelData.status : ""
                  color: Theme.primaryText
                  font.pixelSize: 11
                  visible: text.length > 0
                }
              }
            }

            // === Borderless Media Mode (No caption, no reply) ===
            Item {
              anchors.fill: parent
              visible: msgDelegate.isBorderlessMedia

              Item {
                id: borderlessMediaBox
                anchors.fill: parent

                Image {
                  id: borderlessImage
                  anchors.fill: parent
                  source: (modelData.filePath && modelData.filePath !== "" && !msgDelegate.isAnimation) ? ("file://" + modelData.filePath) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true
                  visible: false
                }

                AnimatedImage {
                  id: borderlessGif
                  anchors.fill: parent
                  source: (modelData.filePath && modelData.filePath !== "" && msgDelegate.isAnimation) ? ("file://" + modelData.filePath) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true
                  visible: false

                  property int remainingLoops: 3

                  onFrameChanged: {
                    if (frameCount > 1 && currentFrame === frameCount - 1) {
                      remainingLoops--
                      if (remainingLoops <= 0) {
                        paused = true
                      }
                    }
                  }
                }

                Rectangle {
                  id: borderlessPlaceholder
                  anchors.fill: parent
                  radius: 16
                  color: Qt.darker(Theme.controlBackground, 1.25)
                  visible: msgDelegate.isAnimation ? (borderlessGif.status !== AnimatedImage.Ready) : (borderlessImage.status !== Image.Ready)
                }

                Rectangle {
                  id: borderlessMask
                  anchors.fill: parent
                  radius: 16
                  color: "white"
                  visible: false
                }

                OpacityMask {
                  anchors.fill: parent
                  source: msgDelegate.isAnimation ? borderlessGif : borderlessImage
                  maskSource: borderlessMask
                  visible: msgDelegate.isAnimation ? (borderlessGif.status === AnimatedImage.Ready) : (borderlessImage.status === Image.Ready)
                }

                // Downloading / Loading state
                Column {
                  anchors.centerIn: parent
                  visible: msgDelegate.isAnimation ? (borderlessGif.status !== AnimatedImage.Ready) : (borderlessImage.status !== Image.Ready)
                  spacing: 6

                  Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(0, 0, 0, 0.45)
                    visible: modelData.isDownloading || !modelData.filePath

                    BusyIndicator {
                      anchors.centerIn: parent
                      running: modelData.isDownloading || !modelData.filePath
                      width: 28
                      height: 28
                    }
                  }

                  Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.isDownloading ? "Downloading..." : ""
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    visible: text.length > 0
                  }
                }

                // Play icon for video
                Rectangle {
                  anchors.centerIn: parent
                  width: 44
                  height: 44
                  radius: 22
                  color: Qt.rgba(0, 0, 0, 0.52)
                  visible: msgDelegate.isVideo && borderlessImage.visible

                  Label {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1
                    text: "▶"
                    color: "#FFFFFF"
                    font.pixelSize: 16
                  }
                }

                // GIF Badge (top-left) - Clickable to restart GIF playback
                Rectangle {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.margins: 8
                  radius: 4
                  height: 18
                  width: gifRow1.implicitWidth + 8
                  color: borderlessGif.paused ? Theme.accent : Qt.rgba(0, 0, 0, 0.55)
                  visible: msgDelegate.isAnimation

                  Row {
                    id: gifRow1
                    anchors.centerIn: parent
                    spacing: 3

                    Label {
                      text: borderlessGif.paused ? "▶" : ""
                      color: "#FFFFFF"
                      font.pixelSize: 8
                      visible: borderlessGif.paused
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                      id: gifText1
                      text: "GIF"
                      color: "#FFFFFF"
                      font.pixelSize: 10
                      font.weight: Font.Bold
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      borderlessGif.remainingLoops = 3
                      borderlessGif.paused = false
                    }
                  }
                }

                // Video Duration Badge (top-left)
                Rectangle {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.margins: 8
                  radius: 4
                  height: 18
                  width: durText1.implicitWidth + 8
                  color: Qt.rgba(0, 0, 0, 0.55)
                  visible: msgDelegate.isVideo && modelData.duration > 0

                  Label {
                    id: durText1
                    function formatDur(sec) {
                      var m = Math.floor(sec / 60)
                      var s = sec % 60
                      return m + ":" + (s < 10 ? "0" : "") + s
                    }
                    anchors.centerIn: parent
                    text: formatDur(modelData.duration)
                    color: "#FFFFFF"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                  }
                }

                // Floating Time & Status Pill (bottom-right)
                Rectangle {
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.margins: 8
                  radius: 10
                  height: 20
                  width: floatingMetaRow1.implicitWidth + 12
                  color: Qt.rgba(0, 0, 0, 0.5)

                  Row {
                    id: floatingMetaRow1
                    anchors.centerIn: parent
                    spacing: 4

                    Label {
                      text: modelData.time || ""
                      color: "#FFFFFF"
                      font.pixelSize: 11
                    }

                    Label {
                      text: (msgDelegate.isOutgoing && modelData.status !== "") ? modelData.status : ""
                      color: "#FFFFFF"
                      font.pixelSize: 11
                      visible: text.length > 0
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.filePath && modelData.filePath !== "") {
                      mediaViewer.show(modelData.filePath, msgDelegate.isVideo ? "video" : (msgDelegate.isAnimation ? "animation" : "photo"))
                    }
                  }
                }
              }
            }

            // === Multi-Line / Reply / Document / Captioned Media Mode ===
            Column {
              id: bubbleCol
              anchors.fill: parent
              anchors.leftMargin: msgDelegate.isVisualMedia ? 0 : 12
              anchors.rightMargin: msgDelegate.isVisualMedia ? 0 : 12
              anchors.topMargin: msgDelegate.isVisualMedia ? 0 : 7
              anchors.bottomMargin: 7
              visible: !msgDelegate.fitsSingleLine && !msgDelegate.isBorderlessMedia
              spacing: 6

              // Reply preview bubble block
              Rectangle {
                id: replyContainer
                width: parent.width - (msgDelegate.isVisualMedia ? 16 : 0)
                anchors.horizontalCenter: msgDelegate.isVisualMedia ? parent.horizontalCenter : undefined
                visible: msgDelegate.hasReply
                implicitHeight: replyInnerCol.implicitHeight + 8
                radius: 6
                color: Qt.darker(Theme.elevatedBackground, 1.18)

                Rectangle {
                  id: replyIndicator
                  width: 3
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.margins: 3
                  radius: 1.5
                  color: Theme.accent
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
                    text: root.replyTargetName(modelData, msgDelegate.isOutgoing)
                    color: Theme.primaryText
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }

                  Label {
                    id: replyContentText
                    width: parent.width
                    text: root.replyPreviewText(modelData)
                    color: Theme.secondaryText
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }
                }
              }

              // Visual Media with Caption (Photo / Video / GIF)
              Item {
                id: captionedMediaBox
                width: parent.width
                height: msgDelegate.targetMediaHeight
                visible: msgDelegate.isVisualMedia

                Image {
                  id: captionedImage
                  anchors.fill: parent
                  source: (modelData.filePath && modelData.filePath !== "" && !msgDelegate.isAnimation) ? ("file://" + modelData.filePath) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true
                  visible: false
                }

                AnimatedImage {
                  id: captionedGif
                  anchors.fill: parent
                  source: (modelData.filePath && modelData.filePath !== "" && msgDelegate.isAnimation) ? ("file://" + modelData.filePath) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true
                  visible: false

                  property int remainingLoops: 3

                  onFrameChanged: {
                    if (frameCount > 1 && currentFrame === frameCount - 1) {
                      remainingLoops--
                      if (remainingLoops <= 0) {
                        paused = true
                      }
                    }
                  }
                }

                Rectangle {
                  id: captionedPlaceholder
                  anchors.fill: parent
                  topLeftRadius: 16
                  topRightRadius: 16
                  bottomLeftRadius: 0
                  bottomRightRadius: 0
                  color: Qt.darker(Theme.controlBackground, 1.25)
                  visible: msgDelegate.isAnimation ? (captionedGif.status !== AnimatedImage.Ready) : (captionedImage.status !== Image.Ready)
                }

                Rectangle {
                  id: captionedMask
                  anchors.fill: parent
                  topLeftRadius: 16
                  topRightRadius: 16
                  bottomLeftRadius: 0
                  bottomRightRadius: 0
                  color: "white"
                  visible: false
                }

                OpacityMask {
                  anchors.fill: parent
                  source: msgDelegate.isAnimation ? captionedGif : captionedImage
                  maskSource: captionedMask
                  visible: msgDelegate.isAnimation ? (captionedGif.status === AnimatedImage.Ready) : (captionedImage.status === Image.Ready)
                }

                // Downloading state
                Column {
                  anchors.centerIn: parent
                  visible: msgDelegate.isAnimation ? (captionedGif.status !== AnimatedImage.Ready) : (captionedImage.status !== Image.Ready)
                  spacing: 6

                  Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(0, 0, 0, 0.45)
                    visible: modelData.isDownloading || !modelData.filePath

                    BusyIndicator {
                      anchors.centerIn: parent
                      running: modelData.isDownloading || !modelData.filePath
                      width: 28
                      height: 28
                    }
                  }

                  Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.isDownloading ? "Downloading..." : ""
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    visible: text.length > 0
                  }
                }

                // Play icon for video
                Rectangle {
                  anchors.centerIn: parent
                  width: 44
                  height: 44
                  radius: 22
                  color: Qt.rgba(0, 0, 0, 0.52)
                  visible: msgDelegate.isVideo && captionedImage.visible

                  Label {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1
                    text: "▶"
                    color: "#FFFFFF"
                    font.pixelSize: 16
                  }
                }

                // GIF Badge (top-left) - Clickable to restart GIF playback
                Rectangle {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.margins: 8
                  radius: 4
                  height: 18
                  width: gifRow2.implicitWidth + 8
                  color: captionedGif.paused ? Theme.accent : Qt.rgba(0, 0, 0, 0.55)
                  visible: msgDelegate.isAnimation

                  Row {
                    id: gifRow2
                    anchors.centerIn: parent
                    spacing: 3

                    Label {
                      text: captionedGif.paused ? "▶" : ""
                      color: "#FFFFFF"
                      font.pixelSize: 8
                      visible: captionedGif.paused
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                      id: gifText2
                      text: "GIF"
                      color: "#FFFFFF"
                      font.pixelSize: 10
                      font.weight: Font.Bold
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      captionedGif.remainingLoops = 3
                      captionedGif.paused = false
                    }
                  }
                }

                // Video Duration Badge
                Rectangle {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.margins: 8
                  radius: 4
                  height: 18
                  width: durText2.implicitWidth + 8
                  color: Qt.rgba(0, 0, 0, 0.55)
                  visible: msgDelegate.isVideo && modelData.duration > 0

                  Label {
                    id: durText2
                    function formatDur(sec) {
                      var m = Math.floor(sec / 60)
                      var s = sec % 60
                      return m + ":" + (s < 10 ? "0" : "") + s
                    }
                    anchors.centerIn: parent
                    text: formatDur(modelData.duration)
                    color: "#FFFFFF"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.filePath && modelData.filePath !== "") {
                      mediaViewer.show(modelData.filePath, msgDelegate.isVideo ? "video" : (msgDelegate.isAnimation ? "animation" : "photo"))
                    }
                  }
                }
              }

              // Document / File block
              Rectangle {
                id: docBox
                width: parent.width
                implicitHeight: 52
                radius: 10
                color: Qt.darker(Theme.controlBackground, 1.15)
                visible: msgDelegate.isDoc

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 10

                  Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: Theme.accent

                    Label {
                      anchors.centerIn: parent
                      text: "📄"
                      font.pixelSize: 18
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                      Layout.fillWidth: true
                      text: modelData.fileName || "Document"
                      color: Theme.primaryText
                      font.pixelSize: 13
                      font.weight: Font.Medium
                      elide: Text.ElideMiddle
                    }

                    Label {
                      function formatSize(bytes) {
                        if (!bytes || bytes <= 0) return ""
                        if (bytes < 1024) return bytes + " B"
                        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
                        return (bytes / 1048576).toFixed(1) + " MB"
                      }
                      text: (modelData.isDownloading ? "Downloading • " : (modelData.filePath ? "Downloaded • " : "")) + formatSize(modelData.fileSize)
                      color: Theme.secondaryText
                      font.pixelSize: 11
                    }
                  }
                }
              }

              // Text / Caption Label
              Label {
                id: bubbleText
                width: parent.width - (msgDelegate.isVisualMedia ? 20 : 0)
                anchors.horizontalCenter: msgDelegate.isVisualMedia ? parent.horizontalCenter : undefined
                visible: text.length > 0 && !(msgDelegate.isPhoto && text === "Photo") && !(msgDelegate.isDoc && text === "Document")
                text: modelData.caption ? modelData.caption : (modelData.text || "")
                color: Theme.primaryText
                wrapMode: Text.WordWrap
                font.pixelSize: 15
                lineHeight: 1.15
              }

              Row {
                anchors.right: parent.right
                anchors.rightMargin: msgDelegate.isVisualMedia ? 10 : 0
                spacing: 3
                visible: (modelData.time !== undefined && modelData.time !== "") || (msgDelegate.isOutgoing && modelData.status !== "")

                Label {
                  id: metaTimeLabel
                  text: modelData.time || ""
                  color: Theme.secondaryText
                  font.pixelSize: 11
                }

                Label {
                  text: (msgDelegate.isOutgoing && modelData.status !== "") ? modelData.status : ""
                  color: Theme.primaryText
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
              visible: !msgDelegate.isBorderlessMedia
            }

            // Click & Context menu trigger for message bubble
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              z: 20
              cursorShape: Qt.ArrowCursor
              onClicked: function(mouse) {
                var bubbleContentText = modelData.caption ? modelData.caption : (modelData.text || "")
                var senderName = msgDelegate.isOutgoing ? "You" : root.chatName
                messageContextMenu.targetMessageId = modelData.messageId || 0
                messageContextMenu.targetSender = senderName
                messageContextMenu.textToCopy = bubbleContentText
                messageContextMenu.mediaPathToCopy = (modelData.filePath && modelData.filePath !== "") ? modelData.filePath : ""

                if (mouse.button === Qt.RightButton) {
                  messageContextMenu.popup()
                } else if (mouse.button === Qt.LeftButton) {
                  // Left-click on message bubble also presents options to reply or act
                  messageContextMenu.popup()
                }
              }
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
    height: root.hasConversation ? (composerCol.implicitHeight + 20) : 0
    clip: true

    color: "transparent"

    Rectangle {
      anchors.fill: parent
      z: -1
      color: "transparent"
      border.color: "transparent"
      border.width: 0
    }

    ColumnLayout {
      id: composerCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      anchors.bottomMargin: 10
      spacing: 6

      // Reply preview banner shown directly above the input box
      Rectangle {
        id: composerReplyBanner
        Layout.fillWidth: true
        implicitHeight: root.activeReply ? 42 : 0
        visible: root.activeReply !== null
        radius: 8
        color: Qt.darker(Theme.elevatedBackground, 1.15)
        border.color: Theme.divider
        border.width: 1
        clip: true

        RowLayout {
          anchors.fill: parent
          anchors.margins: 6
          spacing: 10

          Rectangle {
            Layout.preferredWidth: 3
            Layout.fillHeight: true
            radius: 1.5
            color: Theme.accent
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Label {
              text: root.activeReply ? root.activeReply.sender : ""
              color: Theme.accent
              font.pixelSize: 12
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }

            Label {
              text: root.activeReply ? root.activeReply.text : ""
              color: Theme.primaryText
              font.pixelSize: 12
              elide: Text.ElideRight
            }
          }

          ToolButton {
            text: "✕"
            font.pixelSize: 12
            implicitWidth: 26
            implicitHeight: 26
            focusPolicy: Qt.NoFocus
            onClicked: root.clearReplyTarget()
            background: Rectangle {
              radius: 13
              color: parent.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            }
          }
        }
      }

      // Input row
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ToolButton {
          text: "+"
          font.pixelSize: 25
          focusPolicy: Qt.NoFocus
          padding: 8
          implicitWidth: 40
          implicitHeight: 40
          onClicked: fileDialog.open()
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
              if (text.trim() !== "") {
                var replyId = (root.activeReply && root.activeReply.messageId) ? root.activeReply.messageId : 0
                var quoteText = (root.activeReply && root.activeReply.text) ? root.activeReply.text : ""
                root.sendMessageRequested(text.trim(), replyId, quoteText)
                root.clearReplyTarget()
                text = ""
              }
              event.accepted = true
            }
          }

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape && root.activeReply !== null) {
              root.clearReplyTarget()
              event.accepted = true
              return
            }
            if ((event.key === Qt.Key_V) && (event.modifiers & Qt.ControlModifier)) {
              if (appController.clipboardHasImage() || appController.clipboardHasFiles()) {
                var pastedPath = appController.getClipboardFilePath()
                if (pastedPath && pastedPath !== "") {
                  pastePreviewModal.show(pastedPath)
                  event.accepted = true
                  return
                }
              }
            }
            event.accepted = false
          }

          background: Rectangle {
            id: messageInputGlass
            radius: 20
            color: Theme.controlBackground
            border.color: Theme.divider
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
              var replyId = (root.activeReply && root.activeReply.messageId) ? root.activeReply.messageId : 0
              var quoteText = (root.activeReply && root.activeReply.text) ? root.activeReply.text : ""
              root.sendMessageRequested(messageInput.text.trim(), replyId, quoteText)
              root.clearReplyTarget()
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
  }

  FileDialog {
    id: fileDialog
    title: "Select file to send"
    currentFolder: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0] || ""
    onAccepted: {
      var path = fileDialog.selectedFile.toString()
      // Remove file:// prefix if present
      if (path.indexOf("file://") === 0) {
        path = path.substring(7)
      }
      var caption = messageInput.text.trim()
      messageInput.text = ""
      var replyId = (root.activeReply && root.activeReply.messageId) ? root.activeReply.messageId : 0
      var quoteText = (root.activeReply && root.activeReply.text) ? root.activeReply.text : ""
      root.sendMediaRequested(path, caption, replyId, quoteText)
      root.clearReplyTarget()
    }
  }

  // Right-click Message Context Menu
  Menu {
    id: messageContextMenu

    property var targetMessageId: 0
    property string targetSender: ""
    property string textToCopy: ""
    property string mediaPathToCopy: ""
    property bool canCopyText: textToCopy.trim() !== ""
    property bool canCopyMedia: mediaPathToCopy !== ""

    background: Rectangle {
      implicitWidth: 168
      color: Theme.elevatedBackground
      radius: 8
      border.color: Theme.divider
      border.width: 1
    }

    MenuItem {
      text: "Reply"
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
        radius: 4
      }
      onTriggered: {
        root.setReplyTarget(messageContextMenu.targetMessageId, messageContextMenu.targetSender, messageContextMenu.textToCopy)
      }
    }

    MenuItem {
      text: "Copy Text"
      visible: messageContextMenu.canCopyText
      height: visible ? implicitHeight : 0
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
        radius: 4
      }
      onTriggered: {
        appController.copyText(messageContextMenu.textToCopy)
      }
    }

    MenuItem {
      text: "Copy Media"
      visible: messageContextMenu.canCopyMedia
      height: visible ? implicitHeight : 0
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
        radius: 4
      }
      onTriggered: {
        appController.copyImage(messageContextMenu.mediaPathToCopy)
      }
    }
  }

  // Paste Image / Attachment Preview Confirmation Modal
  Rectangle {
    id: pastePreviewModal
    anchors.fill: parent
    z: 95
    visible: opacity > 0
    opacity: 0
    color: Qt.rgba(0, 0, 0, 0.72)

    Behavior on opacity {
      NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
    }

    property string pendingFilePath: ""

    function show(filePath) {
      pendingFilePath = filePath
      pasteCaptionInput.text = ""
      opacity = 1
      pasteCaptionInput.forceActiveFocus()
    }

    function hide() {
      opacity = 0
      pendingFilePath = ""
      pasteCaptionInput.text = ""
      messageInput.forceActiveFocus()
    }

    function sendPendingMedia() {
      if (pendingFilePath !== "") {
        var replyId = (root.activeReply && root.activeReply.messageId) ? root.activeReply.messageId : 0
        var quoteText = (root.activeReply && root.activeReply.text) ? root.activeReply.text : ""
        root.sendMediaRequested(pendingFilePath, pasteCaptionInput.text.trim(), replyId, quoteText)
        root.clearReplyTarget()
        hide()
      }
    }

    // Modal Card
    Rectangle {
      anchors.centerIn: parent
      width: Math.min(parent.width - 48, 420)
      height: pasteModalCol.implicitHeight + 36
      radius: 16
      color: Theme.elevatedBackground
      border.color: Theme.divider
      border.width: 1

      ColumnLayout {
        id: pasteModalCol
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
          Layout.fillWidth: true

          Label {
            text: "Send Image"
            color: Theme.primaryText
            font.pixelSize: 16
            font.weight: Font.DemiBold
            Layout.fillWidth: true
          }

          ToolButton {
            text: "✕"
            font.pixelSize: 14
            implicitWidth: 28
            implicitHeight: 28
            focusPolicy: Qt.NoFocus
            onClicked: pastePreviewModal.hide()
            background: Rectangle {
              radius: 14
              color: parent.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 220
          radius: 10
          clip: true
          color: Qt.darker(Theme.controlBackground, 1.2)

          Image {
            anchors.fill: parent
            source: pastePreviewModal.pendingFilePath !== "" ? ("file://" + pastePreviewModal.pendingFilePath) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
          }
        }

        TextField {
          id: pasteCaptionInput
          Layout.fillWidth: true
          placeholderText: "Add a caption..."
          color: Theme.primaryText
          font.pixelSize: 14
          background: Rectangle {
            radius: 8
            color: Theme.controlBackground
            border.color: Theme.divider
            border.width: 1
          }
          Keys.onReturnPressed: function(event) {
            pastePreviewModal.sendPendingMedia()
            event.accepted = true
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Item { Layout.fillWidth: true }

          Button {
            text: "Cancel"
            implicitHeight: 34
            onClicked: pastePreviewModal.hide()
            contentItem: Label {
              text: parent.text
              color: Theme.primaryText
              font.pixelSize: 13
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
              radius: 6
              color: parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            }
          }

          Button {
            text: "Send"
            implicitHeight: 34
            highlighted: true
            onClicked: pastePreviewModal.sendPendingMedia()
            contentItem: Label {
              text: parent.text
              color: "#FFFFFF"
              font.pixelSize: 13
              font.weight: Font.Medium
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
              radius: 6
              color: parent.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
            }
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      z: -1
      onClicked: pastePreviewModal.hide()
    }
  }

  // Full-Screen / Lightbox Media Viewer Modal
  Rectangle {
    id: mediaViewer
    z: 100
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    color: Qt.rgba(0, 0, 0, 0.88)

    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    property string mediaPath: ""
    property string mediaType: ""

    function show(path, type) {
      mediaPath = path
      mediaType = type
      if (type === "animation") {
        viewerGif.remainingLoops = 3
        viewerGif.currentFrame = 0
        viewerGif.paused = false
      }
      opacity = 1
    }

    function hide() {
      opacity = 0
      mediaPath = ""
      mediaType = ""
    }

    // Top action bar
    RowLayout {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 16
      z: 2

      Item { Layout.fillWidth: true }

      ToolButton {
        text: "✕"
        font.pixelSize: 18
        implicitWidth: 36
        implicitHeight: 36
        focusPolicy: Qt.NoFocus
        onClicked: mediaViewer.hide()
        background: Rectangle {
          radius: 18
          color: parent.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.4)
        }
      }
    }

    // Center Image/GIF preview with zoom/pan support
    Item {
      anchors.fill: parent
      anchors.margins: 40

      Image {
        id: viewerImage
        anchors.centerIn: parent
        width: Math.min(parent.width, implicitWidth > 0 ? implicitWidth : parent.width)
        height: Math.min(parent.height, implicitHeight > 0 ? implicitHeight : parent.height)
        source: (mediaViewer.mediaType !== "animation" && mediaViewer.mediaPath && mediaViewer.mediaPath !== "") ? ("file://" + mediaViewer.mediaPath) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        visible: mediaViewer.mediaType !== "animation"
      }

      AnimatedImage {
        id: viewerGif
        anchors.centerIn: parent
        width: Math.min(parent.width, implicitWidth > 0 ? implicitWidth : parent.width)
        height: Math.min(parent.height, implicitHeight > 0 ? implicitHeight : parent.height)
        source: (mediaViewer.mediaType === "animation" && mediaViewer.mediaPath && mediaViewer.mediaPath !== "") ? ("file://" + mediaViewer.mediaPath) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        visible: mediaViewer.mediaType === "animation"

        property int remainingLoops: 3

        onFrameChanged: {
          if (frameCount > 1 && currentFrame === frameCount - 1) {
            remainingLoops--
            if (remainingLoops <= 0) {
              paused = true
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            viewerGif.remainingLoops = 3
            viewerGif.currentFrame = 0
            viewerGif.paused = false
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      z: -1
      onClicked: mediaViewer.hide()
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
