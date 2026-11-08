import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Popup {
  id: root

  modal: true
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  x: Math.round((parent.width - width) / 2)
  y: Math.round((parent.height - height) / 2)
  width: Math.min(parent.width - 48, 360)
  height: Math.min(parent.height - 48, 620)
  padding: 0
  topPadding: 0
  bottomPadding: 0
  leftPadding: 0
  rightPadding: 0

  // Profile data properties
  property var userId: 0
  property var chatId: 0
  property string fullName: ""
  property string firstName: ""
  property string lastName: ""
  property string username: ""
  property string phoneNumber: ""
  property string statusText: ""
  property bool isOnline: false
  property string initials: "?"
  property string avatarColor: "#526C8A"
  property string avatarPath: ""
  property string bio: ""
  property string birthdate: ""
  property string note: ""
  property int groupsInCommon: 0
  property bool isBlocked: false
  property bool isContact: true

  // Photo gallery
  property var photoList: []

  function openProfile(data) {
    if (!data) return
    userId = data.userId || 0
    chatId = data.chatId || 0
    fullName = data.fullName || data.name || ""
    firstName = data.firstName || ""
    lastName = data.lastName || ""
    username = data.username || ""
    phoneNumber = data.phoneNumber || ""
    statusText = data.statusText || ""
    isOnline = !!data.isOnline
    initials = data.initials || "?"
    avatarColor = data.avatarColor || "#526C8A"
    avatarPath = data.avatarPath || ""
    bio = data.bio || ""
    birthdate = data.birthdate || ""
    note = data.note || ""
    groupsInCommon = data.groupsInCommon || 0
    isBlocked = !!data.isBlocked
    isContact = (data.isContact !== undefined) ? data.isContact : true

    // Initialize gallery with avatar if present
    if (avatarPath !== "") {
      photoList = [{ filePath: avatarPath }]
    } else {
      photoList = []
    }

    if (typeof telegramClient !== "undefined") {
      telegramClient.loadUserProfile(userId, chatId)
    }

    open()
  }

  Connections {
    target: (typeof telegramClient !== "undefined") ? telegramClient : null

    function onUserProfileLoaded(uId, profile) {
      if (root.userId === 0 || uId === root.userId) {
        if (root.userId === 0 && uId !== 0) root.userId = uId
        if (profile.fullName) root.fullName = profile.fullName
        if (profile.firstName) root.firstName = profile.firstName
        if (profile.lastName) root.lastName = profile.lastName
        if (profile.initials) root.initials = profile.initials
        if (profile.username) root.username = profile.username
        if (profile.phoneNumber) root.phoneNumber = profile.phoneNumber
        if (profile.statusText) root.statusText = profile.statusText
        if (profile.isOnline !== undefined) root.isOnline = profile.isOnline
        if (profile.avatarPath && profile.avatarPath !== "") {
          root.avatarPath = profile.avatarPath
          if (root.photoList.length === 0) {
            root.photoList = [{ filePath: profile.avatarPath }]
          }
        }
        if (profile.bio !== undefined) root.bio = profile.bio
        if (profile.birthdate !== undefined) root.birthdate = profile.birthdate
        if (profile.note !== undefined) root.note = profile.note
        if (profile.groupsInCommon !== undefined) root.groupsInCommon = profile.groupsInCommon
        if (profile.isBlocked !== undefined) root.isBlocked = profile.isBlocked
        if (profile.isContact !== undefined) root.isContact = profile.isContact
      }
    }

    function onUserProfilePhotosLoaded(uId, photos) {
      if (root.userId === 0 || uId === root.userId) {
        if (root.userId === 0 && uId !== 0) root.userId = uId
        if (photos && photos.length > 0) {
          var validPhotos = []
          for (var i = 0; i < photos.length; ++i) {
            if (photos[i].filePath && photos[i].filePath !== "") {
              validPhotos.push(photos[i])
            }
          }
          if (validPhotos.length > 0) {
            root.photoList = validPhotos
          } else if (root.avatarPath !== "") {
            root.photoList = [{ filePath: root.avatarPath }]
          }
        }
      }
    }

    function onUserBlockedStatusChanged(uId, blocked) {
      if (root.userId === 0 || uId === root.userId) {
        root.isBlocked = blocked
      }
    }

    function onChatDeleted(cId) {
      if (cId === root.chatId) {
        root.close()
      }
    }
  }

  background: Item {
    Rectangle {
      anchors.fill: dialogGlass
      anchors.topMargin: 4
      anchors.bottomMargin: -4
      anchors.leftMargin: -2
      anchors.rightMargin: -2
      radius: dialogGlass.radius + 2
      color: Qt.rgba(0, 0, 0, 0.3)
      z: -1
    }
    Rectangle {
      id: dialogGlass
      anchors.fill: parent
      radius: 20
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.96)
      border.color: Theme.divider
      border.width: 1

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 19
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
      }
    }
  }

  contentItem: Item {
    anchors.fill: parent
    clip: true

    layer.enabled: true
    layer.effect: OpacityMask {
      maskSource: Rectangle {
        width: root.width
        height: root.height
        radius: 20
      }
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      // Top Header / Gallery Section (Square profile image flush with profile box edges)
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: width
        clip: true

        // Photo Gallery Carousel / SwipeView
        SwipeView {
          id: photoSwipeView
          anchors.fill: parent
          clip: true
          interactive: root.photoList.length > 1

          Repeater {
            model: root.photoList.length > 0 ? root.photoList : [ { filePath: root.avatarPath } ]
            delegate: Item {
              width: photoSwipeView.width
              height: photoSwipeView.height

              Rectangle {
                anchors.fill: parent
                color: root.avatarColor

                // Fallback Initials when no photo available
                Text {
                  anchors.centerIn: parent
                  text: root.initials
                  color: "#FFFFFF"
                  font.pixelSize: 72
                  font.bold: true
                  visible: !galleryImage.visible
                }

                Image {
                  id: galleryImage
                  anchors.fill: parent
                  source: modelData.filePath ? ("file://" + modelData.filePath) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true
                  visible: modelData.filePath && status === Image.Ready
                }
              }
            }
          }
        }

        // Top Gradient Scrim for action buttons visibility
        Rectangle {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: 64
          gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
            GradientStop { position: 1.0; color: "transparent" }
          }
        }

        // Bottom Gradient Scrim for Full Name contrast
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: 90
          gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
          }
        }

        // Page Indicator Dots (Centered above name if multiple photos)
        PageIndicator {
          id: pageIndicator
          count: photoSwipeView.count
          currentIndex: photoSwipeView.currentIndex
          anchors.bottom: nameStatusColumn.top
          anchors.bottomMargin: 4
          anchors.horizontalCenter: parent.horizontalCenter
          visible: photoSwipeView.count > 1

          delegate: Rectangle {
            implicitWidth: 6
            implicitHeight: 6
            radius: 3
            color: index === pageIndicator.currentIndex ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.45)
          }
        }

        // Full Name displayed bottom middle of profile photo
        ColumnLayout {
          id: nameStatusColumn
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 14
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          spacing: 2

          Label {
            text: root.fullName
            font.pixelSize: 20
            font.bold: true
            color: "#FFFFFF"
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Label {
            text: root.statusText !== "" ? root.statusText : (root.isOnline ? "online" : "offline")
            font.pixelSize: 13
            color: root.isOnline ? "#4CAF50" : Qt.rgba(1, 1, 1, 0.8)
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
          }
        }

        // Close Button (Top-Left)
        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: 12
          width: 36
          height: 36
          radius: 12
          color: closeMouse.containsMouse ? Theme.accent : Qt.rgba(0, 0, 0, 0.4)
          border.color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
          border.width: 1
          z: 10

          Behavior on color { ColorAnimation { duration: 120 } }

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: 1
            visible: closeMouse.containsMouse
          }

          Image {
            anchors.centerIn: parent
            source: "qrc:/qt/qml/Silkite/assets/icons/close.svg"
            width: 18
            height: 18
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }

        // Hamburger Menu Button (Top-Right)
        Rectangle {
          id: menuBtn
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 12
          width: 36
          height: 36
          radius: 12
          color: (menuMouse.containsMouse || profileMenu.opened) ? Theme.accent : Qt.rgba(0, 0, 0, 0.4)
          border.color: (menuMouse.containsMouse || profileMenu.opened) ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
          border.width: 1
          z: 10

          Behavior on color { ColorAnimation { duration: 120 } }

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: 1
            visible: menuMouse.containsMouse || profileMenu.opened
          }

          Image {
            anchors.centerIn: parent
            source: "qrc:/qt/qml/Silkite/assets/icons/menu.svg"
            width: 18
            height: 18
          }

          MouseArea {
            id: menuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: profileMenu.open()
          }

          Menu {
            id: profileMenu
            y: menuBtn.height + 4
            x: -140
            width: 170

            background: Rectangle {
              radius: 12
              color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.98)
              border.color: Theme.divider
              border.width: 1
            }

            MenuItem {
              contentItem: RowLayout {
                spacing: 10
                Image {
                  source: "qrc:/qt/qml/Silkite/assets/icons/block.svg"
                  Layout.preferredWidth: 16
                  Layout.preferredHeight: 16
                }
                Label {
                  text: root.isBlocked ? "Unblock Contact" : "Block Contact"
                  color: parent.highlighted ? Theme.accentText : Theme.primaryText
                  font.pixelSize: 13
                  font.bold: true
                  Layout.fillWidth: true
                }
              }
              background: Rectangle {
                radius: 8
                color: parent.highlighted ? Theme.accent : "transparent"
              }
              onTriggered: {
                if (typeof telegramClient !== "undefined" && root.userId !== 0) {
                  telegramClient.blockUser(root.userId, !root.isBlocked)
                }
              }
            }

            MenuItem {
              visible: root.chatId !== 0
              contentItem: RowLayout {
                spacing: 10
                Image {
                  source: "qrc:/qt/qml/Silkite/assets/icons/delete.svg"
                  Layout.preferredWidth: 16
                  Layout.preferredHeight: 16
                }
                Label {
                  text: "Delete Chat"
                  color: "#FF5252"
                  font.pixelSize: 13
                  font.bold: true
                  Layout.fillWidth: true
                }
              }
              background: Rectangle {
                radius: 8
                color: parent.highlighted ? Qt.rgba(255, 82, 82, 0.18) : "transparent"
              }
              onTriggered: {
                if (typeof telegramClient !== "undefined" && root.chatId !== 0) {
                  telegramClient.deleteChatHistory(root.chatId, true, true)
                }
              }
            }
          }
        }
      }

      // Scrollable content with profile information items directly integrated
      ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Item {
          width: parent.width
          implicitHeight: profileDetailsColumn.implicitHeight + 48

          ColumnLayout {
            id: profileDetailsColumn
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 24
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 16

          // Phone Number
          ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            visible: root.phoneNumber !== ""

            Label {
              text: root.phoneNumber
              font.pixelSize: 15
              font.bold: true
              color: Theme.primaryText
              textFormat: Text.PlainText
            }
            Label {
              text: "Phone"
              font.pixelSize: 12
              color: Theme.secondaryText
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.divider
            opacity: 0.6
            visible: root.phoneNumber !== "" && (root.username !== "" || root.bio !== "")
          }

          // Username
          ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            visible: root.username !== ""

            Label {
              text: "@" + root.username
              font.pixelSize: 15
              font.bold: true
              color: Theme.accent
              textFormat: Text.PlainText
            }
            Label {
              text: "Username"
              font.pixelSize: 12
              color: Theme.secondaryText
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.divider
            opacity: 0.6
            visible: root.username !== "" && root.bio !== ""
          }

          // Bio / About
          ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            visible: root.bio !== ""

            Label {
              text: root.bio
              font.pixelSize: 14
              lineHeight: 1.25
              color: Theme.primaryText
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }
            Label {
              text: "Bio"
              font.pixelSize: 12
              color: Theme.secondaryText
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.divider
            opacity: 0.6
            visible: (root.phoneNumber !== "" || root.username !== "" || root.bio !== "") && (root.birthdate !== "" || root.note !== "" || root.groupsInCommon > 0)
          }

          // Birthday
          ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            visible: root.birthdate !== ""

            Label {
              text: root.birthdate
              font.pixelSize: 15
              font.bold: true
              color: Theme.primaryText
            }
            Label {
              text: "Birthday"
              font.pixelSize: 12
              color: Theme.secondaryText
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.divider
            opacity: 0.6
            visible: root.birthdate !== "" && (root.note !== "" || root.groupsInCommon > 0)
          }

          // Personal Note
          ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            visible: root.note !== ""

            Label {
              text: root.note
              font.pixelSize: 14
              lineHeight: 1.25
              color: Theme.primaryText
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }
            Label {
              text: "Personal Note"
              font.pixelSize: 12
              color: Theme.secondaryText
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.divider
            opacity: 0.6
            visible: root.note !== "" && root.groupsInCommon > 0
          }

          // Groups in Common
          ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            visible: root.groupsInCommon > 0

            Label {
              text: root.groupsInCommon + (root.groupsInCommon === 1 ? " group in common" : " groups in common")
              font.pixelSize: 15
              font.bold: true
              color: Theme.primaryText
            }
            Label {
              text: "Groups in common"
              font.pixelSize: 12
              color: Theme.secondaryText
            }
          }

          // Blocked notice row
          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: root.isBlocked
            spacing: 12

            Image {
              source: "qrc:/qt/qml/Silkite/assets/icons/block.svg"
              Layout.preferredWidth: 20
              Layout.preferredHeight: 20
            }

            Label {
              text: "This contact is currently blocked"
              font.pixelSize: 13
              color: "#FF5252"
              font.bold: true
              Layout.fillWidth: true
            }
          }
        }
      }
    }
    }
  }
}
