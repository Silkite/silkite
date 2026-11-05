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

  property var selectedChat: { chatRevision; return chatListModel.chatById(selectedChatId) }
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
            color: Theme.primaryText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: height / 2
            color: parent.checked ? Theme.accent : Theme.controlBackground
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
            color: Theme.primaryText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: height / 2
            color: parent.checked ? Theme.accent : Theme.controlBackground
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
          radius: 14
          color: Theme.panelBackground
          clip: true

          Image {
            anchors.fill: parent
            anchors.margins: 8
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
              radius: 9
              color: Theme.controlBackground
              border.color: countryBox.activeFocus ? Theme.accent : "transparent"
            }
            delegate: ItemDelegate {
              width: countryBox.width
              text: modelData.flag + "  " + modelData.name + "  " + modelData.code
              contentItem: Label {
                text: modelData.flag + "  " + modelData.name + "  " + modelData.code
                color: Theme.primaryText
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }
              background: Rectangle {
                color: highlighted ? Theme.accent : Theme.controlBackground
                radius: 7
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
                  border.color: parent.activeFocus ? Theme.accent : "transparent"
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
            color: Theme.primaryText
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
            color: Theme.accent
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
              background: Rectangle { radius: width / 2; color: Theme.controlBackground; border.color: parent.activeFocus ? Theme.accent : "transparent" }
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
            color: Theme.primaryText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: height / 2
            color: parent.enabled ? Theme.accent : Theme.controlBackground
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
      radius: 14
      color: Theme.windowBackground
      border.color: Theme.divider
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
    function onChatUpdated() { window.chatRevision++ }
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
      radius: 9
      color: Theme.controlBackground
      border.color: Theme.divider
    }
    delegate: ItemDelegate {
      width: globalThemeSelector.width
      text: modelData
      contentItem: Label {
        text: modelData
        color: Theme.primaryText
        verticalAlignment: Text.AlignVCenter
      }
      background: Rectangle {
        radius: 7
        color: highlighted ? Theme.accent : Theme.controlBackground
      }
    }
  }

  Item {
    anchors.fill: parent

    Sidebar {
      id: topBar
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 48

      currentPage: window.activeSection
      chatListExpanded: window.chatListExpanded

      onNavigationRequested: function(page) {
        window.activeSection = page
        console.log("Navigation:", page)
      }

      onChatListToggleRequested: {
        window.chatListExpanded = !window.chatListExpanded
        window.chatListAutoExpanded = false
      }
    }

    Item {
      id: contentRow
      anchors.top: topBar.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom

      ChatList {
        id: chatListPane
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        visible: window.chatListExpanded
        width: window.compactLayout
          ? (window.chatListExpanded ? 300 : 0)
          : (window.chatListExpanded ? 340 : 0)

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

      ConversationPanel {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.left: chatListPane.right

      chatName: window.selectedChat.name || ""
      chatInitials: window.selectedChat.initials || "?"
      avatarColor: window.selectedChat.avatarColor || "#526C8A"
      avatarPath: window.selectedChat.avatarPath || ""
      lastMessage: window.selectedChat.lastMessage || ""
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

      onSendMessageRequested: function(text) {
        if (window.selectedChatId) {
          telegramClient.sendMessage(window.selectedChatId, text)
        }
      }
      }
    }

    MouseArea {
      z: 40
      visible: window.compactLayout && !window.chatListExpanded
      width: 14
      height: parent.height - topBar.height
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      hoverEnabled: true
      onEntered: {
        window.chatListExpanded = true
        window.chatListAutoExpanded = true
      }
    }
  }
}
