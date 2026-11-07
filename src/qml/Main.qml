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

  // Global ToolTip aesthetic styling following single-layer elevation and theme
  ToolTip.toolTip.contentItem: Text {
    text: ToolTip.toolTip.text
    font.family: fredokaFont.name
    font.pixelSize: 12
    font.weight: Font.Medium
    color: Theme.accentText
  }

  ToolTip.toolTip.background: Item {
    implicitHeight: 28
    implicitWidth: 60

    // Contact/ambient shadow
    Rectangle {
      anchors.fill: tipGlass
      anchors.topMargin: 2
      anchors.bottomMargin: -2
      anchors.leftMargin: -1
      anchors.rightMargin: -1
      radius: tipGlass.radius + 1
      color: Qt.rgba(0, 0, 0, 0.25)
      z: -1
    }

    Rectangle {
      id: tipGlass
      anchors.fill: parent
      radius: 8
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.94)
      border.color: Theme.divider
      border.width: 1

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 7
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
      }
    }
  }

  visible: true

  readonly property real initialDefaultWidth: 1200
  width: initialDefaultWidth
  height: 760

  minimumWidth: initialDefaultWidth * 0.5
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
  property bool isHalfWidth: width <= (initialDefaultWidth * 0.5 + 40)
  property bool compactLogin: isHalfWidth
  property bool compactLayout: isHalfWidth
  property bool chatListExpanded: true
  property bool chatListAutoExpanded: false
  property real chatListCustomWidth: 320
  property bool chatListDragging: false
  property int compactContentWidth: Math.min(width - 32, 720)

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
            popup: Popup {
              y: countryBox.height + 6
              width: Math.max(countryBox.width, 180)
              implicitHeight: contentItem.implicitHeight + 12
              padding: 6

              background: Item {
                Rectangle {
                  anchors.fill: popupGlass
                  anchors.topMargin: 2
                  anchors.bottomMargin: -2
                  anchors.leftMargin: -1
                  anchors.rightMargin: -1
                  radius: popupGlass.radius + 1
                  color: Qt.rgba(0, 0, 0, 0.22)
                  z: -1
                }
                Rectangle {
                  id: popupGlass
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
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                  }
                }
              }

              contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: countryBox.popup.visible ? countryBox.delegateModel : null
                currentIndex: countryBox.highlightedIndex
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
                color: highlighted ? Theme.accent : "transparent"
                radius: 8
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

    background: Item {
      Rectangle {
        anchors.fill: settingsGlass
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: settingsGlass.radius + 1
        color: Qt.rgba(0, 0, 0, 0.22)
        z: -1
      }
      Rectangle {
        id: settingsGlass
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.94)
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
          radius: 12
          color: Theme.controlBackground
          border.color: themeSelector.activeFocus ? Theme.accent : Theme.divider
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

        popup: Popup {
          y: themeSelector.height + 6
          width: themeSelector.width
          implicitHeight: Math.min(240, contentItem.implicitHeight + 12)
          padding: 6

          background: Item {
            Rectangle {
              anchors.fill: themePopupGlass
              anchors.topMargin: 2
              anchors.bottomMargin: -2
              anchors.leftMargin: -1
              anchors.rightMargin: -1
              radius: themePopupGlass.radius + 1
              color: Qt.rgba(0, 0, 0, 0.22)
              z: -1
            }
            Rectangle {
              id: themePopupGlass
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
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
              }
            }
          }

          contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: themeSelector.popup.visible ? themeSelector.delegateModel : null
            currentIndex: themeSelector.highlightedIndex
          }
        }

        delegate: ItemDelegate {
          width: themeSelector.width
          text: modelData
          contentItem: Label {
            text: modelData
            color: highlighted ? Theme.accentText : Theme.primaryText
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8
            font.pixelSize: 14
          }
          background: Rectangle {
            color: highlighted ? Theme.accent : "transparent"
            radius: 8
          }
        }
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
    popup: Popup {
      y: globalThemeSelector.height + 6
      width: globalThemeSelector.width
      implicitHeight: Math.min(240, contentItem.implicitHeight + 12)
      padding: 6

      background: Item {
        Rectangle {
          anchors.fill: globalPopupGlass
          anchors.topMargin: 2
          anchors.bottomMargin: -2
          anchors.leftMargin: -1
          anchors.rightMargin: -1
          radius: globalPopupGlass.radius + 1
          color: Qt.rgba(0, 0, 0, 0.22)
          z: -1
        }
        Rectangle {
          id: globalPopupGlass
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
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
          }
        }
      }

      contentItem: ListView {
        clip: true
        implicitHeight: contentHeight
        model: globalThemeSelector.popup.visible ? globalThemeSelector.delegateModel : null
        currentIndex: globalThemeSelector.highlightedIndex
      }
    }

    delegate: ItemDelegate {
      width: globalThemeSelector.width
      text: modelData
      contentItem: Label {
        text: modelData
        color: highlighted ? Theme.accentText : Theme.primaryText
        verticalAlignment: Text.AlignVCenter
        leftPadding: 8
        font.pixelSize: 13
      }
      background: Rectangle {
        radius: 8
        color: highlighted ? Theme.accent : "transparent"
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
      height: 30
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
      border.color: "transparent"
      border.width: 1
      z: 20

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: "transparent"
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Image {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          source: "qrc:/qt/qml/Silkite/assets/logo-transparent.png"
          fillMode: Image.PreserveAspectFit
          smooth: true
        }

        Label {
          text: appController.appName
          font.bold: true
          font.pixelSize: 14
          color: Theme.primaryText
        }

        Item {
          Layout.fillWidth: true
        }

        ToolButton {
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/panel-left.svg"
          icon.width: 20
          icon.height: 20
          icon.color: Theme.primaryText
          enabled: true
          focusPolicy: Qt.NoFocus
          padding: 0
          implicitWidth: 28
          implicitHeight: 28
          ToolTip.visible: hovered
          ToolTip.text: window.chatListExpanded ? "Hide chats" : "Show chats"
          ToolTip.delay: 400
          background: Rectangle {
            radius: 8
            color: parent.hovered ? Theme.controlBackground : "transparent"
            border.color: parent.hovered ? Theme.divider : "transparent"
            border.width: 1

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: 7
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
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        anchors.leftMargin: 0
        width: 50
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
        anchors.leftMargin: window.chatListExpanded ? 10 : 0
        clip: true

        // Minimum width accommodates "Chats" header in its original size & position (pixelSize 22 + margins = 92px)
        readonly property real minChatBarWidth: 92
        // Custom set or default width
        readonly property real userWidth: Math.max(minChatBarWidth, window.chatListCustomWidth)

        // Space remaining for chatbar after reserving a comfortable width for conversation panel
        readonly property real maxAllowedWidth: Math.max(minChatBarWidth, contentArea.width - sidebarReservedArea.width - 400)

        // While open: width smoothly adapts according to available space, scaling down towards 92px if needed.
        // When width is <= 50%, chatbar is fixed to its lowest (92px).
        // When collapsed: width collapses completely to 0.
        readonly property real responsiveTargetWidth: {
          if (!window.chatListExpanded) return 0
          if (window.isHalfWidth) return minChatBarWidth
          return Math.max(minChatBarWidth, Math.min(userWidth, maxAllowedWidth))
        }

        width: responsiveTargetWidth
        opacity: window.chatListExpanded ? 1.0 : 0.0
        visible: width > 0 || opacity > 0
        z: 5

        Behavior on width {
          enabled: !window.chatListDragging
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Behavior on anchors.leftMargin {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

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

        // Draggable right edge splitter to resize chatbar (disabled when app width is <= 50%)
        Item {
          id: chatListSplitter
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          width: 8
          z: 30
          visible: window.chatListExpanded && !window.isHalfWidth

          Rectangle {
            anchors.centerIn: parent
            width: 2
            height: 36
            radius: 1
            color: splitterMouseArea.containsMouse || window.chatListDragging ? Theme.accent : Theme.divider
            opacity: splitterMouseArea.containsMouse || window.chatListDragging ? 1.0 : 0.35
            Behavior on opacity { NumberAnimation { duration: 150 } }
          }

          MouseArea {
            id: splitterMouseArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.SplitHCursor
            preventStealing: true

            property real startX: 0
            property real initialWidth: 0

            onPressed: function(mouse) {
              startX = mouse.x
              initialWidth = chatListReservedArea.width
              window.chatListDragging = true
            }

            onPositionChanged: function(mouse) {
              if (window.chatListDragging) {
                var delta = mouse.x - startX
                var candidateWidth = initialWidth + delta
                // Dragging resizes the open chatbar between min (92px) and max allowed space
                window.chatListCustomWidth = Math.max(chatListReservedArea.minChatBarWidth,
                                                      Math.min(candidateWidth, chatListReservedArea.maxAllowedWidth))
              }
            }

            onReleased: {
              window.chatListDragging = false
            }

            onCanceled: {
              window.chatListDragging = false
            }
          }
        }
      }

      // Reserved Conversation Panel Container (same height & same border roundness)
      Item {
        id: conversationReservedArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: chatListReservedArea.right
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        ConversationPanel {
          anchors.fill: parent
          chatId: window.selectedChatId || 0
          chatName: window.selectedChat.name || ""
          chatInitials: window.selectedChat.initials || "?"
          avatarColor: window.selectedChat.avatarColor || "#526C8A"
          avatarPath: window.selectedChat.avatarPath || ""
          lastMessage: window.selectedChat.lastMessage || ""
          statusText: window.selectedChat.statusText || ""
          isOnline: window.selectedChat.isOnline || false
          messageModel: telegramClient.messageModel
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

          onToggleReactionRequested: function(messageId, emoji, isChosen) {
            if (window.selectedChatId && messageId) {
              telegramClient.toggleReaction(window.selectedChatId, messageId, emoji, isChosen)
            }
          }
        }
      }

      MouseArea {
        z: 40
        visible: !window.isHalfWidth && window.compactLayout && !window.chatListExpanded
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
