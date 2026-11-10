import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects

Popup {
  id: root

  modal: true
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  x: Math.round((parent.width - width) / 2)
  y: Math.round((parent.height - height) / 2)
  width: Math.min(parent.width - 48, 380)
  height: Math.min(parent.height - 48, 650)
  padding: 0
  topPadding: 0
  bottomPadding: 0
  leftPadding: 0
  rightPadding: 0

  // Profile data properties
  property var userId: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.userId) ? telegramClient.myProfile.userId : 0
  property string fullName: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.fullName) ? telegramClient.myProfile.fullName : ""
  property string firstName: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.firstName) ? telegramClient.myProfile.firstName : ""
  property string lastName: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.lastName) ? telegramClient.myProfile.lastName : ""
  property string username: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.username) ? telegramClient.myProfile.username : ""
  property string phoneNumber: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.phoneNumber) ? telegramClient.myProfile.phoneNumber : ""
  property string statusText: "online"
  property string initials: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.initials) ? telegramClient.myProfile.initials : "?"
  property string avatarColor: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.avatarColor) ? telegramClient.myProfile.avatarColor : "#526C8A"
  property string avatarPath: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.avatarPath) ? telegramClient.myProfile.avatarPath : ""
  property string bio: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.bio) ? telegramClient.myProfile.bio : ""

  // Photo gallery
  property var photoList: []

  // Edit mode tracking
  property bool isEditing: false

  function refreshFromMyProfile() {
    if (typeof telegramClient === "undefined") return
    var prof = telegramClient.myProfile || {}
    if (prof.userId) userId = prof.userId
    if (prof.fullName) fullName = prof.fullName
    if (prof.firstName) firstName = prof.firstName
    if (prof.lastName) lastName = prof.lastName
    if (prof.username !== undefined) username = prof.username
    if (prof.phoneNumber) phoneNumber = prof.phoneNumber
    if (prof.avatarColor) avatarColor = prof.avatarColor
    if (prof.initials) initials = prof.initials
    if (prof.avatarPath) {
      avatarPath = prof.avatarPath
      if (photoList.length === 0) {
        photoList = [{ filePath: avatarPath }]
      }
    }
    if (prof.bio !== undefined) bio = prof.bio
  }

  function openProfile() {
    refreshFromMyProfile()
    isEditing = false
    if (typeof telegramClient !== "undefined") {
      telegramClient.loadUserProfile(0, 0)
    }
    open()
  }

  Connections {
    target: (typeof telegramClient !== "undefined") ? telegramClient : null

    function onMyProfileChanged() {
      root.refreshFromMyProfile()
    }

    function onUserProfileLoaded(uId, profile) {
      if (root.userId === 0 || uId === root.userId) {
        if (root.userId === 0 && uId !== 0) root.userId = uId
        if (profile.fullName) root.fullName = profile.fullName
        if (profile.firstName) root.firstName = profile.firstName
        if (profile.lastName) root.lastName = profile.lastName
        if (profile.initials) root.initials = profile.initials
        if (profile.username !== undefined) root.username = profile.username
        if (profile.phoneNumber) root.phoneNumber = profile.phoneNumber
        if (profile.avatarColor) root.avatarColor = profile.avatarColor
        if (profile.avatarPath) {
          root.avatarPath = profile.avatarPath
          if (root.photoList.length === 0) {
            root.photoList = [{ filePath: profile.avatarPath }]
          }
        }
        if (profile.bio !== undefined) root.bio = profile.bio
      }
    }

    function onUserProfilePhotosLoaded(uId, photos) {
      if (root.userId === 0 || uId === root.userId) {
        if (photos && photos.length > 0) {
          root.photoList = photos
        } else if (root.avatarPath !== "") {
          root.photoList = [{ filePath: root.avatarPath }]
        }
      }
    }

    function onContactAvatarUpdated(uId, aPath) {
      if (root.userId === 0 || uId === root.userId) {
        root.avatarPath = aPath
        if (root.photoList.length <= 1) {
          root.photoList = [{ filePath: aPath }]
        }
      }
    }
  }

  // File picker for Set Photo
  FileDialog {
    id: avatarPicker
    title: "Select Profile Photo"
    currentFolder: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0] || ""
    nameFilters: ["Image files (*.jpg *.jpeg *.png *.webp)"]
    onAccepted: {
      var path = avatarPicker.selectedFile.toString()
      if (path.indexOf("file://") === 0) {
        path = path.substring(7)
      }
      if (typeof telegramClient !== "undefined" && path) {
        telegramClient.setProfilePhoto(path)
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

      // Top Gallery Section (Square profile image)
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

        // User's Name displayed on the bottom side of the profile pic
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
            text: root.fullName !== "" ? root.fullName : (root.firstName + (root.lastName ? " " + root.lastName : ""))
            font.pixelSize: 20
            font.bold: true
            color: "#FFFFFF"
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Label {
            text: "online"
            font.pixelSize: 13
            color: "#4CAF50"
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
      }

      // Action Buttons Row: Set Photo & Edit Info (Below profile pic)
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 52

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(Theme.divider.r, Theme.divider.g, Theme.divider.b, 0.12)
        }

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: 1
          color: Theme.divider
          opacity: 0.5
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 16
          anchors.rightMargin: 16
          spacing: 12

          // Set Photo Button
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 10
            color: setPhotoMouse.containsMouse ? Theme.accent : Qt.rgba(Theme.controlBackground.r, Theme.controlBackground.g, Theme.controlBackground.b, 0.8)
            border.color: setPhotoMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Theme.divider
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
              anchors.centerIn: parent
              spacing: 8

              Image {
                source: "qrc:/qt/qml/Silkite/assets/icons/camera.svg"
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
              }

              Label {
                text: "Set Photo"
                font.pixelSize: 13
                font.bold: true
                color: setPhotoMouse.containsMouse ? Theme.accentText : Theme.primaryText
              }
            }

            MouseArea {
              id: setPhotoMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: avatarPicker.open()
            }
          }

          // Edit Info Button
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 10
            color: root.isEditing ? Theme.accent : (editInfoMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : Qt.rgba(Theme.controlBackground.r, Theme.controlBackground.g, Theme.controlBackground.b, 0.8))
            border.color: root.isEditing ? Qt.rgba(1, 1, 1, 0.25) : (editInfoMouse.containsMouse ? Theme.accent : Theme.divider)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
              anchors.centerIn: parent
              spacing: 8

              Image {
                source: "qrc:/qt/qml/Silkite/assets/icons/edit.svg"
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
              }

              Label {
                text: root.isEditing ? "Save Info" : "Edit Info"
                font.pixelSize: 13
                font.bold: true
                color: root.isEditing ? Theme.accentText : (editInfoMouse.containsMouse ? Theme.accent : Theme.primaryText)
              }
            }

            MouseArea {
              id: editInfoMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.isEditing) {
                  // Save edited info
                  if (typeof telegramClient !== "undefined") {
                    var fName = editFirstNameInput.text.trim()
                    var lName = editLastNameInput.text.trim()
                    var bText = editBioInput.text.trim()
                    var uName = editUsernameInput.text.trim()
                    if (uName.startsWith("@")) uName = uName.substring(1).trim()

                    telegramClient.setName(fName, lName)
                    telegramClient.setBio(bText)
                    telegramClient.setUsername(uName)
                  }
                  root.isEditing = false
                } else {
                  editFirstNameInput.text = root.firstName
                  editLastNameInput.text = root.lastName
                  editBioInput.text = root.bio
                  editUsernameInput.text = root.username
                  root.isEditing = true
                }
              }
            }
          }
        }
      }

      // Scrollable content with profile details (Phone, Bio, Username)
      ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Item {
          width: parent.width
          implicitHeight: root.isEditing ? editColumn.implicitHeight + 48 : viewColumn.implicitHeight + 48

          // VIEW MODE
          ColumnLayout {
            id: viewColumn
            visible: !root.isEditing
            anchors.fill: parent
            anchors.topMargin: 18
            anchors.bottomMargin: 24
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 16

            // Phone Number
            ColumnLayout {
              spacing: 4
              Layout.fillWidth: true

              Label {
                text: root.phoneNumber !== "" ? root.phoneNumber : "Not set"
                font.pixelSize: 15
                font.bold: true
                color: Theme.primaryText
                textFormat: Text.PlainText
              }
              Label {
                text: "Phone number"
                font.pixelSize: 12
                color: Theme.secondaryText
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Theme.divider
              opacity: 0.6
            }

            // Bio
            ColumnLayout {
              spacing: 4
              Layout.fillWidth: true

              Label {
                text: root.bio !== "" ? root.bio : "No bio provided"
                font.pixelSize: 14
                lineHeight: 1.25
                color: root.bio !== "" ? Theme.primaryText : Theme.secondaryText
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
            }

            // Username
            ColumnLayout {
              spacing: 4
              Layout.fillWidth: true

              Label {
                text: root.username !== "" ? ("@" + root.username) : "None"
                font.pixelSize: 15
                font.bold: true
                color: root.username !== "" ? Theme.accent : Theme.secondaryText
                textFormat: Text.PlainText
              }
              Label {
                text: "Username"
                font.pixelSize: 12
                color: Theme.secondaryText
              }
            }
          }

          // EDIT MODE
          ColumnLayout {
            id: editColumn
            visible: root.isEditing
            anchors.fill: parent
            anchors.topMargin: 18
            anchors.bottomMargin: 24
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 14

            // First Name
            ColumnLayout {
              spacing: 4
              Layout.fillWidth: true
              Label {
                text: "First name"
                font.pixelSize: 12
                color: Theme.secondaryText
              }
              TextField {
                id: editFirstNameInput
                Layout.fillWidth: true
                color: Theme.primaryText
                placeholderText: "First name"
                background: Rectangle {
                  radius: 8
                  color: Theme.controlBackground
                  border.color: Theme.divider
                  border.width: 1
                }
              }
            }

            // Last Name
            ColumnLayout {
              spacing: 4
              Layout.fillWidth: true
              Label {
                text: "Last name (optional)"
                font.pixelSize: 12
                color: Theme.secondaryText
              }
              TextField {
                id: editLastNameInput
                Layout.fillWidth: true
                color: Theme.primaryText
                placeholderText: "Last name"
                background: Rectangle {
                  radius: 8
                  color: Theme.controlBackground
                  border.color: Theme.divider
                  border.width: 1
                }
              }
            }

            // Bio
            ColumnLayout {
              spacing: 4
              Layout.fillWidth: true
              Label {
                text: "Bio (up to 70 characters)"
                font.pixelSize: 12
                color: Theme.secondaryText
              }
              TextArea {
                id: editBioInput
                Layout.fillWidth: true
                color: Theme.primaryText
                placeholderText: "A few words about you"
                wrapMode: Text.Wrap
                background: Rectangle {
                  radius: 8
                  color: Theme.controlBackground
                  border.color: Theme.divider
                  border.width: 1
                }
              }
            }

            // Username
            ColumnLayout {
              spacing: 4
              Layout.fillWidth: true
              Label {
                text: "Username"
                font.pixelSize: 12
                color: Theme.secondaryText
              }
              TextField {
                id: editUsernameInput
                Layout.fillWidth: true
                color: Theme.primaryText
                placeholderText: "username"
                background: Rectangle {
                  radius: 8
                  color: Theme.controlBackground
                  border.color: Theme.divider
                  border.width: 1
                }
              }
            }

            // Cancel button
            Button {
              Layout.fillWidth: true
              text: "Cancel"
              onClicked: root.isEditing = false
              background: Rectangle {
                radius: 8
                color: "transparent"
                border.color: Theme.divider
                border.width: 1
              }
            }
          }
        }
      }
    }
  }
}
