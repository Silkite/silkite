import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
  id: window

  FontLoader {
    id: fredokaFont
    source: "qrc:/qt/qml/Silkite/assets/fonts/Fredoka-Variable.ttf"
  }

  visible: true

  width: 1200
  height: 760

  minimumWidth: 320
  minimumHeight: 600

  title: appController.appName
  font.family: fredokaFont.name

  color: Theme.windowBackground

  property var selectedChatId: 0
  property string activeSection: "chats"

  property var selectedChat: {
    chatRevision;
    if (!selectedChatId)
      return ({})
    return chatListModel.chatById(selectedChatId)
  }
  property int chatRevision: 0

  property bool phoneLoginStarted: false
  property bool phoneSubmitted: false
  property int resendSeconds: 0
  property bool resendReady: false
  property string authError: ""
  property bool showQrLogin: true
  property bool compactLogin: width <= Screen.width * 0.5
  property bool compactLayout: width <= Screen.width * 0.5
  property bool chatListExpanded: !compactLayout
  property bool chatListAutoExpanded: false
  property int compactContentWidth: Math.min(width - 32, 720)

  onWidthChanged: {
    if (width <= Screen.width * 0.5)
      chatListExpanded = false
    else
      chatListExpanded = true
    chatListAutoExpanded = false
  }

  Timer {
    id: collapseChatListTimer
    interval: 450
    onTriggered: {
      if (window.compactLayout && window.chatListAutoExpanded && !chatListPane.pointerInside) {
        window.chatListExpanded = false
        window.chatListAutoExpanded = false
      }
    }
  }
  property real phoneBoxSize: compactLogin
    ? Math.max(24, Math.min(40, (compactContentWidth - 108 - 8 - (selectedCountryDigits - 1) * 4) / selectedCountryDigits))
    : 40
  property string selectedCountryCode: "+91"
  property string selectedCountryFlag: "🇮🇳"
  property int selectedCountryDigits: 10
  property var countries: [
    { name: "India", code: "+91", flag: "🇮🇳", digits: 10 },
    { name: "United States", code: "+1", flag: "🇺🇸", digits: 10 },
    { name: "United Kingdom", code: "+44", flag: "🇬🇧", digits: 10 },
    { name: "Canada", code: "+1", flag: "🇨🇦", digits: 10 },
    { name: "Australia", code: "+61", flag: "🇦🇺", digits: 9 },
    { name: "Germany", code: "+49", flag: "🇩🇪", digits: 10 },
    { name: "France", code: "+33", flag: "🇫🇷", digits: 9 },
    { name: "Japan", code: "+81", flag: "🇯🇵", digits: 10 },
    { name: "Singapore", code: "+65", flag: "🇸🇬", digits: 8 },
    { name: "United Arab Emirates", code: "+971", flag: "🇦🇪", digits: 9 }
  ]

  function submitOtp() {
    var code = ""
    for (var i = 0; i < otpRepeater.count; ++i)
      code += otpRepeater.itemAt(i).text
    if (code.length === telegramClient.authenticationCodeLength)
      telegramClient.submitCode(code)
  }

  function enteredPhoneNumber() {
    var number = ""
    for (var i = 0; i < phoneRepeater.count; ++i)
      number += phoneRepeater.itemAt(i).text
    return number
  }

  function clearOtp() {
    for (var i = 0; i < otpRepeater.count; ++i)
      otpRepeater.itemAt(i).clear()
    if (otpRepeater.count > 0)
      otpRepeater.itemAt(0).forceActiveFocus()
  }

  Connections {
    target: telegramClient
    function onErrorOccurred(error) {
      window.authError = error
      if (window.phoneSubmitted)
        window.clearOtp()
    }
    function onAuthenticationCodeTimeoutChanged() {
      window.resendSeconds = telegramClient.authenticationCodeTimeout
      window.resendReady = true
    }
  }

  Timer {
    interval: 1000
    running: window.phoneSubmitted && telegramClient.authorizationState === "waitCode" && window.resendSeconds > 0
    repeat: true
    onTriggered: if (window.resendSeconds > 0) --window.resendSeconds
  }

  Timer {
    interval: 25000
    running: window.showQrLogin && telegramClient.authorizationState === "waitOtherDeviceConfirmation"
    repeat: true
    onTriggered: telegramClient.requestQrLogin()
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.windowBackground
    z: 10
    visible: telegramClient.authorizationState !== "ready"

    ColumnLayout {
      anchors.centerIn: parent
      width: Math.min(parent.width - 32, 900)
      spacing: 18

      RowLayout {
        visible: compactLogin
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Button {
          text: "QR code"
          checkable: true
          checked: window.showQrLogin
          onClicked: {
            window.showQrLogin = true
            telegramClient.selectQrLogin()
            telegramClient.requestQrLogin()
          }
          contentItem: Label {
            text: parent.text
            color: parent.checked ? Theme.accentText : Theme.primaryText
            font.weight: parent.checked ? Font.DemiBold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: height / 2
            color: parent.checked ? Theme.accent : Theme.controlBackground
            border.color: parent.checked ? Qt.rgba(1, 1, 1, 0.25) : Theme.divider
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: parent.radius - 1
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, parent.parent.checked ? 0.35 : 0.08)
              border.width: 1
            }
          }
        }
        Button {
          text: "Phone number"
          checkable: true
          checked: !window.showQrLogin
          onClicked: {
            window.showQrLogin = false
            telegramClient.selectPhoneLogin()
          }
          contentItem: Label {
            text: parent.text
            color: parent.checked ? Theme.accentText : Theme.primaryText
            font.weight: parent.checked ? Font.DemiBold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: height / 2
            color: parent.checked ? Theme.accent : Theme.controlBackground
            border.color: parent.checked ? Qt.rgba(1, 1, 1, 0.25) : Theme.divider
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: parent.radius - 1
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, parent.parent.checked ? 0.35 : 0.08)
              border.width: 1
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: compactLogin ? window.compactContentWidth : Math.min(parent.width - 32, 900)
        spacing: compactLogin ? 0 : 42

      ColumnLayout {
        Layout.preferredWidth: compactLogin ? (showQrLogin ? window.compactContentWidth : 0) : 360
        Layout.maximumWidth: compactLogin ? (showQrLogin ? window.compactContentWidth : 0) : 360
        Layout.alignment: Qt.AlignHCenter
        opacity: compactLogin && !showQrLogin ? 0 : 1
        enabled: !compactLogin || showQrLogin
        spacing: 12
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Label { text: "Log in with QR code"; color: Theme.primaryText; font.pixelSize: 22; Layout.alignment: Qt.AlignHCenter }
        Rectangle {
          Layout.preferredWidth: 260; Layout.preferredHeight: 260
          Layout.alignment: Qt.AlignHCenter
          radius: 20
          color: Theme.panelBackground
          border.color: Theme.divider
          border.width: 1
          clip: true

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 19
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
          }

          Image {
            anchors.fill: parent
            anchors.margins: 12
            source: telegramClient.qrCodeImagePath === "" ? "" : "file://" + telegramClient.qrCodeImagePath
            fillMode: Image.PreserveAspectFit
            smooth: false
          }
        }
        Label {
          text: telegramClient.qrCodeImagePath === "" ? "Preparing QR code…" : "Open Telegram on your phone and scan this code"
          color: Theme.secondaryText; wrapMode: Text.WordWrap; Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
        }
      }

      Rectangle {
        Layout.preferredWidth: compactLogin ? 0 : 1
        Layout.preferredHeight: compactLogin ? 0 : 440
        opacity: compactLogin ? 0 : 1
        color: Theme.divider
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
      }

      ColumnLayout {
        Layout.preferredWidth: compactLogin ? (showQrLogin ? 0 : window.compactContentWidth) : 360
        Layout.maximumWidth: compactLogin ? (showQrLogin ? 0 : window.compactContentWidth) : 360
        Layout.alignment: Qt.AlignHCenter
        opacity: compactLogin && showQrLogin ? 0 : 1
        enabled: !compactLogin || !showQrLogin
        spacing: 14
        visible: !window.phoneSubmitted && telegramClient.authorizationState !== "waitCode"
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Label { text: "Log in with phone number"; color: Theme.primaryText; font.pixelSize: 22; Layout.alignment: Qt.AlignHCenter }
        Label { text: "Choose your country and enter your number"; color: Theme.secondaryText; Layout.alignment: Qt.AlignHCenter }

        RowLayout {
          Layout.fillWidth: false
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 108 + 8 + phoneRepeater.count * window.phoneBoxSize + (phoneRepeater.count - 1) * 4
          spacing: 8

          ComboBox {
            id: countryBox
            Layout.preferredWidth: 108
            Layout.preferredHeight: 40
            model: window.countries
            textRole: "name"
            displayText: window.selectedCountryFlag + "  " + window.selectedCountryCode
            contentItem: Label {
              leftPadding: 14
              text: countryBox.displayText
              color: Theme.primaryText
              verticalAlignment: Text.AlignVCenter
              font.pixelSize: 15
            }
            background: Rectangle {
              radius: 12
              color: Theme.controlBackground
              border.color: countryBox.activeFocus ? Theme.accent : Theme.divider
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
            delegate: ItemDelegate {
              width: countryBox.width
              text: modelData.flag + "  " + modelData.name + "  " + modelData.code
              contentItem: Label {
                text: modelData.flag + "  " + modelData.name + "  " + modelData.code
                color: highlighted ? Theme.accentText : Theme.primaryText
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }
              background: Rectangle {
                color: highlighted ? Theme.accent : Theme.controlBackground
                radius: 9
              }
            }
            onActivated: {
              window.selectedCountryCode = window.countries[index].code
              window.selectedCountryFlag = window.countries[index].flag
              window.selectedCountryDigits = window.countries[index].digits
            }
          }

          Row {
            Layout.fillWidth: false
            Layout.preferredWidth: phoneRepeater.count * window.phoneBoxSize + (phoneRepeater.count - 1) * 4
            Layout.preferredHeight: 40
            spacing: 4
            Repeater {
              id: phoneRepeater
              model: window.selectedCountryDigits
              delegate: TextField {
                width: window.phoneBoxSize
                height: width
                scale: activeFocus ? 1.08 : 1.0
                color: Theme.primaryText
                horizontalAlignment: Text.AlignHCenter
                maximumLength: 1
                inputMethodHints: Qt.ImhDigitsOnly
                background: Rectangle {
                  radius: width / 2
                  color: Theme.controlBackground
                  border.color: parent.activeFocus ? Theme.accent : Theme.divider
                  border.width: 1

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, parent.parent.activeFocus ? 0.3 : 0.08)
                    border.width: 1
                  }
                }
                onTextChanged: {
                  if (text.length === 1 && index + 1 < phoneRepeater.count)
                    phoneRepeater.itemAt(index + 1).forceActiveFocus()
                }
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Backspace && text.length === 0 && index > 0) {
                    phoneRepeater.itemAt(index - 1).forceActiveFocus()
                    event.accepted = true
                  }
                }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              }
            }
          }
        }
        Button {
          text: "Continue"
          Layout.alignment: Qt.AlignHCenter;
          enabled: window.enteredPhoneNumber().length === window.selectedCountryDigits && telegramClient.authorizationState !== "waitCode"
          contentItem: Label {
            text: parent.text
            color: Theme.accentText
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: {
            window.phoneLoginStarted = true
            window.phoneSubmitted = true
            window.authError = ""
            window.resendSeconds = 0
            window.resendReady = false
            telegramClient.selectPhoneLogin()
            telegramClient.submitPhoneNumber(window.selectedCountryCode + window.enteredPhoneNumber())
            for (var i = 0; i < phoneRepeater.count; ++i)
              phoneRepeater.itemAt(i).clear()
          }
          background: Rectangle {
            radius: height / 2
            color: parent.enabled ? Theme.accent : Theme.controlBackground
            border.color: parent.enabled ? Qt.rgba(1, 1, 1, 0.25) : Theme.divider
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: parent.radius - 1
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, parent.parent.enabled ? 0.35 : 0.08)
              border.width: 1
            }
          }
        }
      }

      ColumnLayout {
        Layout.preferredWidth: 360
        Layout.alignment: Qt.AlignHCenter
        spacing: 14
        visible: window.phoneSubmitted || telegramClient.authorizationState === "waitCode"
        Label { text: "Enter Telegram code"; color: Theme.primaryText; font.pixelSize: 22; Layout.alignment: Qt.AlignHCenter }
        Label { text: "Enter the code sent to your Telegram account"; color: Theme.secondaryText; Layout.alignment: Qt.AlignHCenter }
        Label {
          visible: window.authError !== ""
          text: window.authError
          color: Theme.accent
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
        }
        Row {
          Layout.alignment: Qt.AlignHCenter
          spacing: 8
          Repeater {
            id: otpRepeater
            model: telegramClient.authenticationCodeLength
            delegate: TextField {
              width: 44; height: 44
              scale: activeFocus ? 1.12 : 1.0
              color: Theme.primaryText; horizontalAlignment: Text.AlignHCenter
              font.pixelSize: 22; maximumLength: 1
              inputMethodHints: Qt.ImhDigitsOnly
              background: Rectangle {
                radius: width / 2
                color: Theme.controlBackground
                border.color: parent.activeFocus ? Theme.accent : Theme.divider
                border.width: 1

                Rectangle {
                  anchors.fill: parent
                  anchors.margins: 1
                  radius: parent.radius - 1
                  color: "transparent"
                  border.color: Qt.rgba(1, 1, 1, parent.parent.activeFocus ? 0.3 : 0.08)
                  border.width: 1
                }
              }
              onTextChanged: {
                if (text.length === 1 && index + 1 < otpRepeater.count) {
                  otpRepeater.itemAt(index + 1).forceActiveFocus()
                } else if (text.length === 1 && index === otpRepeater.count - 1) {
                  Qt.callLater(window.submitOtp)
                }
              }
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Backspace && text.length === 0 && index > 0) {
                  otpRepeater.itemAt(index - 1).forceActiveFocus()
                  event.accepted = true
                }
              }
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
          }
        }
        Button {
          text: !window.resendReady ? "Waiting for Telegram…" : (window.resendSeconds > 0 ? "Resend code in " + window.resendSeconds + "s" : "Resend code")
          Layout.alignment: Qt.AlignHCenter
          enabled: window.resendReady && window.resendSeconds === 0 && telegramClient.authorizationState === "waitCode"
          contentItem: Label {
            text: parent.text
            color: parent.enabled ? Theme.accentText : Theme.secondaryText
            font.weight: parent.enabled ? Font.DemiBold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: height / 2
            color: parent.enabled ? Theme.accent : Theme.controlBackground
            border.color: parent.enabled ? Qt.rgba(1, 1, 1, 0.25) : Theme.divider
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: parent.radius - 1
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, parent.parent.enabled ? 0.35 : 0.08)
              border.width: 1
            }
          }
          onClicked: {
            window.clearOtp()
            window.authError = ""
            window.resendReady = false
            telegramClient.resendAuthenticationCode()
          }
        }
      }
      }
    }
  }

  Popup {
    id: settingsPopup

    x: (window.width - width) / 2
    y: (window.height - height) / 2
    width: Math.min(window.width - 48, 520)
    height: settingsContent.implicitHeight + 48
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
      radius: 18
      color: Theme.windowBackground
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

    onClosed: {
      if (window.activeSection === "settings")
        window.activeSection = "chats"
    }

    ColumnLayout {
      id: settingsContent
      anchors.fill: parent
      anchors.margins: 24
      spacing: 18

      Label {
        text: "Settings"
        color: Theme.primaryText
        font.pixelSize: 26
        font.bold: true
        Layout.alignment: Qt.AlignHCenter
      }

      Label {
        text: "Theme"
        color: Theme.primaryText
        font.pixelSize: 16
      }

      ComboBox {
        id: themeSelector
        Layout.fillWidth: true
        model: Theme.availableThemes
        currentIndex: Math.max(0, model.indexOf(Theme.currentTheme))
        onActivated: Theme.selectTheme(currentText)
      }

      Label {
        text: "Silkite stores its theme palette in " + Theme.configFilePath()
        color: Theme.secondaryText
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
  }

  Connections {
    target: window
    function onActiveSectionChanged() {
      if (window.activeSection === "settings" && telegramClient.authorizationState === "ready")
        settingsPopup.open()
      else if (settingsPopup.opened)
        settingsPopup.close()
    }
  }

  Connections {
    target: telegramClient
    function onChatUpdated() {
      window.chatRevision++
      if ((window.selectedChatId === 0 || !window.selectedChatId) && chatListModel.rowCount() > 0) {
        var firstChat = chatListModel.chatAt(0)
        if (firstChat && firstChat.chatId) {
          window.selectedChatId = firstChat.chatId
          telegramClient.loadConversation(firstChat.chatId)
        }
      }
    }
  }

  ComboBox {
    id: globalThemeSelector
    z: 30
    visible: telegramClient.authorizationState !== "ready"
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: 18
    anchors.bottomMargin: 10
    width: 170
    model: Theme.availableThemes
    currentIndex: Math.max(0, model.indexOf(Theme.currentTheme))
    displayText: "Theme: " + Theme.currentTheme
    onActivated: Theme.selectTheme(currentText)
    contentItem: Label {
      text: globalThemeSelector.displayText
      color: Theme.primaryText
      leftPadding: 10
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
    background: Rectangle {
      radius: 12
      color: Theme.controlBackground
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
    delegate: ItemDelegate {
      width: globalThemeSelector.width
      text: modelData
      contentItem: Label {
        text: modelData
        color: highlighted ? Theme.accentText : Theme.primaryText
        verticalAlignment: Text.AlignVCenter
      }
      background: Rectangle {
        radius: 8
        color: highlighted ? Theme.accent : Theme.controlBackground
      }
    }
  }

  Item {
    anchors.fill: parent

    // Top application header bar - fixed across the entire top
    Rectangle {
      id: topBar
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 48
      color: Theme.elevatedBackground
      border.color: Theme.divider
      border.width: 1
      z: 20

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.divider
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Image {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          source: "qrc:/qt/qml/Silkite/assets/logo-transparent.png"
          fillMode: Image.PreserveAspectFit
          smooth: true
        }

        Label {
          text: appController.appName
          font.bold: true
          font.pixelSize: 17
          color: Theme.primaryText
        }

        Item {
          Layout.fillWidth: true
        }

        ToolButton {
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/panel-left.svg"
          icon.width: 22
          icon.height: 22
          icon.color: Theme.primaryText
          focusPolicy: Qt.NoFocus
          implicitWidth: 38
          implicitHeight: 38
          ToolTip.visible: hovered
          ToolTip.text: window.chatListExpanded ? "Hide chats" : "Show chats"
          ToolTip.delay: 400
          background: Rectangle {
            radius: 12
            color: parent.hovered ? Theme.controlBackground : "transparent"
            border.color: parent.hovered ? Theme.divider : "transparent"
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: 11
              color: "transparent"
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1
              visible: parent.parent.hovered
            }
          }
          onClicked: {
            window.chatListExpanded = !window.chatListExpanded
            window.chatListAutoExpanded = false
          }
        }
      }
    }

    // Main content area below the fixed top bar
    Item {
      id: contentArea
      anchors.top: topBar.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom

      // Reserved Left Sidebar Container (same height & same border roundness)
      Item {
        id: sidebarReservedArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.leftMargin: 10
        width: 60
        z: 10

        Sidebar {
          id: floatingSidebar
          anchors.fill: parent
          currentPage: window.activeSection

          onNavigationRequested: function(page) {
            window.activeSection = page
            console.log("Navigation:", page)
          }
        }
      }

      // Reserved ChatList Container (same height & same border roundness)
      Item {
        id: chatListReservedArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: sidebarReservedArea.right
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.leftMargin: 10
        visible: window.chatListExpanded
        width: window.compactLayout
          ? (window.chatListExpanded ? 300 : 0)
          : (window.chatListExpanded ? 340 : 0)
        z: 5

        ChatList {
          id: chatListPane
          anchors.fill: parent
          chatModel: chatListModel
          selectedChatId: window.selectedChatId

          onPointerInsideChanged: {
            if (!pointerInside && window.compactLayout && window.chatListExpanded && window.chatListAutoExpanded)
              collapseChatListTimer.restart()
          }

          onChatSelected: function(chatId) {
            window.selectedChatId = chatId
            telegramClient.loadConversation(chatId)
            if (window.compactLayout) {
              window.chatListExpanded = false
              window.chatListAutoExpanded = false
            }
          }
        }
      }

      // Reserved Conversation Panel Container (same height & same border roundness)
      Item {
        id: conversationReservedArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: chatListReservedArea.visible ? chatListReservedArea.right : sidebarReservedArea.right
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        ConversationPanel {
          anchors.fill: parent
          chatName: window.selectedChat.name || ""
          chatInitials: window.selectedChat.initials || "?"
          avatarColor: window.selectedChat.avatarColor || "#526C8A"
          avatarPath: window.selectedChat.avatarPath || ""
          lastMessage: window.selectedChat.lastMessage || ""
          statusText: window.selectedChat.statusText || ""
          isOnline: window.selectedChat.isOnline || false
          messages: telegramClient.conversationMessages
          typing: telegramClient.typing
          appVersion: appController.appVersion

          onStartMessaging: {
            var firstChat = chatListModel.chatAt(0)
            if (firstChat.chatId === undefined)
              return
            window.chatListExpanded = true
            window.chatListAutoExpanded = false
            window.selectedChatId = firstChat.chatId
            telegramClient.loadConversation(firstChat.chatId)
          }

          onSendMessageRequested: function(text, replyToMessageId, quoteText) {
            if (window.selectedChatId) {
              telegramClient.sendMessage(window.selectedChatId, text, replyToMessageId || 0, quoteText || "")
            }
          }

          onSendMediaRequested: function(filePath, caption, replyToMessageId, quoteText) {
            if (window.selectedChatId) {
              telegramClient.sendMedia(window.selectedChatId, filePath, caption, replyToMessageId || 0, quoteText || "")
            }
          }
        }
      }

      MouseArea {
        z: 40
        visible: window.compactLayout && !window.chatListExpanded
        width: 14
        height: parent.height
        anchors.left: sidebarReservedArea.right
        anchors.bottom: parent.bottom
        hoverEnabled: true
        onEntered: {
          window.chatListExpanded = true
          window.chatListAutoExpanded = true
        }
      }
    }
  }
}
