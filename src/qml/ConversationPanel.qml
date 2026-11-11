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
  property bool isSecondaryPane: false
  property bool canSendMessages: true
  property string chatType: "group"
  property bool isMember: true
  property bool isMuted: false
  property string lastSentText: ""

  signal closePaneRequested()
  signal toggleSplitRequested()
  signal joinChatRequested(var chatId)
  signal leaveChatRequested(var chatId)
  signal toggleMuteRequested(var chatId, bool mute)

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
    messageListView.positionViewAtEnd()
  }

  onChatIdChanged: {
    if (chatId !== previousChatId) {
      previousChatId = chatId
      unreadIncomingCount = 0
      previousMessageCount = 0
      pendingScrollToBottom = false
      bottomScrollScheduled = false
      lastKnownAtBottom = true
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
      // Only snap to the bottom if we were previously empty or the user is already at the bottom
      if (root.previousMessageCount === 0 || root.lastKnownAtBottom) {
        root.lastKnownAtBottom = true
        root.unreadIncomingCount = 0
        root.scheduleBottomScroll(false)
      }
      root.previousMessageCount = root.messageModel ? root.messageModel.count : 0
    }
    function onMessageAdded(message) {
      root.handleNewMessage(message)
    }
    function onCountChanged() {
      // Handled primarily via messageAdded, but keep count sync
      root.previousMessageCount = root.messageModel ? root.messageModel.count : 0
    }
  }

  Connections {
    target: telegramClient
    function onMessageSendFailed(failedChatId, error) {
      if (failedChatId === root.chatId) {
        if (messageInput.text === "" && root.lastSentText !== "") {
          messageInput.text = root.lastSentText
          root.lastSentText = ""
        }
      }
    }
  }

  property bool hasConversation: (chatId !== 0 && chatId !== undefined && chatId !== null) || chatName !== ""
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

  // Error details popup state for failed message send
  property string sendErrorText: ""
  property real sendErrorPopupX: 0
  property real sendErrorPopupY: 0

  function openSendErrorPopup(errorText, item) {
    sendErrorText = errorText || "Message failed to send"
    var p = item.mapToItem(root, 0, 0)
    var popupW = sendErrorPopup.width
    var popupH = 90
    var targetX = p.x - popupW + 24
    sendErrorPopupX = Math.max(12, Math.min(root.width - popupW - 12, targetX))
    if (p.y - popupH - 8 >= 8) {
      sendErrorPopupY = p.y - popupH - 8
    } else {
      sendErrorPopupY = Math.min(root.height - popupH - 12, p.y + 24)
    }
    sendErrorPopup.open()
  }

  function closeSendErrorPopup() {
    sendErrorPopup.close()
    sendErrorText = ""
  }

  // Active composer panel popup state ("none", "emoji", "sticker", "gif")
  property string activeComposerPopup: "none"
  property bool composerControlsCollapsed: false
  property bool composerToolsExpanded: false

  function toggleComposerPopup(popupName) {
    if (activeComposerPopup === popupName) {
      activeComposerPopup = "none"
    } else {
      activeComposerPopup = popupName
    }
  }

  function closeComposerPopups() {
    activeComposerPopup = "none"
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

  // Outer soft ambient elevation shadow for the chat messages box
  Rectangle {
    anchors.fill: chatMessagesBox
    anchors.topMargin: 2
    anchors.bottomMargin: -2
    anchors.leftMargin: -1
    anchors.rightMargin: -1
    radius: chatMessagesBox.radius + 1
    color: Qt.rgba(0, 0, 0, 0.18)
    z: -1
    visible: root.hasConversation
  }

  readonly property bool showComposer: root.hasConversation && root.canSendMessages && root.isMember

  // Liquid glass background container ONLY for the chat messages section
  Rectangle {
    id: chatMessagesBox
    anchors.top: conversationHeader.bottom
    anchors.topMargin: 6
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: messageComposer.top
    anchors.bottomMargin: 6
    radius: 18
    color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
    border.color: Theme.divider
    border.width: 1
    visible: root.hasConversation

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

  // Conversation header with separate backgrounds
  Item {
    id: conversationHeader
    z: 2
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.hasConversation ? 52 : 0
    visible: root.hasConversation
    clip: false

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 0
      anchors.rightMargin: 0
      spacing: 6

      // Left box: Contact info pill container
      Rectangle {
        id: contactInfoBox
        Layout.preferredHeight: 52
        implicitWidth: contactInfoRow.implicitWidth + 20
        radius: 16
        color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
        border.color: Theme.divider
        border.width: 1

        // Soft elevation shadow
        Rectangle {
          anchors.fill: parent
          anchors.topMargin: 2
          anchors.bottomMargin: -2
          anchors.leftMargin: -1
          anchors.rightMargin: -1
          radius: parent.radius + 1
          color: Qt.rgba(0, 0, 0, 0.14)
          z: -1
        }

        // Inner subtle highlight border
        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: parent.radius - 1
          color: "transparent"
          border.color: Qt.rgba(1, 1, 1, 0.08)
          border.width: 1
        }

        RowLayout {
          id: contactInfoRow
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.rightMargin: 12
          spacing: 10

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

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onClicked: {
                if (window && typeof window.showContactProfile === "function") {
                  window.showContactProfile({
                    chatId: root.chatId,
                    name: root.chatName,
                    fullName: root.chatName,
                    statusText: root.statusText,
                    isOnline: root.isOnline,
                    initials: root.chatInitials,
                    avatarColor: root.avatarColor,
                    avatarPath: root.avatarPath
                  })
                }
              }
            }
          }

          ColumnLayout {
            spacing: 2
            Layout.rightMargin: 8

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

      // Right box: Action buttons container
      Rectangle {
        id: headerActionsBox
        Layout.preferredHeight: 52
        implicitWidth: headerActionsRow.implicitWidth + 16
        radius: 16
        color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
        border.color: Theme.divider
        border.width: 1

        // Soft elevation shadow
        Rectangle {
          anchors.fill: parent
          anchors.topMargin: 2
          anchors.bottomMargin: -2
          anchors.leftMargin: -1
          anchors.rightMargin: -1
          radius: parent.radius + 1
          color: Qt.rgba(0, 0, 0, 0.14)
          z: -1
        }

        // Inner subtle highlight border
        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: parent.radius - 1
          color: "transparent"
          border.color: Qt.rgba(1, 1, 1, 0.08)
          border.width: 1
        }

        RowLayout {
          id: headerActionsRow
          anchors.centerIn: parent
          spacing: 6

          // Join button for non-members of public channels or groups
          Button {
            visible: (root.chatType === "channel" || root.chatType === "group") && !root.isMember
            text: "Join"
            focusPolicy: Qt.NoFocus
            implicitHeight: 34
            implicitWidth: 68
            contentItem: Text {
              text: parent.text
              font.pixelSize: 13
              font.weight: Font.DemiBold
              color: Theme.accentText
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
              radius: 10
              color: parent.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
              border.color: Qt.rgba(1, 1, 1, 0.25)
              border.width: 1
            }
            onClicked: root.joinChatRequested(root.chatId)
          }

          // Mute / Unmute button for members of channels or groups
          ToolButton {
            visible: (root.chatType === "channel" || root.chatType === "group") && root.isMember
            icon.source: root.isMuted ? "qrc:/qt/qml/Silkite/assets/icons/unmute.svg" : "qrc:/qt/qml/Silkite/assets/icons/mute.svg"
            icon.width: 20
            icon.height: 20
            icon.color: parent.hovered ? Theme.accentText : Theme.primaryText
            focusPolicy: Qt.NoFocus
            implicitWidth: 38
            implicitHeight: 38
            ToolTip.visible: hovered
            ToolTip.text: root.isMuted ? "Unmute" : "Mute"
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
            onClicked: root.toggleMuteRequested(root.chatId, !root.isMuted)
          }

          // Leave button for members of channels or groups
          ToolButton {
            visible: (root.chatType === "channel" || root.chatType === "group") && root.isMember
            icon.source: "qrc:/qt/qml/Silkite/assets/icons/leave.svg"
            icon.width: 20
            icon.height: 20
            icon.color: parent.hovered ? Theme.accentText : Theme.primaryText
            focusPolicy: Qt.NoFocus
            implicitWidth: 38
            implicitHeight: 38
            ToolTip.visible: hovered
            ToolTip.text: "Leave"
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
            onClicked: root.leaveChatRequested(root.chatId)
          }

          // Voice call button (1-on-1 private user chats only)
          ToolButton {
            visible: root.chatType === "user"
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

          // Video call button (1-on-1 private user chats only)
          ToolButton {
            visible: root.chatType === "user"
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

          // Return / Choose chat button if this is secondary pane
          ToolButton {
            visible: root.isSecondaryPane
            icon.source: "qrc:/qt/qml/Silkite/assets/icons/arrow-undo.svg"
            icon.width: 18
            icon.height: 18
            icon.color: parent.hovered ? Theme.accentText : Theme.primaryText
            focusPolicy: Qt.NoFocus
            implicitWidth: 38
            implicitHeight: 38
            ToolTip.visible: hovered
            ToolTip.text: "Choose another chat"
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
            onClicked: root.closePaneRequested()
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
    }
  }

  // Messages area fills all space between the header and composer inside the chat box.
  Item {
    id: messagesArea
    z: 1
    clip: true
    anchors.fill: chatMessagesBox
    anchors.margins: 4
    visible: root.hasConversation

      ListView {
        id: messageListView
        z: 5
        clip: true
        anchors.fill: parent
        visible: root.hasConversation
        model: root.messageModel ? root.messageModel : root.messages
        spacing: 6
        topMargin: 8
        bottomMargin: 8
        boundsBehavior: Flickable.StopAtBounds
        displayMarginBeginning: 600
        displayMarginEnd: 600
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

        ScrollBar.vertical: ScrollBar {
          id: messageScrollBar
          active: messageListView.moving || messageScrollBar.hovered || messageScrollBar.pressed
          policy: ScrollBar.AsNeeded
          contentItem: Rectangle {
            implicitWidth: 5
            radius: 2.5
            color: messageScrollBar.hovered ? Theme.accent : Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.45)
          }
        }

        delegate: Item {
          id: msgDelegate
          required property var modelData
          required property int index
          readonly property var mData: modelData || ({})
          width: messageListView.width

          readonly property bool isGroupStart: {
            if (index === 0) return true
            var prevMsg = null
            if (root.messageModel && typeof root.messageModel.get === "function") {
              prevMsg = root.messageModel.get(index - 1)
            } else if (root.messages && index - 1 < root.messages.length) {
              prevMsg = root.messages[index - 1]
            }
            if (!prevMsg) return true
            return Boolean(prevMsg.outgoing) !== Boolean(mData.outgoing)
          }

          readonly property real topGroupGap: (index > 0 && isGroupStart) ? Math.max(0, Theme.chatSpacing - 3) : 0
          height: bubble.height + (reactionsRow.visible ? (reactionsRow.height + 4) : 0) + 6 + topGroupGap

          readonly property bool isOutgoing: Boolean(mData.outgoing)
          readonly property bool hasReply: (mData.replyToMessageId && mData.replyToMessageId > 0) || (mData.replyText !== undefined && mData.replyText !== "")
          readonly property bool hasMedia: mData.mediaType !== undefined && mData.mediaType !== "none" && mData.mediaType !== "" && mData.mediaType !== "sticker"
          readonly property bool isVisualMedia: mData.mediaType === "photo" || mData.mediaType === "video" || mData.mediaType === "animation"
          readonly property bool isPhoto: mData.mediaType === "photo"
          readonly property bool isVideo: mData.mediaType === "video"
          readonly property bool isAnimation: mData.mediaType === "animation"
          readonly property bool isDoc: mData.mediaType === "document" || mData.mediaType === "audio"
          readonly property bool isSticker: mData.mediaType === "sticker"
          readonly property bool isSingleEmoji: {
            if (hasMedia || hasReply || isSticker) return false
            if (mData.isSingleEmoji !== undefined) return Boolean(mData.isSingleEmoji)
            // Client-side regex fallback in case of local/unsynced messages
            var t = (mData.text || "").trim()
            if (!t) return false
            try {
              return /^(\p{Emoji_Presentation}|\p{Extended_Pictographic}|\p{Emoji}\uFE0F)$/u.test(t)
            } catch (e) {
              return false
            }
          }
          readonly property bool hasCaption: !isSticker && !isSingleEmoji && Boolean(mData.caption && mData.caption.trim().length > 0)
          readonly property bool isBorderlessMedia: (isVisualMedia || isSticker || isSingleEmoji) && !hasCaption && !hasReply

          // Target dimensions for photos, videos, stickers, and gifs based on aspect ratio
          readonly property real targetMediaWidth: {
            if (isSingleEmoji) return 100
            if (isSticker) return 180
            if (!isVisualMedia) return 0
            var parentW = (msgDelegate.width > 0 ? msgDelegate.width : messageListView.width)
            var maxW = isAnimation
              ? Math.min(240, parentW * 0.48)
              : Math.min(380, parentW * 0.68)
            var minW = isAnimation ? 140 : 220
            var baseScale = isAnimation ? 180 : 280
            var w = mData.mediaWidth || 0
            var h = mData.mediaHeight || 0
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
            if (isSingleEmoji) return 100
            if (isSticker) return 180
            if (!isVisualMedia) return 0
            var maxH = isAnimation ? 220 : 360
            var minH = isAnimation ? 100 : 160
            var w = mData.mediaWidth || 0
            var h = mData.mediaHeight || 0
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
            text: (mData.time || "") + (msgDelegate.isOutgoing && mData.status ? (" " + mData.status) : "") + ((msgDelegate.isOutgoing && (Boolean(mData.sendError) || mData.status === "!")) ? "   " : "")
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
          readonly property real maxBubbleWidth: Math.min(460, (msgDelegate.width > 0 ? msgDelegate.width : messageListView.width) * 0.68)

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
          readonly property real minBubbleWidth: isSingleEmoji ? 100 : (isSticker ? 180 : (isVisualMedia ? targetMediaWidth : (isDoc ? 260 : (hasReply ? 200 : (msgDelegate.isOutgoing ? 175 : 160)))))

          readonly property bool fitsSingleLine: !isBorderlessMedia && !hasMedia && !hasReply && (inlineNeededWidth <= maxBubbleWidth)

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
            y: msgDelegate.topGroupGap
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
                  ? Math.max(36, Theme.chatFontSize + 21)
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
              z: 5

              Label {
                id: singleLineText
                anchors.left: parent.left
                anchors.right: singleMetaRow.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: msgDelegate.mData.text || ""
                color: msgDelegate.isOutgoing ? Theme.accentText : Theme.primaryText
                font.pixelSize: Theme.chatFontSize
                elide: Text.ElideNone
              }

              Row {
                id: singleMetaRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Label {
                  text: msgDelegate.mData.time || ""
                  color: msgDelegate.isOutgoing ? Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.75) : Theme.secondaryText
                  font.pixelSize: Math.max(9, Theme.chatFontSize - 4)
                }

                Label {
                  text: (msgDelegate.isOutgoing && msgDelegate.mData.status !== "" && msgDelegate.mData.status !== "!") ? msgDelegate.mData.status : ""
                  color: msgDelegate.isOutgoing ? Theme.accentText : Theme.primaryText
                  font.pixelSize: Math.max(9, Theme.chatFontSize - 4)
                  visible: text.length > 0
                }

                Item {
                  id: singleSendErrorIcon
                  width: 14
                  height: 14
                  anchors.verticalCenter: parent.verticalCenter
                  visible: msgDelegate.isOutgoing && (Boolean(msgDelegate.mData.sendError) || msgDelegate.mData.status === "!")
                  z: 50

                  Image {
                    anchors.centerIn: parent
                    source: "qrc:/qt/qml/Silkite/assets/icons/info.svg"
                    width: 13
                    height: 13
                    sourceSize: Qt.size(13, 13)
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                      color: "#EB5757"
                    }
                  }

                  MouseArea {
                    id: singleSendErrorMouseArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    propagateComposedEvents: false
                    onClicked: function(mouse) {
                      mouse.accepted = true
                      root.openSendErrorPopup(msgDelegate.mData.sendError, singleSendErrorIcon)
                    }
                  }
                }
              }
            }

            // === Borderless Media Mode (No caption, no reply) ===
            Item {
              anchors.fill: parent
              visible: msgDelegate.isBorderlessMedia

              // Single Animated Emoji Mode
              Item {
                id: singleAnimatedEmojiBox
                anchors.fill: parent
                visible: msgDelegate.isSingleEmoji

                Label {
                  id: singleEmojiText
                  anchors.centerIn: parent
                  text: msgDelegate.mData.text || ""
                  font.pixelSize: 72
                  scale: 1.0

                  Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                  }

                  SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: msgDelegate.isSingleEmoji
                    PauseAnimation { duration: 2500 }
                    NumberAnimation { from: 0; to: -10; duration: 250; easing.type: Easing.OutQuad }
                    NumberAnimation { from: -10; to: 0; duration: 350; easing.type: Easing.OutBounce }
                    PauseAnimation { duration: 1500 }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: singleEmojiText.scale = 1.3
                    onExited: singleEmojiText.scale = 1.0
                    onClicked: {
                      singleEmojiText.scale = 1.6
                      singleEmojiText.scale = 1.0
                    }
                  }
                }

                // Tiny timestamp pill at bottom-right of single emoji
                Rectangle {
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  radius: 8
                  height: 16
                  width: emojiTimeRow.implicitWidth + 8
                  color: Qt.rgba(0, 0, 0, 0.45)

                  Row {
                    id: emojiTimeRow
                    anchors.centerIn: parent
                    spacing: 3
                    Label {
                      text: msgDelegate.mData.time || ""
                      color: "#FFFFFF"
                      font.pixelSize: 9
                    }
                    Label {
                      text: (msgDelegate.isOutgoing && msgDelegate.mData.status !== "") ? msgDelegate.mData.status : ""
                      color: "#FFFFFF"
                      font.pixelSize: 9
                      visible: text.length > 0
                    }
                  }
                }
              }

              Item {
                id: borderlessMediaBox
                anchors.fill: parent
                visible: !msgDelegate.isSingleEmoji

                // Sticker Emoji Fallback (when .tgs/.webp file is loading or animated emoji sticker)
                Label {
                  anchors.centerIn: parent
                  visible: msgDelegate.isSticker && (!msgDelegate.mData.filePath || msgDelegate.mData.filePath === "" || borderlessImage.status !== Image.Ready)
                  text: (msgDelegate.mData.stickerEmoji && msgDelegate.mData.stickerEmoji !== "")
                    ? msgDelegate.mData.stickerEmoji
                    : ((msgDelegate.mData.caption && msgDelegate.mData.caption !== "") ? msgDelegate.mData.caption : ((msgDelegate.mData.text && msgDelegate.mData.text !== "Sticker" && msgDelegate.mData.text !== "Attachment") ? msgDelegate.mData.text : "🏷️"))
                  font.pixelSize: 84
                  scale: 1.0
                  Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                  }
                }

                Image {
                  id: borderlessImage
                  anchors.fill: parent
                  source: (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "" && !msgDelegate.isAnimation && !msgDelegate.isSticker && !msgDelegate.mData.filePath.endsWith(".tgs")) ? ("file://" + msgDelegate.mData.filePath) : ""
                  fillMode: Image.PreserveAspectFit
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
                  visible: !msgDelegate.isSticker && (msgDelegate.isAnimation ? (borderlessGif.status !== AnimatedImage.Ready) : (borderlessImage.status !== Image.Ready))
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
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.leftMargin: msgDelegate.isVisualMedia ? 0 : 12
              anchors.rightMargin: msgDelegate.isVisualMedia ? 0 : 12
              anchors.topMargin: msgDelegate.isVisualMedia ? 0 : 7
              visible: !msgDelegate.fitsSingleLine && !msgDelegate.isBorderlessMedia
              spacing: 6
              z: 5

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
                  source: (msgDelegate.mData.filePath && msgDelegate.mData.filePath !== "" && !msgDelegate.isAnimation && msgDelegate.isVisualMedia && !msgDelegate.mData.filePath.endsWith(".tgs")) ? ("file://" + msgDelegate.mData.filePath) : ""
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
                font.pixelSize: Theme.chatFontSize
                lineHeight: 1.15
              }

              Row {
                anchors.right: parent.right
                anchors.rightMargin: msgDelegate.isVisualMedia ? 10 : 0
                spacing: 4
                visible: (msgDelegate.mData.time !== undefined && msgDelegate.mData.time !== "") || (msgDelegate.isOutgoing && msgDelegate.mData.status !== "")

                Label {
                  id: metaTimeLabel
                  text: msgDelegate.mData.time || ""
                  color: msgDelegate.isOutgoing ? Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.75) : Theme.secondaryText
                  font.pixelSize: Math.max(9, Theme.chatFontSize - 4)
                }

                Label {
                  text: (msgDelegate.isOutgoing && msgDelegate.mData.status !== "" && msgDelegate.mData.status !== "!") ? msgDelegate.mData.status : ""
                  color: msgDelegate.isOutgoing ? Theme.accentText : Theme.primaryText
                  font.pixelSize: Math.max(9, Theme.chatFontSize - 4)
                  visible: text.length > 0
                }

                Item {
                  id: multiSendErrorIcon
                  width: 14
                  height: 14
                  anchors.verticalCenter: parent.verticalCenter
                  visible: msgDelegate.isOutgoing && (Boolean(msgDelegate.mData.sendError) || msgDelegate.mData.status === "!")
                  z: 50

                  Image {
                    anchors.centerIn: parent
                    source: "qrc:/qt/qml/Silkite/assets/icons/info.svg"
                    width: 13
                    height: 13
                    sourceSize: Qt.size(13, 13)
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                      color: "#EB5757"
                    }
                  }

                  MouseArea {
                    id: multiSendErrorMouseArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    propagateComposedEvents: false
                    onClicked: function(mouse) {
                      mouse.accepted = true
                      root.openSendErrorPopup(msgDelegate.mData.sendError, multiSendErrorIcon)
                    }
                  }
                }
              }
            }

            // Click & Context menu trigger for message bubble
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              z: 1
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

  // Pop-up box attached to the info icon showing message send error
  Popup {
    id: sendErrorPopup
    x: root.sendErrorPopupX
    y: root.sendErrorPopupY
    width: 270
    modal: false
    focus: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 0
    topInset: 0
    leftInset: 0
    rightInset: 0
    bottomInset: 0

    background: Item {
      // Drop shadow
      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: errorPopupBody.radius + 1
        color: Qt.rgba(0, 0, 0, 0.35)
        z: -1
      }

      Rectangle {
        id: errorPopupBody
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.98)
        border.color: Qt.rgba(235/255, 87/255, 87/255, 0.6)
        border.width: 1
      }
    }

    contentItem: ColumnLayout {
      id: errorPopupCol
      spacing: 6
      anchors.fill: parent
      anchors.margins: 12

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Image {
          source: "qrc:/qt/qml/Silkite/assets/icons/info.svg"
          Layout.preferredWidth: 16
          Layout.preferredHeight: 16
          sourceSize: Qt.size(16, 16)
          layer.enabled: true
          layer.effect: ColorOverlay {
            color: "#EB5757"
          }
        }

        Label {
          text: "Message Not Sent"
          color: "#EB5757"
          font.pixelSize: 12
          font.weight: Font.DemiBold
          Layout.fillWidth: true
        }

        Image {
          source: "qrc:/qt/qml/Silkite/assets/icons/close.svg"
          Layout.preferredWidth: 12
          Layout.preferredHeight: 12
          sourceSize: Qt.size(12, 12)
          opacity: closeErrorMouseArea.containsMouse ? 1.0 : 0.6
          layer.enabled: true
          layer.effect: ColorOverlay {
            color: Theme.secondaryText
          }

          MouseArea {
            id: closeErrorMouseArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeSendErrorPopup()
          }
        }
      }

      Label {
        text: root.sendErrorText
        color: Theme.primaryText
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
  }

  // Message composer
  Rectangle {
    id: messageComposer
    z: 30
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.showComposer ? (composerCol.implicitHeight + 20) : 0
    visible: root.showComposer
    clip: false

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
      anchors.leftMargin: 0
      anchors.rightMargin: 0
      anchors.bottomMargin: 6
      spacing: 6

      // Animated typing indicator positioned directly below messages and right above the input
      // Height is permanently reserved so showing/hiding does not resize or flicker the chatbox
      RowLayout {
        id: typingIndicatorRow
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.bottomMargin: 2
        Layout.preferredHeight: 18
        spacing: 6
        visible: true
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
        id: composerInputRow
        Layout.fillWidth: true
        spacing: 6

        // Emojis Button
        ToolButton {
          id: emojiPickerBtn
          visible: !root.composerControlsCollapsed
          focusPolicy: Qt.NoFocus
          implicitWidth: 38
          implicitHeight: 38
          ToolTip.visible: hovered
          ToolTip.text: "Emojis"
          onClicked: root.toggleComposerPopup("emoji")
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/emoji.svg"
          icon.width: 20
          icon.height: 20
          icon.color: (root.activeComposerPopup === "emoji" || hovered) ? Theme.accent : Theme.secondaryText
          background: Rectangle {
            radius: 12
            color: (root.activeComposerPopup === "emoji") ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : (parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            border.color: (root.activeComposerPopup === "emoji") ? Theme.accent : "transparent"
            border.width: 1
          }
        }

        // Stickers Button
        ToolButton {
          id: stickerPickerBtn
          visible: !root.composerControlsCollapsed
          focusPolicy: Qt.NoFocus
          implicitWidth: 38
          implicitHeight: 38
          ToolTip.visible: hovered
          ToolTip.text: "Stickers"
          onClicked: root.toggleComposerPopup("sticker")
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/sticker.svg"
          icon.width: 20
          icon.height: 20
          icon.color: (root.activeComposerPopup === "sticker" || hovered) ? Theme.accent : Theme.secondaryText
          background: Rectangle {
            radius: 12
            color: (root.activeComposerPopup === "sticker") ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : (parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            border.color: (root.activeComposerPopup === "sticker") ? Theme.accent : "transparent"
            border.width: 1
          }
        }

        // GIFs Button
        ToolButton {
          id: gifPickerBtn
          visible: !root.composerControlsCollapsed
          focusPolicy: Qt.NoFocus
          implicitWidth: 38
          implicitHeight: 38
          ToolTip.visible: hovered
          ToolTip.text: "GIFs"
          onClicked: root.toggleComposerPopup("gif")
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/gif.svg"
          icon.width: 20
          icon.height: 20
          icon.color: (root.activeComposerPopup === "gif" || hovered) ? Theme.accent : Theme.secondaryText
          background: Rectangle {
            radius: 12
            color: (root.activeComposerPopup === "gif") ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : (parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            border.color: (root.activeComposerPopup === "gif") ? Theme.accent : "transparent"
            border.width: 1
          }
        }

        // Attachment Button
        ToolButton {
          id: attachBtn
          visible: !root.composerControlsCollapsed
          focusPolicy: Qt.NoFocus
          implicitWidth: 38
          implicitHeight: 38
          ToolTip.visible: hovered
          ToolTip.text: "Attach file"
          onClicked: {
            if (!root.canSendMessages) {
              if (typeof window !== "undefined" && window.showRestrictionAlert) {
                window.showRestrictionAlert("Posting Restricted", "You are not allowed to send attachments or media in this chat.")
              }
              return
            }
            fileDialog.open()
          }
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/attach.svg"
          icon.width: 20
          icon.height: 20
          icon.color: parent.hovered ? Theme.accent : Theme.secondaryText
          background: Rectangle {
            radius: 12
            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
          }
        }

        ToolButton {
          id: compactComposerToolsButton
          visible: root.composerControlsCollapsed
          focusPolicy: Qt.NoFocus
          Layout.preferredWidth: 32
          Layout.preferredHeight: 42
          text: root.composerToolsExpanded ? "⌄" : "⌃"
          font.pixelSize: 22
          font.weight: Font.Medium
          contentItem: Label {
            text: compactComposerToolsButton.text
            color: compactComposerToolsButton.hovered ? Theme.accent : Theme.secondaryText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: {
            root.composerToolsExpanded = !root.composerToolsExpanded
            if (!root.composerToolsExpanded) root.closeComposerPopups()
          }
          background: Rectangle {
            radius: 10
            color: compactComposerToolsButton.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
          }
        }

        TextArea {
          id: messageInput
          Layout.fillWidth: true
          Layout.minimumWidth: 140
          Layout.preferredHeight: Math.max(42, Math.min(140, implicitHeight))
          Layout.maximumHeight: 140
          font.pixelSize: Theme.chatFontSize

          readOnly: false
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
                if (!root.canSendMessages) {
                  if (typeof window !== "undefined" && window.showRestrictionAlert) {
                    window.showRestrictionAlert("Posting Restricted", "You are not allowed to send messages in this chat.")
                  }
                  event.accepted = true
                  return
                }
                var replyId = (root.activeReply && root.activeReply.messageId) ? root.activeReply.messageId : 0
                var quoteText = (root.activeReply && root.activeReply.text) ? root.activeReply.text : ""
                root.lastSentText = text.trim()
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
            if (!root.canSendMessages) {
              if (typeof window !== "undefined" && window.showRestrictionAlert) {
                window.showRestrictionAlert("Posting Restricted", "You are not allowed to send messages in this chat.")
              }
              return
            }
            if (messageInput.text.trim() !== "") {
              var replyId = (root.activeReply && root.activeReply.messageId) ? root.activeReply.messageId : 0
              var quoteText = (root.activeReply && root.activeReply.text) ? root.activeReply.text : ""
              root.lastSentText = messageInput.text.trim()
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

    Rectangle {
      id: compactComposerToolsPopup
      parent: root
      visible: opacity > 0
      opacity: (root.composerControlsCollapsed && root.composerToolsExpanded) ? 1.0 : 0.0

      // Calculate absolute position centered above compactComposerToolsButton
      property var arrowPos: compactComposerToolsButton.mapToItem(root, 0, 0)
      x: Math.max(8, Math.min(root.width - width - 8,
        arrowPos.x + (compactComposerToolsButton.width - width) / 2))
      property real targetY: arrowPos.y - height - 8
      y: (root.composerControlsCollapsed && root.composerToolsExpanded) ? targetY : targetY + 12

      width: 42
      height: compactToolsColumn.implicitHeight + 12
      radius: width / 2
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.95)
      border.color: Theme.divider
      border.width: 1
      z: 70

      // Subtle pill glow/inner highlight
      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
      }

      Column {
        id: compactToolsColumn
        anchors.centerIn: parent
        spacing: 4

        ToolButton {
          implicitWidth: 32; implicitHeight: 32; padding: 0
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/emoji.svg"
          icon.width: 18; icon.height: 18
          icon.color: hovered ? Theme.accent : Theme.secondaryText
          ToolTip.visible: hovered
          ToolTip.text: "Emojis"
          ToolTip.delay: 300
          background: Rectangle {
            radius: 16
            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
          }
          onClicked: { root.toggleComposerPopup("emoji"); root.composerToolsExpanded = false }
        }
        ToolButton {
          implicitWidth: 32; implicitHeight: 32; padding: 0
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/sticker.svg"
          icon.width: 18; icon.height: 18
          icon.color: hovered ? Theme.accent : Theme.secondaryText
          ToolTip.visible: hovered
          ToolTip.text: "Stickers"
          ToolTip.delay: 300
          background: Rectangle {
            radius: 16
            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
          }
          onClicked: { root.toggleComposerPopup("sticker"); root.composerToolsExpanded = false }
        }
        ToolButton {
          implicitWidth: 32; implicitHeight: 32; padding: 0
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/gif.svg"
          icon.width: 18; icon.height: 18
          icon.color: hovered ? Theme.accent : Theme.secondaryText
          ToolTip.visible: hovered
          ToolTip.text: "GIFs"
          ToolTip.delay: 300
          background: Rectangle {
            radius: 16
            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
          }
          onClicked: { root.toggleComposerPopup("gif"); root.composerToolsExpanded = false }
        }
        ToolButton {
          implicitWidth: 32; implicitHeight: 32; padding: 0
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/attach.svg"
          icon.width: 18; icon.height: 18
          icon.color: hovered ? Theme.accent : Theme.secondaryText
          ToolTip.visible: hovered
          ToolTip.text: "Attach file"
          ToolTip.delay: 300
          background: Rectangle {
            radius: 16
            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
          }
          onClicked: { fileDialog.open(); root.composerToolsExpanded = false }
        }
      }

      Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
      Behavior on y {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
    }

    // === Emoji Pop-up Box (Above Emoji button) ===
    Rectangle {
      id: emojiBoxPopup
      z: 60
      anchors.bottom: composerCol.top
      anchors.bottomMargin: 8
      anchors.left: composerCol.left
      width: Math.min(340, parent.width - 28)
      height: 290
      radius: 16
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.96)
      border.color: Theme.divider
      border.width: 1
      visible: opacity > 0
      opacity: root.activeComposerPopup === "emoji" ? 1.0 : 0.0

      Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
      }

      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: 17
        color: Qt.rgba(0, 0, 0, 0.32)
        z: -1
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Label {
            text: "All Emojis"
            font.pixelSize: 13
            font.bold: true
            color: Theme.primaryText
          }
          Item { Layout.fillWidth: true }
          ToolButton {
            text: "✕"
            font.pixelSize: 11
            implicitWidth: 24
            implicitHeight: 24
            focusPolicy: Qt.NoFocus
            onClicked: root.closeComposerPopups()
            background: Rectangle {
              radius: 12
              color: parent.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            }
          }
        }

        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true

          Grid {
            columns: 8
            spacing: 6
            width: parent.width

            readonly property var allEmojis: [
              "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣",
              "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰",
              "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜",
              "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳", "😏",
              "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣",
              "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠",
              "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨",
              "😰", "😥", "😓", "🤗", "🤔", "🤭", "🤫", "🤥",
              "😶", "😐", "😑", "😬", "🙄", "😯", "😦", "😧",
              "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "🤐",
              "🥴", "🤢", "🤮", "🤧", "😷", "🤒", "🤕", "🤑",
              "🤠", "😈", "👿", "👹", "👺", "🤡", "💩", "👻",
              "💀", "☠️", "👽", "👾", "🤖", "🎃", "😺", "😸",
              "👍", "👎", "👊", "✊", "🤛", "🤜", "🤞", "✌️",
              "🤟", "🤘", "👌", "🤌", "🤏", "👈", "👉", "👆",
              "👇", "☝️", "✋", "🤚", "🖐️", "🖖", "👋", "🤙",
              "💪", "🦾", "🖕", "✍️", "🙏", "🤝", "💅", "🗣️",
              "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
              "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖",
              "💘", "💝", "💟", "🔥", "✨", "⚡", "💥", "🎉",
              "🎊", "🎈", "🎂", "🎁", "🏆", "🥇", "⭐", "🌟"
            ]

            Repeater {
              model: parent.allEmojis
              delegate: Rectangle {
                required property var modelData
                readonly property string charEmoji: modelData
                width: 32
                height: 32
                radius: 6
                color: itemMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"

                Label {
                  anchors.centerIn: parent
                  text: charEmoji
                  font.pixelSize: 20
                }

                MouseArea {
                  id: itemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    messageInput.insert(messageInput.cursorPosition, charEmoji)
                    messageInput.forceActiveFocus()
                  }
                }
              }
            }
          }
        }
      }
    }

    // === Sticker Pop-up Box (Above Sticker button) ===
    Rectangle {
      id: stickerBoxPopup
      z: 60
      anchors.bottom: composerCol.top
      anchors.bottomMargin: 8
      anchors.left: composerCol.left
      width: Math.min(360, parent.width - 28)
      height: 310
      radius: 16
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.96)
      border.color: Theme.divider
      border.width: 1
      visible: opacity > 0
      opacity: root.activeComposerPopup === "sticker" ? 1.0 : 0.0

      Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
      }

      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: 17
        color: Qt.rgba(0, 0, 0, 0.32)
        z: -1
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Label {
            text: "Popular Stickers"
            font.pixelSize: 13
            font.bold: true
            color: Theme.primaryText
          }
          Item { Layout.fillWidth: true }
          ToolButton {
            text: "✕"
            font.pixelSize: 11
            implicitWidth: 24
            implicitHeight: 24
            focusPolicy: Qt.NoFocus
            onClicked: root.closeComposerPopups()
            background: Rectangle {
              radius: 12
              color: parent.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            }
          }
        }

        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true

          Grid {
            columns: 4
            spacing: 12
            width: parent.width

            readonly property var stickerList: [
              { emoji: "👋", title: "Wave" },
              { emoji: "🎉", title: "Party" },
              { emoji: "❤️", title: "Love" },
              { emoji: "🔥", title: "Fire" },
              { emoji: "😎", title: "Cool" },
              { emoji: "🥳", title: "Celebrate" },
              { emoji: "🚀", title: "Rocket" },
              { emoji: "💯", title: "Hundred" },
              { emoji: "👏", title: "Clap" },
              { emoji: "⭐", title: "Star" },
              { emoji: "🤩", title: "Starstruck" },
              { emoji: "⚡", title: "Electric" }
            ]

            Repeater {
              model: parent.stickerList
              delegate: Rectangle {
                required property var modelData
                readonly property var sData: modelData
                width: 68
                height: 68
                radius: 12
                color: sMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                border.color: sMouse.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on scale {
                  NumberAnimation { duration: 120 }
                }
                scale: sMouse.containsMouse ? 1.08 : 1.0

                Column {
                  anchors.centerIn: parent
                  spacing: 2
                  Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sData.emoji
                    font.pixelSize: 32
                  }
                  Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sData.title
                    font.pixelSize: 9
                    color: Theme.secondaryText
                  }
                }

                MouseArea {
                  id: sMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var replyId = (root.activeReply && root.activeReply.messageId) ? root.activeReply.messageId : 0
                    var quoteText = (root.activeReply && root.activeReply.text) ? root.activeReply.text : ""
                    root.sendMessageRequested(sData.emoji, replyId, quoteText)
                    root.clearReplyTarget()
                    root.closeComposerPopups()
                  }
                }
              }
            }
          }
        }
      }
    }

    // === GIF Pop-up Box (Above GIF button) ===
    Rectangle {
      id: gifBoxPopup
      z: 60
      anchors.bottom: composerCol.top
      anchors.bottomMargin: 8
      anchors.left: composerCol.left
      width: Math.min(360, parent.width - 28)
      height: 280
      radius: 16
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.96)
      border.color: Theme.divider
      border.width: 1
      visible: opacity > 0
      opacity: root.activeComposerPopup === "gif" ? 1.0 : 0.0

      Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
      }

      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: 17
        color: Qt.rgba(0, 0, 0, 0.32)
        z: -1
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Label {
            text: "GIFs"
            font.pixelSize: 13
            font.bold: true
            color: Theme.primaryText
          }
          Item { Layout.fillWidth: true }
          ToolButton {
            text: "✕"
            font.pixelSize: 11
            implicitWidth: 24
            implicitHeight: 24
            focusPolicy: Qt.NoFocus
            onClicked: root.closeComposerPopups()
            background: Rectangle {
              radius: 12
              color: parent.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            }
          }
        }

        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true

          Grid {
            columns: 3
            spacing: 8
            width: parent.width

            readonly property var gifCategories: [
              { tag: "Trending", icon: "🔥" },
              { tag: "Happy", icon: "😄" },
              { tag: "Sad", icon: "😢" },
              { tag: "Dancing", icon: "💃" },
              { tag: "Confused", icon: "🤔" },
              { tag: "Party", icon: "🥳" }
            ]

            Repeater {
              model: parent.gifCategories
              delegate: Rectangle {
                required property var modelData
                width: 96
                height: 72
                radius: 10
                color: gMouse.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Column {
                  anchors.centerIn: parent
                  spacing: 4
                  Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.icon
                    font.pixelSize: 24
                  }
                  Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.tag
                    font.pixelSize: 11
                    color: gMouse.containsMouse ? Theme.accentText : Theme.primaryText
                    font.weight: Font.DemiBold
                  }
                }

                MouseArea {
                  id: gMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var replyId = (root.activeReply && root.activeReply.messageId) ? root.activeReply.messageId : 0
                    var quoteText = (root.activeReply && root.activeReply.text) ? root.activeReply.text : ""
                    root.sendMessageRequested(modelData.icon, replyId, quoteText)
                    root.clearReplyTarget()
                    root.closeComposerPopups()
                  }
                }
              }
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
    visible: !root.hasConversation && !root.isSecondaryPane
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
