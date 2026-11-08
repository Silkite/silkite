import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
  id: root

  property var contactModel
  property var selectedUserId: 0
  property bool pointerInside: false
  readonly property bool compactMode: width < 140

  // "contacts" or "newGroup"
  property string currentMode: "contacts"

  // Selected contacts for group creation: Set or array of userIds
  property var selectedGroupMemberIds: []

  signal contactSelected(var userId, var chatId)
  signal openInSplitRequested(var chatId)
  signal dragStarted(var contactData, point startPos)
  signal dragMoved(point globalPos)
  signal dragEnded(point globalPos)

  NewContactDialog {
    id: newContactDialog
  }

  function toggleGroupMember(userId) {
    var arr = selectedGroupMemberIds.slice()
    var idx = arr.indexOf(userId)
    if (idx >= 0) {
      arr.splice(idx, 1)
    } else {
      arr.push(userId)
    }
    selectedGroupMemberIds = arr
  }

  function isMemberSelected(userId) {
    return selectedGroupMemberIds.indexOf(userId) >= 0
  }

  // Outer ambient shadow
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

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: 17
      color: "transparent"
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1
    }

    HoverHandler {
      onHoveredChanged: root.pointerInside = hovered
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 10

      // Top Header Area (Smooth transition between Contacts bar and Group bar)
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.currentMode === "newGroup" ? 82 : 40
        clip: true

        Behavior on Layout.preferredHeight {
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Mode 1: Standard Contacts Header
        Item {
          id: contactsHeaderItem
          anchors.fill: parent
          opacity: root.currentMode === "contacts" ? 1.0 : 0.0
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }

          RowLayout {
            anchors.fill: parent
            spacing: 6

            Label {
              id: contactsHeaderLabel
              text: "Contacts"
              color: Theme.primaryText
              font.pixelSize: 22
              font.bold: true
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            // Create New Group button (multiple people icon)
            ToolButton {
              id: newGroupBtn
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              padding: 0
              focusPolicy: Qt.NoFocus
              ToolTip.visible: hovered
              ToolTip.text: "New Group"
              ToolTip.delay: 400

              icon.source: "qrc:/qt/qml/Silkite/assets/icons/people-team.svg"
              icon.width: 18
              icon.height: 18
              icon.color: hovered ? Theme.accentText : Theme.primaryText

              background: Rectangle {
                radius: 8
                color: newGroupBtn.hovered ? Theme.accent : Theme.controlBackground
                border.color: newGroupBtn.hovered ? Qt.rgba(1, 1, 1, 0.25) : Theme.divider
                border.width: 1
              }

              onClicked: {
                root.selectedGroupMemberIds = []
                groupNameInput.clear()
                root.currentMode = "newGroup"
              }
            }

            // Add Contact button (+ icon)
            ToolButton {
              id: addContactBtn
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              padding: 0
              focusPolicy: Qt.NoFocus
              ToolTip.visible: hovered
              ToolTip.text: "Add Contact"
              ToolTip.delay: 400

              icon.source: "qrc:/qt/qml/Silkite/assets/icons/add.svg"
              icon.width: 18
              icon.height: 18
              icon.color: hovered ? Theme.accentText : Theme.primaryText

              background: Rectangle {
                radius: 8
                color: addContactBtn.hovered ? Theme.accent : Theme.controlBackground
                border.color: addContactBtn.hovered ? Qt.rgba(1, 1, 1, 0.25) : Theme.divider
                border.width: 1
              }

              onClicked: {
                newContactDialog.open()
              }
            }
          }
        }

        // Mode 2: New Group Header
        ColumnLayout {
          id: groupHeaderItem
          anchors.fill: parent
          spacing: 6
          opacity: root.currentMode === "newGroup" ? 1.0 : 0.0
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ToolButton {
              Layout.preferredWidth: 28
              Layout.preferredHeight: 28
              padding: 0
              focusPolicy: Qt.NoFocus
              icon.source: "qrc:/qt/qml/Silkite/assets/icons/arrow-left.svg"
              icon.width: 16
              icon.height: 16
              icon.color: Theme.primaryText

              background: Rectangle {
                radius: 7
                color: parent.hovered ? Theme.controlBackground : "transparent"
                border.color: parent.hovered ? Theme.divider : "transparent"
                border.width: 1
              }

              onClicked: {
                root.currentMode = "contacts"
                root.selectedGroupMemberIds = []
              }
            }

            Label {
              text: "New Group"
              color: Theme.primaryText
              font.pixelSize: 17
              font.bold: true
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            Label {
              text: root.selectedGroupMemberIds.length > 0 ? (root.selectedGroupMemberIds.length + " selected") : ""
              color: Theme.secondaryText
              font.pixelSize: 12
            }
          }

          // Group Name TextField
          TextField {
            id: groupNameInput
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            placeholderText: "Group name..."
            color: Theme.primaryText
            font.pixelSize: 13
            leftPadding: 10
            rightPadding: 10
            selectByMouse: true

            background: Rectangle {
              radius: 9
              color: Theme.controlBackground
              border.color: groupNameInput.activeFocus ? Theme.accent : Theme.divider
              border.width: 1
            }
          }
        }
      }

      // Search field (for filtering contacts)
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 10
        color: Theme.controlBackground
        border.color: searchInput.activeFocus ? Theme.accent : Theme.divider
        border.width: 1
        clip: true

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 6

          Image {
            source: "qrc:/qt/qml/Silkite/assets/icons/search.svg"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            fillMode: Image.PreserveAspectFit
            opacity: 0.6
          }

          TextField {
            id: searchInput
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: "Search contacts..."
            color: Theme.primaryText
            font.pixelSize: 13
            background: Item {}
            padding: 0
            verticalAlignment: Text.AlignVCenter
            onTextChanged: {
              if (root.contactModel) {
                root.contactModel.filterText = text
              }
            }
          }

          ToolButton {
            visible: searchInput.text.length > 0
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            padding: 0
            icon.source: "qrc:/qt/qml/Silkite/assets/icons/close.svg"
            icon.width: 12
            icon.height: 12
            icon.color: Theme.secondaryText
            background: Item {}
            onClicked: searchInput.clear()
          }
        }
      }

      // Contact List View
      ListView {
        id: contactListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: root.contactModel
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
          id: scrollBar
          active: true
          policy: ScrollBar.AsNeeded
          contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: scrollBar.hovered ? Theme.accent : Theme.divider
            opacity: 0.6
          }
        }

        delegate: Item {
          id: contactDelegate
          width: contactListView.width
          height: 54

          readonly property var uId: model.userId
          readonly property var cId: model.chatId
          readonly property string cName: model.fullName || model.name || "Contact"
          readonly property string cInitials: model.initials || "?"
          readonly property string cAvatarColor: model.avatarColor || "#526C8A"
          readonly property string cAvatarPath: model.avatarPath || ""
          readonly property string cPhoneNumber: model.phoneNumber || ""
          readonly property string cStatusText: model.statusText || ""
          readonly property bool cIsOnline: model.isOnline || false
          readonly property bool isGroupChecked: root.isMemberSelected(uId)
          readonly property bool isSelected: root.selectedUserId === uId

          Rectangle {
            id: delegateBg
            anchors.fill: parent
            radius: 12
            color: contactDelegate.isSelected
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                : (delegateMouseArea.containsMouse ? Theme.controlBackground : "transparent")
            border.color: contactDelegate.isSelected ? Theme.accent : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 8

              // In Group Mode: Checkmark on the left side
              Item {
                Layout.preferredWidth: root.currentMode === "newGroup" ? 24 : 0
                Layout.preferredHeight: 24
                visible: root.currentMode === "newGroup"
                clip: true

                Behavior on Layout.preferredWidth {
                  NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Rectangle {
                  anchors.centerIn: parent
                  width: 20
                  height: 20
                  radius: 6
                  color: contactDelegate.isGroupChecked ? Theme.accent : "transparent"
                  border.color: contactDelegate.isGroupChecked ? Theme.accent : Theme.divider
                  border.width: 1.5

                  Image {
                    anchors.centerIn: parent
                    source: "qrc:/qt/qml/Silkite/assets/icons/checkmark.svg"
                    width: 14
                    height: 14
                    visible: contactDelegate.isGroupChecked
                  }
                }
              }

              // Contact Avatar
              Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                z: 2

                Rectangle {
                  id: avatarBg
                  anchors.fill: parent
                  radius: width / 2
                  color: contactDelegate.cAvatarColor

                  Text {
                    anchors.centerIn: parent
                    text: contactDelegate.cInitials
                    color: Theme.accentText
                    font.pixelSize: 15
                    font.bold: true
                    visible: !avatarImg.visible
                  }

                  Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: contactDelegate.cAvatarPath ? ("file://" + contactDelegate.cAvatarPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: contactDelegate.cAvatarPath !== "" && status === Image.Ready
                    layer.enabled: true
                    layer.effect: OpacityMask {
                      maskSource: Rectangle {
                        width: avatarBg.width
                        height: avatarBg.height
                        radius: width / 2
                      }
                    }
                  }
                }

                // Click avatar to view profile popup
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onClicked: {
                    if (window && typeof window.showContactProfile === "function") {
                      window.showContactProfile({
                        userId: contactDelegate.uId,
                        chatId: contactDelegate.cId,
                        name: contactDelegate.cName,
                        fullName: contactDelegate.cName,
                        phoneNumber: contactDelegate.cPhoneNumber,
                        statusText: contactDelegate.cStatusText,
                        isOnline: contactDelegate.cIsOnline,
                        initials: contactDelegate.cInitials,
                        avatarColor: contactDelegate.cAvatarColor,
                        avatarPath: contactDelegate.cAvatarPath
                      })
                    }
                  }
                }

                // Online badge
                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.right: parent.right
                  width: 10
                  height: 10
                  radius: 5
                  color: Theme.accent
                  border.color: Theme.panelBackground
                  border.width: 1.5
                  visible: contactDelegate.cIsOnline
                }
              }

              // Name and status
              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Label {
                  text: contactDelegate.cName
                  color: Theme.primaryText
                  font.pixelSize: 14
                  font.bold: true
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }

                Label {
                  text: contactDelegate.cStatusText || (contactDelegate.cIsOnline ? "online" : "offline")
                  color: contactDelegate.cIsOnline ? Theme.accent : Theme.secondaryText
                  font.pixelSize: 12
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }
              }
            }

            // Mouse handling for clicks and dragging to split pane
            MouseArea {
              id: delegateMouseArea
              anchors.fill: parent
              hoverEnabled: true
              preventStealing: isDragging

              property bool isLongPressed: false
              property bool isDragging: false
              property point pressPos: Qt.point(0, 0)

              Timer {
                id: longPressTimer
                interval: 320
                repeat: false
                onTriggered: {
                  if (delegateMouseArea.pressed && (delegateMouseArea.pressedButtons & Qt.LeftButton)) {
                    if (root.currentMode === "newGroup") {
                      // In group mode, long press can toggle selection or drag
                      root.toggleGroupMember(contactDelegate.uId)
                      return
                    }
                    delegateMouseArea.isLongPressed = true
                    delegateMouseArea.isDragging = true
                    var gPos = delegateMouseArea.mapToItem(null, delegateMouseArea.pressPos.x, delegateMouseArea.pressPos.y)
                    var cInfo = {
                      chatId: contactDelegate.cId,
                      userId: contactDelegate.uId,
                      name: contactDelegate.cName,
                      initials: contactDelegate.cInitials,
                      avatarColor: contactDelegate.cAvatarColor,
                      avatarPath: contactDelegate.cAvatarPath,
                      lastMessage: "",
                      time: ""
                    }
                    root.dragStarted(cInfo, gPos)
                  }
                }
              }

              onPressed: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                  pressPos = Qt.point(mouse.x, mouse.y)
                  isLongPressed = false
                  isDragging = false
                  longPressTimer.start()
                }
              }

              onPositionChanged: function(mouse) {
                if (isDragging) {
                  var gPos = delegateMouseArea.mapToItem(null, mouse.x, mouse.y)
                  root.dragMoved(gPos)
                } else if (!isLongPressed) {
                  var dx = mouse.x - pressPos.x
                  var dy = mouse.y - pressPos.y
                  if ((dx * dx + dy * dy) > 64) {
                    longPressTimer.stop()
                  }
                }
              }

              onReleased: function(mouse) {
                longPressTimer.stop()
                if (isDragging) {
                  var gPos = delegateMouseArea.mapToItem(null, mouse.x, mouse.y)
                  root.dragEnded(gPos)
                  isDragging = false
                  isLongPressed = false
                } else if (!isLongPressed && mouse.button === Qt.LeftButton) {
                  if (root.currentMode === "newGroup") {
                    root.toggleGroupMember(contactDelegate.uId)
                  } else {
                    root.selectedUserId = contactDelegate.uId
                    root.contactSelected(contactDelegate.uId, contactDelegate.cId)
                  }
                }
              }

              onCanceled: {
                longPressTimer.stop()
                if (isDragging) {
                  root.dragEnded(Qt.point(-1, -1))
                  isDragging = false
                  isLongPressed = false
                }
              }
            }
          }
        }

        // Empty placeholder
        Item {
          anchors.fill: parent
          visible: contactListView.count === 0

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Image {
              Layout.alignment: Qt.AlignHCenter
              source: "qrc:/qt/qml/Silkite/assets/icons/people.svg"
              Layout.preferredWidth: 36
              Layout.preferredHeight: 36
              opacity: 0.35
            }

            Label {
              Layout.alignment: Qt.AlignHCenter
              text: "No new contacts"
              color: Theme.secondaryText
              font.pixelSize: 14
            }

            Label {
              Layout.alignment: Qt.AlignHCenter
              text: "All synced contacts have existing chats"
              color: Qt.rgba(Theme.secondaryText.r, Theme.secondaryText.g, Theme.secondaryText.b, 0.6)
              font.pixelSize: 11
            }
          }
        }
      }

      // Group Creation Action Bar at the very bottom (visible when in newGroup mode)
      Item {
        id: createGroupBottomBar
        Layout.fillWidth: true
        Layout.preferredHeight: root.currentMode === "newGroup" ? 44 : 0
        visible: root.currentMode === "newGroup"
        clip: true

        Behavior on Layout.preferredHeight {
          NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Button {
          anchors.fill: parent
          text: root.selectedGroupMemberIds.length > 0
              ? ("Create Group (" + root.selectedGroupMemberIds.length + ")")
              : "Select members to create"
          enabled: groupNameInput.text.trim().length > 0 && root.selectedGroupMemberIds.length > 0

          contentItem: Label {
            text: parent.text
            color: parent.enabled ? Theme.accentText : Theme.secondaryText
            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          background: Rectangle {
            radius: 12
            color: parent.enabled ? (parent.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : Theme.controlBackground
            border.color: parent.enabled ? Qt.rgba(1, 1, 1, 0.2) : Theme.divider
            border.width: 1
            opacity: parent.enabled ? 1.0 : 0.6
          }

          onClicked: {
            var title = groupNameInput.text.trim()
            var members = root.selectedGroupMemberIds
            telegramClient.createNewGroup(title, members)
            root.currentMode = "contacts"
            root.selectedGroupMemberIds = []
            groupNameInput.clear()
          }
        }
      }
    }
  }
}
