import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects

Item {
  id: root

  property string activeCategory: "account"
  property string activeSection: "profile_card"
  signal sectionScrolled(string category, string section)

  // User Profile properties
  property var userId: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.userId) ? telegramClient.myProfile.userId : 0
  property string fullName: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.fullName) ? telegramClient.myProfile.fullName : ""
  property string firstName: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.firstName) ? telegramClient.myProfile.firstName : ""
  property string lastName: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.lastName) ? telegramClient.myProfile.lastName : ""
  property string username: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.username) ? telegramClient.myProfile.username : ""
  property string phoneNumber: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.phoneNumber) ? telegramClient.myProfile.phoneNumber : ""
  property string initials: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.initials) ? telegramClient.myProfile.initials : "?"
  property string avatarColor: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.avatarColor) ? telegramClient.myProfile.avatarColor : "#526C8A"
  property string avatarPath: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.avatarPath) ? telegramClient.myProfile.avatarPath : ""
  property string bio: (typeof telegramClient !== "undefined" && telegramClient.myProfile && telegramClient.myProfile.bio) ? telegramClient.myProfile.bio : ""

  property bool isEditingProfile: false
  property bool isProgrammaticScrolling: false

  function refreshProfile() {
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
    if (prof.avatarPath) avatarPath = prof.avatarPath
    if (prof.bio !== undefined) bio = prof.bio
  }

  Component.onCompleted: {
    refreshProfile()
    if (typeof telegramClient !== "undefined") {
      telegramClient.loadUserProfile(0, 0)
    }
  }

  onActiveCategoryChanged: {
    // Reset scroll position to top whenever switching category
    isProgrammaticScrolling = true
    flickable.contentY = 0
    isProgrammaticScrolling = false
  }

  function scrollToSection(sectionId) {
    var target = null
    if (sectionId === "profile_card") target = sec_profile_card
    else if (sectionId === "edit_details") target = sec_edit_details
    else if (sectionId === "account_actions") target = sec_account_actions
    else if (sectionId === "theme_section") target = sec_theme_section
    else if (sectionId === "app_zoom_section") target = sec_app_zoom_section
    else if (sectionId === "messages_style_section") target = sec_messages_style_section
    else if (sectionId === "chat_font_section") target = sec_chat_font_section
    else if (sectionId === "two_step_section") target = sec_two_step_section
    else if (sectionId === "sessions_section") target = sec_sessions_section
    else if (sectionId === "visibility_section") target = sec_visibility_section
    else if (sectionId === "chat_alerts_section") target = sec_chat_alerts_section
    else if (sectionId === "sounds_section") target = sec_sounds_section
    else if (sectionId === "auto_download_section") target = sec_auto_download_section
    else if (sectionId === "cache_section") target = sec_cache_section
    else if (sectionId === "folders_list_section") target = sec_folders_list_section
    else if (sectionId === "create_folder_section") target = sec_create_folder_section
    else if (sectionId === "interface_lang_section") target = sec_interface_lang_section
    else if (sectionId === "about_silkite_section") target = sec_about_silkite_section
    else if (sectionId === "libraries_section") target = sec_libraries_section

    if (target) {
      isProgrammaticScrolling = true
      var pos = target.mapToItem(contentColumn, 0, 0)
      var destY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, pos.y - 12))
      scrollAnimation.stop()
      scrollAnimation.to = destY
      scrollAnimation.start()
    }
  }

  NumberAnimation {
    id: scrollAnimation
    target: flickable
    property: "contentY"
    duration: 250
    easing.type: Easing.OutCubic
    onFinished: {
      root.isProgrammaticScrolling = false
    }
  }

  function checkVisibleSection() {
    if (isProgrammaticScrolling || scrollAnimation.running) return

    var currentY = flickable.contentY + 50
    var bestSec = ""
    var sectionsToCheck = []

    if (activeCategory === "account") {
      sectionsToCheck = [
        { id: "profile_card", item: sec_profile_card },
        { id: "edit_details", item: sec_edit_details },
        { id: "account_actions", item: sec_account_actions }
      ]
    } else if (activeCategory === "appearance") {
      sectionsToCheck = [
        { id: "theme_section", item: sec_theme_section },
        { id: "app_zoom_section", item: sec_app_zoom_section },
        { id: "messages_style_section", item: sec_messages_style_section },
        { id: "chat_font_section", item: sec_chat_font_section }
      ]
    } else if (activeCategory === "privacy") {
      sectionsToCheck = [
        { id: "two_step_section", item: sec_two_step_section },
        { id: "sessions_section", item: sec_sessions_section },
        { id: "visibility_section", item: sec_visibility_section }
      ]
    } else if (activeCategory === "notifications") {
      sectionsToCheck = [
        { id: "chat_alerts_section", item: sec_chat_alerts_section },
        { id: "sounds_section", item: sec_sounds_section }
      ]
    } else if (activeCategory === "data_storage") {
      sectionsToCheck = [
        { id: "auto_download_section", item: sec_auto_download_section },
        { id: "cache_section", item: sec_cache_section }
      ]
    } else if (activeCategory === "chat_folders") {
      sectionsToCheck = [
        { id: "folders_list_section", item: sec_folders_list_section },
        { id: "create_folder_section", item: sec_create_folder_section }
      ]
    } else if (activeCategory === "language") {
      sectionsToCheck = [
        { id: "interface_lang_section", item: sec_interface_lang_section }
      ]
    } else if (activeCategory === "about") {
      sectionsToCheck = [
        { id: "about_silkite_section", item: sec_about_silkite_section },
        { id: "libraries_section", item: sec_libraries_section }
      ]
    }

    for (var i = 0; i < sectionsToCheck.length; ++i) {
      var s = sectionsToCheck[i]
      if (s.item) {
        var p = s.item.mapToItem(contentColumn, 0, 0)
        if (p.y <= currentY) {
          bestSec = s.id
        }
      }
    }

    if (bestSec === "" && sectionsToCheck.length > 0) {
      bestSec = sectionsToCheck[0].id
    }

    if (bestSec !== "" && bestSec !== root.activeSection) {
      root.activeSection = bestSec
      root.sectionScrolled(activeCategory, bestSec)
    }
  }

  Connections {
    target: (typeof telegramClient !== "undefined") ? telegramClient : null
    function onMyProfileChanged() {
      root.refreshProfile()
    }
    function onUserProfileLoaded(uId, profile) {
      if (root.userId === 0 || uId === root.userId) {
        if (profile.bio !== undefined) root.bio = profile.bio
        if (profile.fullName) root.fullName = profile.fullName
        if (profile.firstName) root.firstName = profile.firstName
        if (profile.lastName) root.lastName = profile.lastName
        if (profile.username !== undefined) root.username = profile.username
        if (profile.phoneNumber) root.phoneNumber = profile.phoneNumber
        if (profile.avatarPath) root.avatarPath = profile.avatarPath
      }
    }
  }

  FileDialog {
    id: photoFileDialog
    title: "Choose Profile Photo"
    nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp)"]
    onAccepted: {
      var path = selectedFile.toString().replace("file://", "")
      if (typeof telegramClient !== "undefined") {
        telegramClient.setProfilePhoto(path)
      }
    }
  }

  // Outer ambient elevation shadow
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
  }

  Flickable {
    id: flickable
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + 48

    ScrollBar.vertical: ScrollBar {
      policy: ScrollBar.AsNeeded
    }

    onContentYChanged: {
      checkVisibleSection()
    }

    ColumnLayout {
      id: contentColumn
      width: Math.min(flickable.width - 48, 640)
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 24

      Item { Layout.preferredHeight: 12 }

      // ==========================================
      // ACCOUNT & PROFILE SECTION
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 20
        visible: root.activeCategory === "account"

        // Section Title
        RowLayout {
          Layout.fillWidth: true
          Label {
            text: "Account & Profile"
            font.pixelSize: 22
            font.bold: true
            color: Theme.primaryText
            Layout.fillWidth: true
          }

          Button {
            visible: !root.isEditingProfile
            text: "Edit Profile"
            background: Rectangle {
              radius: 8
              color: parent.hovered ? Theme.controlBackground : "transparent"
              border.color: Theme.divider
            }
            contentItem: Text {
              text: parent.text
              color: Theme.accent
              font.bold: true
              font.pixelSize: 13
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
              editFirstNameInput.text = root.firstName
              editLastNameInput.text = root.lastName
              editBioInput.text = root.bio
              editUsernameInput.text = root.username
              root.isEditingProfile = true
            }
          }

          Button {
            visible: root.isEditingProfile
            text: "Done"
            background: Rectangle {
              radius: 8
              color: Theme.accent
            }
            contentItem: Text {
              text: parent.text
              color: Theme.accentText
              font.bold: true
              font.pixelSize: 13
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
              if (typeof telegramClient !== "undefined") {
                telegramClient.setName(editFirstNameInput.text.trim(), editLastNameInput.text.trim())
                telegramClient.setBio(editBioInput.text.trim())
                telegramClient.setUsername(editUsernameInput.text.trim().replace(/^@/, ''))
              }
              root.isEditingProfile = false
            }
          }
        }

        // Sub-section 1: Profile Avatar Card
        Rectangle {
          id: sec_profile_card
          Layout.fillWidth: true
          height: 110
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Item {
              Layout.preferredWidth: 76
              Layout.preferredHeight: 76

              Rectangle {
                id: avatarCircle
                anchors.fill: parent
                radius: 38
                color: root.avatarColor

                Text {
                  anchors.centerIn: parent
                  text: root.initials
                  color: "#FFFFFF"
                  font.pixelSize: 28
                  font.bold: true
                  visible: !avatarImage.visible
                }

                Image {
                  id: avatarImage
                  anchors.fill: parent
                  source: root.avatarPath !== "" ? ("file://" + root.avatarPath) : ""
                  fillMode: Image.PreserveAspectCrop
                  smooth: true
                  visible: root.avatarPath !== "" && status === Image.Ready
                  layer.enabled: true
                  layer.effect: OpacityMask {
                    maskSource: Rectangle {
                      width: avatarCircle.width
                      height: avatarCircle.height
                      radius: 38
                    }
                  }
                }

                // Camera upload overlay
                Rectangle {
                  anchors.fill: parent
                  radius: 38
                  color: Qt.rgba(0, 0, 0, 0.45)
                  visible: avatarHoverArea.containsMouse

                  Image {
                    anchors.centerIn: parent
                    source: "qrc:/qt/qml/Silkite/assets/icons/camera.svg"
                    sourceSize.width: 24
                    sourceSize.height: 24
                  }
                }

                MouseArea {
                  id: avatarHoverArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: photoFileDialog.open()
                }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4

              Label {
                text: root.fullName !== "" ? root.fullName : "Your Name"
                font.pixelSize: 18
                font.bold: true
                color: Theme.primaryText
                elide: Text.ElideRight
              }

              Label {
                text: root.phoneNumber !== "" ? root.phoneNumber : "No Phone Number"
                font.pixelSize: 13
                color: Theme.secondaryText
              }

              Label {
                text: root.username !== "" ? ("@" + root.username) : "No Username"
                font.pixelSize: 13
                color: Theme.accent
              }
            }
          }
        }

        // Sub-section 2: Edit Profile Form / Details
        ColumnLayout {
          id: sec_edit_details
          Layout.fillWidth: true
          spacing: 14

          // Form if editing
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: root.isEditingProfile

            Label {
              text: "Edit Information"
              font.pixelSize: 14
              font.bold: true
              color: Theme.secondaryText
            }

            TextField {
              id: editFirstNameInput
              Layout.fillWidth: true
              placeholderText: "First Name"
              color: Theme.primaryText
              placeholderTextColor: Theme.secondaryText
              background: Rectangle {
                radius: 10
                color: Theme.controlBackground
                border.color: editFirstNameInput.activeFocus ? Theme.accent : Theme.divider
              }
            }

            TextField {
              id: editLastNameInput
              Layout.fillWidth: true
              placeholderText: "Last Name (Optional)"
              color: Theme.primaryText
              placeholderTextColor: Theme.secondaryText
              background: Rectangle {
                radius: 10
                color: Theme.controlBackground
                border.color: editLastNameInput.activeFocus ? Theme.accent : Theme.divider
              }
            }

            TextField {
              id: editBioInput
              Layout.fillWidth: true
              placeholderText: "Bio (Few words about yourself)"
              color: Theme.primaryText
              placeholderTextColor: Theme.secondaryText
              background: Rectangle {
                radius: 10
                color: Theme.controlBackground
                border.color: editBioInput.activeFocus ? Theme.accent : Theme.divider
              }
            }

            TextField {
              id: editUsernameInput
              Layout.fillWidth: true
              placeholderText: "Username (without @)"
              color: Theme.primaryText
              placeholderTextColor: Theme.secondaryText
              background: Rectangle {
                radius: 10
                color: Theme.controlBackground
                border.color: editUsernameInput.activeFocus ? Theme.accent : Theme.divider
              }
            }
          }

          // Details / View Mode Box
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: detailsColumn.implicitHeight + 24
            radius: 16
            color: Theme.controlBackground
            border.color: Theme.divider
            border.width: 1
            visible: !root.isEditingProfile

            ColumnLayout {
              id: detailsColumn
              anchors.fill: parent
              anchors.margins: 14
              spacing: 14

              ColumnLayout {
                spacing: 2
                Label { text: "Phone Number"; font.pixelSize: 11; color: Theme.secondaryText }
                Label { text: root.phoneNumber !== "" ? root.phoneNumber : "None"; font.pixelSize: 14; color: Theme.primaryText }
              }

              Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

              ColumnLayout {
                spacing: 2
                Label { text: "Username"; font.pixelSize: 11; color: Theme.secondaryText }
                Label { text: root.username !== "" ? ("@" + root.username) : "None"; font.pixelSize: 14; color: Theme.primaryText }
              }

              Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

              ColumnLayout {
                spacing: 2
                Label { text: "Bio"; font.pixelSize: 11; color: Theme.secondaryText }
                Label { text: root.bio !== "" ? root.bio : "None"; font.pixelSize: 14; color: Theme.primaryText; wrapMode: Text.WordWrap; Layout.fillWidth: true }
              }
            }
          }
        }

        // Sub-section 3: Account Actions (Log Out)
        Item {
          id: sec_account_actions
          Layout.fillWidth: true
          Layout.preferredHeight: 46

          Button {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Layout.preferredHeight: 38
            Layout.preferredWidth: 120
            background: Rectangle {
              radius: 10
              color: parent.down ? Qt.darker("#dc3545", 1.1) : (parent.hovered ? "#e04b59" : "#dc3545")
            }
            contentItem: Text {
              text: "Log Out"
              color: "white"
              font.bold: true
              font.pixelSize: 13
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
              if (typeof telegramClient !== "undefined") {
                telegramClient.logOut()
              }
            }
          }
        }
      }

      // ==========================================
      // APPEARANCE SECTION
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 16
        visible: root.activeCategory === "appearance"

        Label {
          text: "Appearance"
          font.pixelSize: 22
          font.bold: true
          color: Theme.primaryText
        }

        // Sub-section 1: Theme
        Rectangle {
          id: sec_theme_section
          Layout.fillWidth: true
          implicitHeight: appearanceCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: appearanceCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Label {
              text: "Theme Palette"
              font.pixelSize: 15
              font.bold: true
              color: Theme.primaryText
            }

            ComboBox {
              id: themeSelector
              Layout.fillWidth: true
              Layout.preferredHeight: 40
              model: Theme.availableThemes
              currentIndex: Math.max(0, model.indexOf(Theme.currentTheme))
              onActivated: Theme.selectTheme(currentText)

              contentItem: Label {
                leftPadding: 14
                text: themeSelector.displayText
                color: Theme.primaryText
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
              }

              background: Rectangle {
                radius: 10
                color: Theme.panelBackground
                border.color: themeSelector.activeFocus ? Theme.accent : Theme.divider
                border.width: 1
              }
            }

            Label {
              text: "Silkite theme configuration is stored at " + Theme.configFilePath()
              color: Theme.secondaryText
              font.pixelSize: 12
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }

        // Sub-section 2: App zoom level
        Rectangle {
          id: sec_app_zoom_section
          Layout.fillWidth: true
          implicitHeight: zoomCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: zoomCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
              Layout.fillWidth: true
              Label { text: "App Zoom Level"; font.pixelSize: 15; font.bold: true; color: Theme.primaryText }
              Item { Layout.fillWidth: true }
              Label { text: Math.round(zoomSlider.value) + "%"; font.bold: true; color: Theme.accent }
            }

            Slider {
              id: zoomSlider
              Layout.fillWidth: true
              from: 80
              to: 150
              value: 100
              stepSize: 5
            }

            Label {
              text: "Adjust overall user interface scale for high-DPI displays"
              font.pixelSize: 12
              color: Theme.secondaryText
            }
          }
        }

        // Sub-section 3: Messages style
        Rectangle {
          id: sec_messages_style_section
          Layout.fillWidth: true
          implicitHeight: messagesCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: messagesCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Label { text: "Messages View"; font.pixelSize: 15; font.bold: true; color: Theme.primaryText }

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Bubble Corners"; font.pixelSize: 13; font.bold: true; color: Theme.primaryText }
                Label { text: "Use rounded bubble style for conversation messages"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Switch { checked: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Liquid Glass Tint"; font.pixelSize: 13; font.bold: true; color: Theme.primaryText }
                Label { text: "Enable translucent glass backdrop across panes"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Switch { checked: true }
            }
          }
        }

        // Sub-section 4: Chat font scaling
        Rectangle {
          id: sec_chat_font_section
          Layout.fillWidth: true
          implicitHeight: fontCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: fontCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
              Layout.fillWidth: true
              Label { text: "Chat Font Scaling"; font.pixelSize: 15; font.bold: true; color: Theme.primaryText }
              Item { Layout.fillWidth: true }
              Label { text: Math.round(fontSlider.value) + " pt"; font.bold: true; color: Theme.accent }
            }

            Slider {
              id: fontSlider
              Layout.fillWidth: true
              from: 11
              to: 20
              value: 14
              stepSize: 1
            }

            Label {
              text: "Adjust text readability for incoming and outgoing chat messages"
              font.pixelSize: 12
              color: Theme.secondaryText
            }
          }
        }
      }

      // ==========================================
      // PRIVACY & SECURITY SECTION
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 16
        visible: root.activeCategory === "privacy"

        Label {
          text: "Privacy & Security"
          font.pixelSize: 22
          font.bold: true
          color: Theme.primaryText
        }

        // Sub-section 1: Two-step verification
        Rectangle {
          id: sec_two_step_section
          Layout.fillWidth: true
          implicitHeight: twoStepCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: twoStepCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Two-Step Verification"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Add an extra layer of security with a cloud password"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Switch { checked: true; enabled: false }
            }
          }
        }

        // Sub-section 2: Active sessions
        Rectangle {
          id: sec_sessions_section
          Layout.fillWidth: true
          implicitHeight: sessionsCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: sessionsCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Active Sessions & Devices"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Control logged in applications and web sessions"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Label { text: "1 Active"; color: Theme.accent; font.pixelSize: 13 }
            }
          }
        }

        // Sub-section 3: Visibility & online
        Rectangle {
          id: sec_visibility_section
          Layout.fillWidth: true
          implicitHeight: visibilityCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: visibilityCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Phone Number Visibility"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Choose who can see your phone number"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Label { text: "My Contacts"; color: Theme.secondaryText; font.pixelSize: 13 }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Last Seen & Online"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Choose who can see your last seen time"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Label { text: "Everybody"; color: Theme.secondaryText; font.pixelSize: 13 }
            }
          }
        }
      }

      // ==========================================
      // NOTIFICATIONS & SOUNDS
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 16
        visible: root.activeCategory === "notifications"

        Label {
          text: "Notifications & Sounds"
          font.pixelSize: 22
          font.bold: true
          color: Theme.primaryText
        }

        // Sub-section 1: Chat notifications
        Rectangle {
          id: sec_chat_alerts_section
          Layout.fillWidth: true
          implicitHeight: notifCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: notifCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Private Chats"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Show notifications for private messages"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Switch { checked: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Groups"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Show notifications for group chats"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Switch { checked: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Channels"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Show notifications for subscribed channels"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Switch { checked: false }
            }
          }
        }

        // Sub-section 2: Sound effects
        Rectangle {
          id: sec_sounds_section
          Layout.fillWidth: true
          implicitHeight: soundCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: soundCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "In-App Sounds"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Play sound on new messages"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Switch { checked: true }
            }
          }
        }
      }

      // ==========================================
      // DATA & STORAGE
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 16
        visible: root.activeCategory === "data_storage"

        Label {
          text: "Data & Storage"
          font.pixelSize: 22
          font.bold: true
          color: Theme.primaryText
        }

        // Sub-section 1: Media auto-download
        Rectangle {
          id: sec_auto_download_section
          Layout.fillWidth: true
          implicitHeight: dataCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: dataCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Automatic Media Download"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Download photos and documents automatically"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Switch { checked: true }
            }
          }
        }

        // Sub-section 2: Cache storage
        Rectangle {
          id: sec_cache_section
          Layout.fillWidth: true
          implicitHeight: cacheCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: cacheCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Cache Storage"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Keep cached files to save network data"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Button {
                text: "Clear Cache"
                background: Rectangle {
                  radius: 8
                  color: parent.hovered ? Theme.divider : "transparent"
                  border.color: Theme.divider
                }
                contentItem: Text {
                  text: parent.text
                  color: Theme.accent
                  font.bold: true
                  font.pixelSize: 12
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }
          }
        }
      }

      // ==========================================
      // CHAT FOLDERS
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 16
        visible: root.activeCategory === "chat_folders"

        Label {
          text: "Chat Folders"
          font.pixelSize: 22
          font.bold: true
          color: Theme.primaryText
        }

        // Sub-section 1: Manage folders
        Rectangle {
          id: sec_folders_list_section
          Layout.fillWidth: true
          implicitHeight: folderCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: folderCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Label {
              text: "Organize your conversations by creating custom chat folders."
              color: Theme.secondaryText
              font.pixelSize: 13
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }

        // Sub-section 2: Create folder
        Rectangle {
          id: sec_create_folder_section
          Layout.fillWidth: true
          implicitHeight: createFoldCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: createFoldCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Button {
              text: "+ Create New Folder"
              Layout.preferredHeight: 36
              background: Rectangle {
                radius: 8
                color: Theme.accent
              }
              contentItem: Text {
                text: parent.text
                color: Theme.accentText
                font.bold: true
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: {
                if (typeof chatOrganizationManager !== "undefined") {
                  newFolderDialog.open()
                }
              }
            }
          }
        }
      }

      // ==========================================
      // LANGUAGE
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 16
        visible: root.activeCategory === "language"

        Label {
          text: "Language"
          font.pixelSize: 22
          font.bold: true
          color: Theme.primaryText
        }

        // Sub-section 1: Interface language
        Rectangle {
          id: sec_interface_lang_section
          Layout.fillWidth: true
          implicitHeight: langCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: langCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Interface Language"; font.pixelSize: 14; font.bold: true; color: Theme.primaryText }
                Label { text: "Silkite interface language"; font.pixelSize: 12; color: Theme.secondaryText }
              }
              Label { text: "English (US)"; color: Theme.accent; font.pixelSize: 13; font.bold: true }
            }
          }
        }
      }

      // ==========================================
      // ABOUT SILKITE
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 16
        visible: root.activeCategory === "about"

        Label {
          text: "About Silkite"
          font.pixelSize: 22
          font.bold: true
          color: Theme.primaryText
        }

        // Sub-section 1: Silkite client
        Rectangle {
          id: sec_about_silkite_section
          Layout.fillWidth: true
          implicitHeight: aboutCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: aboutCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
              spacing: 14
              Image {
                source: "qrc:/qt/qml/Silkite/assets/logo-transparent.png"
                sourceSize.width: 48
                sourceSize.height: 48
              }
              ColumnLayout {
                spacing: 2
                Label { text: "Silkite Telegram Client"; font.pixelSize: 16; font.bold: true; color: Theme.primaryText }
                Label { text: "Fast, elegant Telegram desktop client built with Qt Quick & TDLib"; font.pixelSize: 12; color: Theme.secondaryText }
                Label { text: "Version 0.1.0"; font.pixelSize: 12; color: Theme.accent }
              }
            }
          }
        }

        // Sub-section 2: Components & TDLib
        Rectangle {
          id: sec_libraries_section
          Layout.fillWidth: true
          implicitHeight: libCol.implicitHeight + 24
          radius: 16
          color: Theme.controlBackground
          border.color: Theme.divider
          border.width: 1

          ColumnLayout {
            id: libCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Label {
              text: "Powered by TDLib (Telegram Database Library) and Qt 6."
              color: Theme.secondaryText
              font.pixelSize: 12
            }
          }
        }
      }

      Item { Layout.preferredHeight: 32 }
    }
  }
}
