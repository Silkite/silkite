import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Qt5Compat.GraphicalEffects

Item {
  id: root

  property var chatId: 0
  property string chatName: ""
  property string chatInitials: "?"
  property string avatarColor: "#526C8A"
  property string avatarPath: ""
  property string lastMessage: ""
  property string statusText: ""
  property bool isOnline: false
  property var messages: []
  property var messageModel: null
  property bool typing: false

  // Pill notification button tracking unread/new messages arriving while scrolled up
  property int unreadIncomingCount: 0
  property int previousMessageCount: 0
  property var previousChatId: 0
  property bool pendingScrollToBottom: false
  property bool bottomScrollScheduled: false
  property bool lastKnownAtBottom: true

  function isScrolledToBottom() {
    if (messageListView.count === 0) return true
    if (messageListView.contentHeight <= messageListView.height) return true
    var maxScrollY = messageListView.originY + messageListView.contentHeight - messageListView.height + messageListView.bottomMargin
    return Math.abs(messageListView.contentY - maxScrollY) <= 48 || messageListView.atYEnd
  }

  function scrollToBottomSmoothly() {
    unreadIncomingCount = 0
    if (messageListView.count === 0) return
    lastKnownAtBottom = true
    messageListView.positionViewAtEnd()
  }

  function scheduleBottomScroll(animated) {
    if (messageListView.count === 0) return
    lastKnownAtBottom = true
    messageScrollAnim.stop()
    messageListView.positionViewAtEnd()
    // Run across multiple event loops to ensure initial delegate layouts are finished
    Qt.callLater(function() {
      if (messageListView.count > 0 && lastKnownAtBottom) {
        messageListView.positionViewAtEnd()
        Qt.callLater(function() {
          if (messageListView.count > 0 && lastKnownAtBottom) {
            messageListView.positionViewAtEnd()
          }
        })
      }
    })
  }

  onChatIdChanged: {
    if (chatId !== previousChatId) {
      previousChatId = chatId
      unreadIncomingCount = 0
      previousMessageCount = 0
      pendingScrollToBottom = false
      bottomScrollScheduled = false
      lastKnownAtBottom = true
      messageScrollAnim.stop()
      scheduleBottomScroll(false)
    }
  }

  onMessagesChanged: {
    if (!messageModel) {
      // Fallback if using array model
      var newCount = messages ? messages.length : 0
      if (newCount > previousMessageCount) {
        var lastMsg = (messages && messages.length > 0) ? messages[messages.length - 1] : null
        handleNewMessage(lastMsg)
      }
      previousMessageCount = newCount
    }
  }

  function handleNewMessage(msg) {
    var atBottom = lastKnownAtBottom && isScrolledToBottom()
    var isOutgoing = Boolean(msg && msg.outgoing)

    if (atBottom) {
      unreadIncomingCount = 0
      scheduleBottomScroll(true)
    } else {
      // User is scrolled up (arrow is visible):
      // - Do NOT scroll down
      // - Increment badge ONLY for incoming messages, ignoring outgoing messages
      if (!isOutgoing) {
        unreadIncomingCount++
      }
    }
  }

  Connections {
    target: root.messageModel
    function onMessagesLoaded() {
      // When history is loaded or reloaded for a conversation, ensure we position at the bottom
      lastKnownAtBottom = true
      unreadIncomingCount = 0
      root.scheduleBottomScroll(false)
    }
    function onMessageAdded(message) {
      root.handleNewMessage(message)
    }
    function onCountChanged() {
      // Handled primarily via messageAdded, but keep count sync
      previousMessageCount = root.messageModel ? root.messageModel.count : 0
    }
  }

  property bool hasConversation: chatName !== ""
  property string appVersion: ""
  property color glassColor: Qt.rgba(1, 1, 1, 0.08)
  property color glassBorder: Qt.rgba(1, 1, 1, 0.16)

  // Active reply target state
  property var activeReply: null // { messageId, sender, text }

  // Reaction picker popup state
  property var activeReactionMessageId: 0
  property real reactionPickerX: 0
  property real reactionPickerY: 0
  property bool reactionPickerVisible: false

  function openReactionPicker(msgId, globalPos, isOutgoing, bubbleWidth) {
    activeReactionMessageId = msgId
    var pos = messagesArea.mapFromItem(null, globalPos.x, globalPos.y)
    var pickerW = 224
    var pickerH = 46
    if (isOutgoing) {
      reactionPickerX = Math.max(8, pos.x - pickerW - 8)
    } else {
      reactionPickerX = Math.min(messagesArea.width - pickerW - 8, pos.x + bubbleWidth + 8)
    }
    reactionPickerY = Math.max(8, Math.min(messagesArea.height - pickerH - 8, pos.y - 6))
    reactionPickerVisible = true
  }

  function closeReactionPicker() {
    reactionPickerVisible = false
    activeReactionMessageId = 0
  }

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
    if (replyId) {
      if (root.messageModel) {
        var mTarget = root.messageModel.getByMessageId(replyId)
        if (mTarget && mTarget.messageId) {
          return mTarget.outgoing ? "You" : root.chatName
        }
      } else if (root.messages) {
        for (var i = 0; i < root.messages.length; ++i) {
          var m = root.messages[i]
          if (m.messageId === replyId) {
            return m.outgoing ? "You" : root.chatName
          }
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
    if (replyId) {
      var targetMsg = null
      if (root.messageModel) {
        var found = root.messageModel.getByMessageId(replyId)
        if (found && found.messageId) targetMsg = found
      } else if (root.messages) {
        for (var i = 0; i < root.messages.length; ++i) {
          if (root.messages[i].messageId === replyId) {
            targetMsg = root.messages[i]
            break
          }
        }
      }
      if (targetMsg) {
        if (targetMsg.caption && targetMsg.caption.trim() !== "") return targetMsg.caption
        if (targetMsg.text && targetMsg.text.trim() !== "") return targetMsg.text
        if (targetMsg.mediaType && targetMsg.mediaType !== "none") {
          if (targetMsg.mediaType === "photo") return "Photo"
          if (targetMsg.mediaType === "video") return "Video"
          if (targetMsg.mediaType === "animation") return "GIF"
          if (targetMsg.mediaType === "audio") return "Audio"
          if (targetMsg.mediaType === "document") return targetMsg.fileName || "Document"
        }
      }
    }
    return ""
  }

  signal startMessaging()
  signal sendMessageRequested(string text, var replyToMessageId, string quoteText)
  signal sendMediaRequested(string filePath, string caption, var replyToMessageId, string quoteText)
  signal toggleReactionRequested(var messageId, string emoji, bool isChosen)

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

  // Conversation header
  Item {
    id: conversationHeader
    z: 2
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.hasConversation ? 72 : 0
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      spacing: 12

      // Contact details pill with transparent background
      Item {
        Layout.preferredHeight: 52
        implicitWidth: contactInfoRow.implicitWidth + 24

        RowLayout {
          id: contactInfoRow
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.rightMargin: 16
          spacing: 12

          Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 19
            color: root.avatarColor
            border.color: Qt.rgba(1, 1, 1, 0.2)
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
              color: "#FFFFFF"
              font.bold: true
              font.pixelSize: 14
            }
          }

          ColumnLayout {
            spacing: 2
            Layout.rightMargin: 12

            Label {
              text: root.chatName
              color: Theme.primaryText
              font.bold: true
              font.pixelSize: 15
              elide: Text.ElideRight
            }

            Label {
              text: root.typing ? "typing..." : (root.statusText !== "" ? root.statusText : "Telegram conversation")
              color: root.typing ? Theme.accent : (root.isOnline ? Theme.accent : Theme.secondaryText)
              font.pixelSize: 11
            }
          }
        }
      }

      Item {
        Layout.fillWidth: true
      }

      // Voice call button
      ToolButton {
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/call.svg"
        icon.width: 20
        icon.height: 20
        icon.color: parent.hovered ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 38
        implicitHeight: 38
        ToolTip.visible: hovered
        ToolTip.text: "Voice call"
        background: Rectangle {
          radius: 12
          color: parent.hovered ? Theme.accent : "transparent"
          border.color: parent.hovered ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: 1
            visible: parent.parent.hovered
          }
        }
      }

      // Video call button
      ToolButton {
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/video.svg"
        icon.width: 20
        icon.height: 20
        icon.color: parent.hovered ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 38
        implicitHeight: 38
        ToolTip.visible: hovered
        ToolTip.text: "Video call"
        background: Rectangle {
          radius: 12
          color: parent.hovered ? Theme.accent : "transparent"
          border.color: parent.hovered ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: 1
            visible: parent.parent.hovered
          }
        }
      }

      // Search button
      ToolButton {
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/search.svg"
        icon.width: 20
        icon.height: 20
        icon.color: parent.hovered ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 38
        implicitHeight: 38
        ToolTip.visible: hovered
        ToolTip.text: "Search"
        background: Rectangle {
          radius: 12
          color: parent.hovered ? Theme.accent : "transparent"
          border.color: parent.hovered ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: 1
            visible: parent.parent.hovered
          }
        }
      }

      // Three-dot more options button
      ToolButton {
        icon.source: "qrc:/qt/qml/Silkite/assets/icons/more.svg"
        icon.width: 20
        icon.height: 20
        icon.color: parent.hovered ? Theme.accentText : Theme.primaryText
        focusPolicy: Qt.NoFocus
        implicitWidth: 38
        implicitHeight: 38
        ToolTip.visible: hovered
        ToolTip.text: "More options"
        background: Rectangle {
          radius: 12
          color: parent.hovered ? Theme.accent : "transparent"
          border.color: parent.hovered ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
          border.width: 1

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: 1
            visible: parent.parent.hovered
          }
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
        id: messageListView
        z: 5
        clip: true
        anchors.fill: parent
        visible: root.hasConversation
        model: root.messageModel ? root.messageModel : root.messages
        spacing: 6
        topMargin: 12
        bottomMargin: 12
        boundsBehavior: Flickable.StopAtBounds
        maximumFlickVelocity: 4000
        flickDeceleration: 1600

        onAtYEndChanged: {
          if (atYEnd) {
            root.unreadIncomingCount = 0
            root.lastKnownAtBottom = true
          }
        }

        onMovementEnded: {
          root.lastKnownAtBottom = root.isScrolledToBottom()
        }

        onDragStarted: {
          root.lastKnownAtBottom = false
        }

        NumberAnimation {
          id: messageScrollAnim
          target: messageListView
          property: "contentY"
          duration: 180
          easing.type: Easing.OutCubic
        }

        WheelHandler {
          id: messageWheelHandler
          target: null
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: (event) => {
            if (event.angleDelta.y === 0) return

            // Standard notch gives 120 units. Smoothly step contentY.
            var step = (event.angleDelta.y / 120.0) * 120.0

            // Bound checking:
            var minY = messageListView.originY - messageListView.topMargin
            var maxY = Math.max(minY, messageListView.originY + messageListView.contentHeight - messageListView.height + messageListView.bottomMargin)

            var startY = messageScrollAnim.running ? messageScrollAnim.to : messageListView.contentY
            var targetY = Math.max(minY, Math.min(startY - step, maxY))

            messageScrollAnim.stop()
            messageScrollAnim.from = messageListView.contentY
            messageScrollAnim.to = targetY
            messageScrollAnim.start()

            event.accepted = true
          }
        }

        delegate: Item {
          id: msgDelegate
          required property var modelData
          readonly property var mData: modelData || ({})
          width: messageListView.width
          height: bubble.height + (reactionsRow.visible ? (reactionsRow.height + 4) : 0) + 6

          readonly property bool isOutgoing: Boolean(mData.outgoing)
          readonly property bool hasReply: (mData.replyToMessageId && mData.replyToMessageId > 0) || (mData.replyText !== undefined && mData.replyText !== "")
          readonly property bool hasMedia: mData.mediaType !== undefined && mData.mediaType !== "none" && mData.mediaType !== ""
          readonly property bool isVisualMedia: mData.mediaType === "photo" || mData.mediaType === "video" || mData.mediaType === "animation"
          readonly property bool isPhoto: mData.mediaType === "photo"
          readonly property bool isVideo: mData.mediaType === "video"
          readonly property bool isAnimation: mData.mediaType === "animation"
          readonly property bool isDoc: mData.mediaType === "document" || mData.mediaType === "audio"
          readonly property bool hasCaption: Boolean(mData.caption && mData.caption.trim().length > 0)
          readonly property bool isBorderlessMedia: isVisualMedia && !hasCaption && !hasReply

          // Target dimensions for photos, videos, and gifs based on aspect ratio
          readonly property real targetMediaWidth: {
            if (!isVisualMedia) return 0
            var maxW = isAnimation
              ? Math.min(240, parent.width * 0.48)
              : Math.min(380, parent.width * 0.68)
            var minW = isAnimation ? 140 : 220
            var baseScale = isAnimation ? 180 : 280
            var w = mData.mediaWidth || 0
            var h = mData.mediaHeight || 0
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
                return Math.max(minW, Math.min(maxW, baseScale * ratio))
              } else {
                var targetH = Math.min(isAnimation ? 220 : 340, baseScale / ratio)
                return Math.max(minW, Math.min(maxW, targetH * ratio))
              }
            }
            return isAnimation ? 200 : 320
          }

          readonly property real targetMediaHeight: {
            if (!isVisualMedia) return 0
            var maxH = isAnimation ? 220 : 360
            var minH = isAnimation ? 100 : 160
            var w = mData.mediaWidth || 0
            var h = mData.mediaHeight || 0
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
            return isAnimation ? 150 : 220
          }

          TextMetrics {
            id: bubbleMetrics
            text: mData.caption ? mData.caption : (mData.text || "")
            font: bubbleText.font
          }

          TextMetrics {
            id: metaMetrics
            text: (mData.time || "") + (msgDelegate.isOutgoing && mData.status ? (" " + mData.status) : "")
            font: metaTimeLabel.font
          }

          TextMetrics {
            id: replyContentMetrics
            text: hasReply ? root.replyPreviewText(mData) : ""
            font: replyContentText.font
          }

          TextMetrics {
            id: replySenderMetrics
            text: hasReply ? root.replyTargetName(mData, msgDelegate.isOutgoing) : ""
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

          // Ambient Elevation Glow/Shadow layer 2 (wider, softer spread)
          Rectangle {
            z: 1
            x: bubble.x - 1
            y: bubble.y + 2
            width: bubble.width + 2
            height: bubble.height + 1
            topLeftRadius: bubble.topLeftRadius + 1
            topRightRadius: bubble.topRightRadius + 1
            bottomLeftRadius: bubble.bottomLeftRadius + 1
            bottomRightRadius: bubble.bottomRightRadius + 1
            color: Qt.rgba(0, 0, 0, 0.12)
            visible: !msgDelegate.isBorderlessMedia
          }

          // Direct Elevation Cast Shadow layer 1 (contact shadow)
          Rectangle {
            z: 2
            x: bubble.x
            y: bubble.y + 1
            width: bubble.width
            height: bubble.height
            topLeftRadius: bubble.topLeftRadius
            topRightRadius: bubble.topRightRadius
            bottomLeftRadius: bubble.bottomLeftRadius
            bottomRightRadius: bubble.bottomRightRadius
            color: Qt.rgba(0, 0, 0, 0.22)
            visible: !msgDelegate.isBorderlessMedia
          }

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

            // Modern capsule corners: 18px radius with subtle corner anchor
            // Visual borderless media always uses uniform 18px radius on all 4 corners
            topLeftRadius: 18
            topRightRadius: 18
            bottomLeftRadius: isBorderlessMedia ? 18 : (msgDelegate.isOutgoing ? 18 : 6)
            bottomRightRadius: isBorderlessMedia ? 18 : (msgDelegate.isOutgoing ? 6 : 18)

            color: isBorderlessMedia
              ? "transparent"
              : (msgDelegate.isOutgoing
                  ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.92)
                  : Theme.elevatedBackground)
            border.width: isBorderlessMedia ? 0 : 1
            border.color: msgDelegate.isOutgoing ? Qt.rgba(1, 1, 1, 0.28) : Theme.divider
            clip: isBorderlessMedia

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              topLeftRadius: 17
              topRightRadius: 17
              bottomLeftRadius: msgDelegate.isBorderlessMedia ? 17 : (msgDelegate.isOutgoing ? 17 : 5)
              bottomRightRadius: msgDelegate.isBorderlessMedia ? 17 : (msgDelegate.isOutgoing ? 5 : 17)
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, msgDelegate.isOutgoing ? 0.35 : 0.08)
              border.width: 1
              visible: !msgDelegate.isBorderlessMedia
            }

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
                text: msgDelegate.mData.text || ""
                color: msgDelegate.isOutgoing ? Theme.accentText : Theme.primaryText
                font.pixelSize: 15
                elide: Text.ElideNone
              }

              Row {
                id: singleMetaRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Label {
                  text: msgDelegate.mData.time || ""
                  color: msgDelegate.isOutgoing ? Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.75) : Theme.secondaryText
                  font.pixelSize: 11
                }

                Label {
                  text: (msgDelegate.isOutgoing && msgDelegate.mData.status !== "") ? msgDelegate.mData.status : ""
                  color: msgDelegate.isOutgoing ? Theme.accentText : Theme.primaryText
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
                  source: (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "" && !msgDelegate.isAnimation) ? ("file://" + msgDelegate.mData.filePath) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true
                  visible: false
                }

                AnimatedImage {
                  id: borderlessGif
                  anchors.fill: parent
                  source: (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "" && msgDelegate.isAnimation) ? ("file://" + msgDelegate.mData.filePath) : ""
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

                // Thin delicate border around borderless media
                Rectangle {
                  anchors.fill: parent
                  radius: 16
                  color: "transparent"
                  border.color: Qt.rgba(1, 1, 1, 0.18)
                  border.width: 1
                  z: 5
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
                    visible: msgDelegate.mData.isDownloading || !msgDelegate.mData.filePath

                    BusyIndicator {
                      anchors.centerIn: parent
                      running: msgDelegate.mData.isDownloading || !msgDelegate.mData.filePath
                      width: 28
                      height: 28
                    }
                  }

                  Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: msgDelegate.mData.isDownloading ? "Downloading..." : ""
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
                  visible: msgDelegate.isVideo && msgDelegate.mData.duration > 0

                  Label {
                    id: durText1
                    function formatDur(sec) {
                      var m = Math.floor(sec / 60)
                      var s = sec % 60
                      return m + ":" + (s < 10 ? "0" : "") + s
                    }
                    anchors.centerIn: parent
                    text: formatDur(msgDelegate.mData.duration)
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
                      text: msgDelegate.mData.time || ""
                      color: "#FFFFFF"
                      font.pixelSize: 11
                    }

                    Label {
                      text: (msgDelegate.isOutgoing && msgDelegate.mData.status !== "") ? msgDelegate.mData.status : ""
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
                    if (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "") {
                      mediaViewer.show(msgDelegate.mData.filePath, msgDelegate.isVideo ? "video" : (msgDelegate.isAnimation ? "animation" : "photo"))
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
                    text: root.replyTargetName(msgDelegate.mData, msgDelegate.isOutgoing)
                    color: Theme.primaryText
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }

                  Label {
                    id: replyContentText
                    width: parent.width
                    text: root.replyPreviewText(msgDelegate.mData)
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
                  source: (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "" && !msgDelegate.isAnimation) ? ("file://" + msgDelegate.mData.filePath) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true
                  visible: false
                }

                AnimatedImage {
                  id: captionedGif
                  anchors.fill: parent
                  source: (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "" && msgDelegate.isAnimation) ? ("file://" + msgDelegate.mData.filePath) : ""
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

                // Thin delicate border around captioned media preview
                Rectangle {
                  anchors.fill: parent
                  topLeftRadius: 16
                  topRightRadius: 16
                  bottomLeftRadius: 0
                  bottomRightRadius: 0
                  color: "transparent"
                  border.color: Qt.rgba(1, 1, 1, 0.16)
                  border.width: 1
                  z: 5
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
                    visible: msgDelegate.mData.isDownloading || !msgDelegate.mData.filePath

                    BusyIndicator {
                      anchors.centerIn: parent
                      running: msgDelegate.mData.isDownloading || !msgDelegate.mData.filePath
                      width: 28
                      height: 28
                    }
                  }

                  Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: msgDelegate.mData.isDownloading ? "Downloading..." : ""
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
                  visible: msgDelegate.isVideo && msgDelegate.mData.duration > 0

                  Label {
                    id: durText2
                    function formatDur(sec) {
                      var m = Math.floor(sec / 60)
                      var s = sec % 60
                      return m + ":" + (s < 10 ? "0" : "") + s
                    }
                    anchors.centerIn: parent
                    text: formatDur(msgDelegate.mData.duration)
                    color: "#FFFFFF"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "") {
                      mediaViewer.show(msgDelegate.mData.filePath, msgDelegate.isVideo ? "video" : (msgDelegate.isAnimation ? "animation" : "photo"))
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
                      text: msgDelegate.mData.fileName || "Document"
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
                      text: (msgDelegate.mData.isDownloading ? "Downloading • " : (msgDelegate.mData.filePath ? "Downloaded • " : "")) + formatSize(msgDelegate.mData.fileSize)
                      color: Theme.secondaryText
                      font.pixelSize: 11
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "") {
                      Qt.openUrlExternally("file://" + msgDelegate.mData.filePath)
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
                text: msgDelegate.mData.caption ? msgDelegate.mData.caption : (msgDelegate.mData.text || "")
                color: msgDelegate.isOutgoing ? Theme.accentText : Theme.primaryText
                wrapMode: Text.WordWrap
                font.pixelSize: 15
                lineHeight: 1.15
              }

              Row {
                anchors.right: parent.right
                anchors.rightMargin: msgDelegate.isVisualMedia ? 10 : 0
                spacing: 3
                visible: (msgDelegate.mData.time !== undefined && msgDelegate.mData.time !== "") || (msgDelegate.isOutgoing && msgDelegate.mData.status !== "")

                Label {
                  id: metaTimeLabel
                  text: msgDelegate.mData.time || ""
                  color: msgDelegate.isOutgoing ? Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.75) : Theme.secondaryText
                  font.pixelSize: 11
                }

                Label {
                  text: (msgDelegate.isOutgoing && msgDelegate.mData.status !== "") ? msgDelegate.mData.status : ""
                  color: msgDelegate.isOutgoing ? Theme.accentText : Theme.primaryText
                  font.pixelSize: 11
                  visible: text.length > 0
                }
              }
            }

            // Click & Context menu trigger for message bubble
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              z: 20
              cursorShape: Qt.ArrowCursor
              onClicked: function(mouse) {
                var bubbleContentText = msgDelegate.mData.caption ? msgDelegate.mData.caption : (msgDelegate.mData.text || "")
                var senderName = msgDelegate.isOutgoing ? "You" : root.chatName
                messageContextMenu.targetMessageId = msgDelegate.mData.messageId || 0
                messageContextMenu.targetSender = senderName
                messageContextMenu.textToCopy = bubbleContentText
                messageContextMenu.mediaPathToCopy = (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "") ? msgDelegate.mData.filePath : ""

                if (mouse.button === Qt.RightButton) {
                  messageContextMenu.popup()
                } else if (mouse.button === Qt.LeftButton) {
                  if (msgDelegate.hasMedia && msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "") {
                    if (msgDelegate.isDoc) {
                      Qt.openUrlExternally("file://" + msgDelegate.mData.filePath)
                    } else if (msgDelegate.isVisualMedia) {
                      mediaViewer.show(msgDelegate.mData.filePath, msgDelegate.isVideo ? "video" : (msgDelegate.isAnimation ? "animation" : "photo"))
                    }
                  } else {
                    // Left-click on message bubble shows reaction picker pill beside the chat bubble
                    var mapped = bubble.mapToItem(null, 0, 0)
                    root.openReactionPicker(msgDelegate.mData.messageId || 0, mapped, msgDelegate.isOutgoing, bubble.width)
                  }
                }
              }
            }
          }

          // Message Reactions Badges Row (resting pills below bubble)
          Row {
            id: reactionsRow
            z: 15
            anchors.top: bubble.bottom
            anchors.topMargin: 4
            anchors.right: msgDelegate.isOutgoing ? bubble.right : undefined
            anchors.left: msgDelegate.isOutgoing ? undefined : bubble.left
            spacing: 4
            visible: (msgDelegate.mData.reactions && msgDelegate.mData.reactions.length > 0)

            Repeater {
              model: msgDelegate.mData.reactions || []
              delegate: Rectangle {
                id: reactionBadge
                required property var modelData
                readonly property var rItem: modelData || ({})
                readonly property bool chosen: Boolean(rItem.isChosen)

                radius: 12
                height: 24
                width: badgeRow.implicitWidth + 14
                color: chosen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) : Theme.elevatedBackground
                border.width: 1
                border.color: chosen ? Theme.accent : Theme.divider

                Behavior on scale {
                  NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                }
                Behavior on color {
                  ColorAnimation { duration: 150 }
                }

                Component.onCompleted: {
                  scale = 0.5
                  scale = 1.0
                }

                Row {
                  id: badgeRow
                  anchors.centerIn: parent
                  spacing: 4
                  Label {
                    text: reactionBadge.rItem.emoji || ""
                    font.pixelSize: 13
                  }
                  Label {
                    text: reactionBadge.rItem.count ? reactionBadge.rItem.count.toString() : "1"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: reactionBadge.chosen ? Theme.accent : Theme.secondaryText
                    visible: text !== "0"
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    reactionBadge.scale = 0.8
                    reactionBadge.scale = 1.0
                    root.toggleReactionRequested(msgDelegate.mData.messageId, reactionBadge.rItem.emoji, reactionBadge.chosen)
                  }
                }
              }
            }
          }
        }
      }

      Label {
        anchors.centerIn: parent
        visible: root.hasConversation && (root.messageModel ? root.messageModel.count === 0 : root.messages.length === 0)
        text: "Your conversation will appear here."
        color: Theme.secondaryText
      }

      // Floating pill-shaped button to scroll to bottom and show unread/new messages count
      Item {
        id: scrollToBottomPill
        z: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        visible: opacity > 0
        opacity: (root.hasConversation && (!root.isScrolledToBottom() || root.unreadIncomingCount > 0)) ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        implicitWidth: pillContentRow.implicitWidth + 24
        implicitHeight: 36

        // Single-layer elevation shadow
        Rectangle {
          anchors.fill: pillGlass
          anchors.topMargin: 2
          anchors.bottomMargin: -2
          anchors.leftMargin: -1
          anchors.rightMargin: -1
          radius: pillGlass.radius + 1
          color: Qt.rgba(0, 0, 0, 0.28)
          z: -1
        }

        Rectangle {
          id: pillGlass
          anchors.fill: parent
          radius: height / 2
          color: pillMouseArea.containsMouse
            ? Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.96)
            : Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.88)
          border.color: pillMouseArea.containsMouse ? Theme.accent : Theme.divider
          border.width: 1

          Behavior on color {
            ColorAnimation { duration: 150 }
          }
          Behavior on border.color {
            ColorAnimation { duration: 150 }
          }

          // Subtle inner highlight border
          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: (parent.height / 2) - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
          }

          RowLayout {
            id: pillContentRow
            anchors.centerIn: parent
            spacing: 6

            Image {
              source: "qrc:/qt/qml/Silkite/assets/icons/arrow-down.svg"
              width: 16
              height: 16
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              fillMode: Image.PreserveAspectFit
              sourceSize: Qt.size(16, 16)
              layer.enabled: true
              layer.effect: ColorOverlay {
                color: pillMouseArea.containsMouse ? Theme.accent : Theme.primaryText
              }
            }

            Rectangle {
              id: unreadBadge
              visible: root.unreadIncomingCount > 0
              radius: 9
              Layout.preferredHeight: 18
              Layout.preferredWidth: Math.max(18, badgeText.implicitWidth + 8)
              color: Theme.accent

              Label {
                id: badgeText
                anchors.centerIn: parent
                text: root.unreadIncomingCount > 99 ? "99+" : root.unreadIncomingCount.toString()
                color: Theme.accentText
                font.pixelSize: 11
                font.weight: Font.DemiBold
              }
            }
          }

          MouseArea {
            id: pillMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.scrollToBottomSmoothly()
            }
          }
        }
      }

      // Horizontal Pill-Shaped Reaction Picker Pop-up Box
      Item {
        id: reactionPickerPopup
        z: 50
        x: root.reactionPickerX
        y: root.reactionPickerY
        width: 224
        height: 44
        visible: opacity > 0
        opacity: root.reactionPickerVisible ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        // Elevation soft shadow
        Rectangle {
          anchors.fill: pickerBackground
          anchors.topMargin: 2
          anchors.bottomMargin: -2
          anchors.leftMargin: -1
          anchors.rightMargin: -1
          radius: pickerBackground.radius + 1
          color: Qt.rgba(0, 0, 0, 0.32)
          z: -1
        }

        Rectangle {
          id: pickerBackground
          anchors.fill: parent
          radius: 22
          color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.96)
          border.color: Theme.divider
          border.width: 1

          // Inner highlight border
          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 21
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 2

            // Horizontally scrollable row showing 5 reactions visible at a time
            Flickable {
              id: reactionFlickable
              Layout.fillWidth: true
              Layout.fillHeight: true
              contentWidth: emojiRow.implicitWidth
              contentHeight: height
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Row {
                id: emojiRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                readonly property var emojis: [
                  "👍", "❤️", "🔥", "😂", "👏", "🎉", "😍", "😢",
                  "😮", "🙏", "🤩", "⚡", "💯", "🫡", "🤝", "🥳"
                ]

                Repeater {
                  model: emojiRow.emojis
                  delegate: Rectangle {
                    required property var modelData
                    readonly property string emojiChar: modelData
                    width: 32
                    height: 32
                    radius: 16
                    color: emojiMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent"

                    Behavior on scale {
                      NumberAnimation { duration: 100 }
                    }
                    scale: emojiMouse.containsMouse ? 1.25 : 1.0

                    Label {
                      anchors.centerIn: parent
                      text: emojiChar
                      font.pixelSize: 20
                    }

                    MouseArea {
                      id: emojiMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.activeReactionMessageId) {
                          root.toggleReactionRequested(root.activeReactionMessageId, emojiChar, false)
                        }
                        root.closeReactionPicker()
                      }
                    }
                  }
                }
              }
            }

            // Arrow button at the end to scroll/reveal more reactions
            Rectangle {
              Layout.preferredWidth: 28
              Layout.preferredHeight: 28
              radius: 14
              color: arrowMouse.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)

              Behavior on color {
                ColorAnimation { duration: 120 }
              }

              Image {
                source: "qrc:/qt/qml/Silkite/assets/icons/arrow-down.svg"
                anchors.centerIn: parent
                width: 14
                height: 14
                rotation: reactionFlickable.atXEnd ? 90 : -90
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(14, 14)
                layer.enabled: true
                layer.effect: ColorOverlay {
                  color: arrowMouse.containsMouse ? Theme.accentText : Theme.primaryText
                }
              }

              MouseArea {
                id: arrowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (reactionFlickable.atXEnd) {
                    reactionFlickAnim.to = 0
                  } else {
                    reactionFlickAnim.to = Math.min(reactionFlickable.contentWidth - reactionFlickable.width, reactionFlickable.contentX + 110)
                  }
                  reactionFlickAnim.restart()
                }
              }

              NumberAnimation {
                id: reactionFlickAnim
                target: reactionFlickable
                property: "contentX"
                duration: 200
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }

      // Invisible backdrop to dismiss reaction picker when clicking outside
      MouseArea {
        anchors.fill: parent
        z: 49
        visible: root.reactionPickerVisible
        onClicked: {
          root.closeReactionPicker()
        }
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

      // Animated typing indicator positioned directly below messages and right above the input
      RowLayout {
        id: typingIndicatorRow
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.bottomMargin: 2
        spacing: 6
        visible: root.typing
        opacity: root.typing ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
        }

        Label {
          text: (root.chatName !== "" ? root.chatName : "Contact") + " is typing"
          color: Theme.accent
          font.pixelSize: 12
          font.weight: Font.DemiBold
        }

        Row {
          spacing: 3
          Layout.alignment: Qt.AlignVCenter

          Repeater {
            model: 3
            delegate: Rectangle {
              width: 4
              height: 4
              radius: 2
              color: Theme.accent

              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.typing
                PauseAnimation { duration: index * 200 }
                NumberAnimation { from: 0.25; to: 1.0; duration: 300; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.0; to: 0.25; duration: 300; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: (2 - index) * 200 + 200 }
              }

              SequentialAnimation on y {
                loops: Animation.Infinite
                running: root.typing
                PauseAnimation { duration: index * 200 }
                NumberAnimation { from: 0; to: -3; duration: 300; easing.type: Easing.OutQuad }
                NumberAnimation { from: -3; to: 0; duration: 300; easing.type: Easing.InQuad }
                PauseAnimation { duration: (2 - index) * 200 + 200 }
              }
            }
          }
        }
      }

      // Reply preview banner shown directly above the input box
      Rectangle {
        id: composerReplyBanner
        Layout.fillWidth: true
        implicitHeight: root.activeReply ? 42 : 0
        visible: root.activeReply !== null
        radius: 12
        color: Theme.controlBackground
        border.color: Theme.divider
        border.width: 1
        clip: true

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: 11
          color: "transparent"
          border.color: Qt.rgba(1, 1, 1, 0.08)
          border.width: 1
        }

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
          font.pixelSize: 22
          focusPolicy: Qt.NoFocus
          implicitWidth: 42
          implicitHeight: 42
          onClicked: fileDialog.open()
          contentItem: Label {
            text: parent.text
            color: parent.hovered ? Theme.accentText : Theme.primaryText
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: 14
            color: parent.hovered ? Theme.accent : Theme.controlBackground
            border.color: parent.hovered ? Qt.rgba(1, 1, 1, 0.25) : Theme.divider
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: 13
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, parent.parent.hovered ? 0.35 : 0.08)
              border.width: 1
            }
          }
        }

        TextArea {
          id: messageInput
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(42, Math.min(140, implicitHeight))
          Layout.maximumHeight: 140

          placeholderText: "Write a message..."
          color: Theme.primaryText
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          leftPadding: 18
          rightPadding: 16
          topPadding: 11
          bottomPadding: 11
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
            radius: 16
            color: Theme.controlBackground
            border.color: messageInput.activeFocus ? Theme.accent : Theme.divider
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: 15
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, messageInput.activeFocus ? 0.28 : 0.08)
              border.width: 1
            }
          }
        }

        ToolButton {
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/send.svg"
          icon.width: 22
          icon.height: 22
          icon.color: Theme.accentText
          focusPolicy: Qt.NoFocus
          implicitWidth: 42
          implicitHeight: 42
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
            radius: 14
            color: Theme.accent
            border.color: Qt.rgba(1, 1, 1, 0.25)
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: 13
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, 0.35)
              border.width: 1
            }
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

    background: Item {
      implicitWidth: 168
      Rectangle {
        anchors.fill: msgMenuGlass
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: msgMenuGlass.radius + 1
        color: Qt.rgba(0, 0, 0, 0.22)
        z: -1
      }
      Rectangle {
        id: msgMenuGlass
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
