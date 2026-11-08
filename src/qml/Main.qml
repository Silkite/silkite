import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects

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
    var c = chatListModel.chatById(selectedChatId)
    if (c && c.name)
      return c
    var contact = contactListModel.contactByChatId(selectedChatId)
    if (contact && contact.name)
      return contact
    if (contactListPane && contactListPane.selectedUserId) {
      var cu = contactListModel.contactByUserId(contactListPane.selectedUserId)
      if (cu && cu.name)
        return cu
    }
    return c || ({})
  }
  property int chatRevision: 0

  // Secondary Split Pane properties
  property bool splitPaneActive: false
  property var secondarySelectedChatId: 0
  property var secondarySelectedChat: {
    chatRevision;
    if (!secondarySelectedChatId)
      return ({})
    var c = chatListModel.chatById(secondarySelectedChatId)
    if (c && c.name)
      return c
    var contact = contactListModel.contactByChatId(secondarySelectedChatId)
    if (contact && contact.name)
      return contact
    return c || ({})
  }
  readonly property bool canEnableSplitPane: width >= (initialDefaultWidth * 0.6)
  property real primaryPaneRatio: 0.5
  property bool paneSplitterDragging: false

  // Global Drag Replica State
  property bool isDraggingChatReplica: false
  property var draggedChatData: null
  property real dragReplicaTargetX: 0
  property real dragReplicaTargetY: 0
  property bool dragOverSecondaryPane: false

  onWidthChanged: {
    if (!canEnableSplitPane && splitPaneActive) {
      splitPaneActive = false
    }
  }

  function openInSecondaryPane(chatId) {
    if (!canEnableSplitPane) return
    secondarySelectedChatId = chatId
    splitPaneActive = true
    telegramClient.loadSecondaryConversation(chatId)
  }

  function closeSecondaryPane() {
    splitPaneActive = false
    secondarySelectedChatId = 0
    telegramClient.closeSecondaryConversation()
  }

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
      if (telegramClient.authorizationState === "ready") {
        window.showRestrictionAlert("Telegram Error", error)
      } else {
        window.authError = error
        if (window.phoneSubmitted)
          window.clearOtp()
      }
    }
    function onGroupCreationFailed(error) {
      window.showRestrictionAlert("Group Creation Failed", error)
    }
    function onMessageSendFailed(chatId, error) {
      window.showRestrictionAlert("Message Failed to Send", error)
    }
    function onAuthenticationCodeTimeoutChanged() {
      window.resendSeconds = telegramClient.authenticationCodeTimeout
      window.resendReady = true
    }
    function onAuthorizationStateChanged() {
      const s = telegramClient.authorizationState
      if (s === "loggingOut" || s === "closing" || s === "closed") {
        window.selectedChatId = 0
        window.secondarySelectedChatId = 0
        window.phoneSubmitted = false
        window.phoneLoginStarted = false
        window.resendSeconds = 0
        window.resendReady = false
        window.authError = ""
        window.clearOtp()
        if (contactListPane)
          contactListPane.selectedUserId = 0
        if (chatOrganizationManager)
          chatOrganizationManager.resetFolders()
        if (appController)
          appController.clearClipboardCache()
        if (settingsPopup && settingsPopup.opened)
          settingsPopup.close()
        window.activeSection = "chats"
      }
    }
    function onPrivateChatCreated(userId, chatId) {
      if (String(contactListPane.selectedUserId) === String(userId)) {
        window.selectedChatId = chatId
        telegramClient.loadConversation(chatId)
        if (window.compactLayout) {
          window.chatListExpanded = false
          window.chatListAutoExpanded = false
        }
      }
    }
    function onGroupChatCreated(chatId) {
      window.activeSection = "chats"
      window.selectedChatId = chatId
      telegramClient.loadConversation(chatId)
      if (window.compactLayout) {
        window.chatListExpanded = false
        window.chatListAutoExpanded = false
      }
    }
    function onChatDeleted(chatId) {
      if (String(window.selectedChatId) === String(chatId)) {
        window.selectedChatId = 0
        telegramClient.loadConversation(0)
        if (chatListModel.rowCount() > 0) {
          var firstChat = chatListModel.chatAt(0)
          if (firstChat && firstChat.chatId) {
            window.selectedChatId = firstChat.chatId
            telegramClient.loadConversation(firstChat.chatId)
          }
        }
      }
      if (String(window.secondarySelectedChatId) === String(chatId)) {
        window.secondarySelectedChatId = 0
        telegramClient.closeSecondaryConversation()
      }
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

  readonly property bool isLoginRequired: {
    const s = telegramClient.authorizationState
    return s !== "ready"
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.windowBackground
    z: 10
    visible: window.isLoginRequired

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

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.divider
      }

      Button {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 36
        Layout.preferredWidth: 140
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
          settingsPopup.close()
          telegramClient.logOut()
        }
      }
    }
  }

  ContactProfileDialog {
    id: contactProfileDialog
  }

  function showContactProfile(profileData) {
    if (contactProfileDialog) {
      contactProfileDialog.openProfile(profileData)
    }
  }

  // Telegram Restrictions and Centered Alert Popup
  property string restrictionAlertTitle: "Action Restricted"
  property string restrictionAlertMessage: ""
  property int restrictionCountdown: 10

  function formatTelegramRestrictionError(err) {
    if (!err) return "An unexpected error occurred."
    var s = String(err).trim()
    if (s.indexOf("USER_RESTRICTED") !== -1) {
      return "Your account is restricted from creating groups or messaging non-contacts. Check @SpamBot on Telegram."
    }
    if (s.indexOf("PEER_FLOOD") !== -1) {
      return "Too many requests. Telegram temporarily limited your account. Try again later or check @SpamBot."
    }
    if (s.indexOf("CHAT_WRITE_FORBIDDEN") !== -1 || s.indexOf("SEND_MESSAGES_RESTRICTED") !== -1 || s.indexOf("USER_BANNED_IN_CHANNEL") !== -1) {
      return "You do not have permission to post in this chat."
    }
    if (s.indexOf("USER_PRIVACY_RESTRICTED") !== -1 || s.indexOf("PRIVACY") !== -1 || s.indexOf("canSendMessageToUserResultUserRestrictsNewChats") !== -1) {
      return "Restricted by the user's privacy settings."
    }
    if (s.indexOf("USER_IS_BLOCKED") !== -1 || s.indexOf("YOU_BLOCKED_USER") !== -1) {
      return "This user is blocked. Unblock them to send messages."
    }
    if (s.indexOf("USERS_TOO_FEW") !== -1) {
      return "Select at least one contact to create a group."
    }
    if (s.indexOf("SLOWMODE_WAIT_") !== -1) {
      var waitMatch = s.match(/SLOWMODE_WAIT_(\d+)/)
      var secs = waitMatch ? waitMatch[1] : ""
      return "Slow mode active. Please wait " + (secs ? secs + "s " : "") + "before sending another message."
    }
    if (s.indexOf("MESSAGE_TOO_LONG") !== -1) {
      return "Message exceeds the maximum character limit."
    }
    if (s.indexOf("CHATS_TOO_MUCH") !== -1 || s.indexOf("CHANNELS_TOO_MUCH") !== -1) {
      return "Chat limit reached (maximum 500 chats)."
    }
    return s
  }

  function showRestrictionAlert(title, message) {
    restrictionAlertTitle = title || "Action Restricted"
    restrictionAlertMessage = formatTelegramRestrictionError(message)
    restrictionCountdown = 10
    restrictionAlertPopup.open()
  }

  Timer {
    id: restrictionAutoCloseTimer
    interval: 1000
    repeat: true
    running: restrictionAlertPopup.opened
    onTriggered: {
      if (window.restrictionCountdown > 1) {
        window.restrictionCountdown--
      } else {
        window.restrictionCountdown = 0
        restrictionAutoCloseTimer.stop()
        restrictionAlertPopup.close()
      }
    }
  }

  Popup {
    id: restrictionAlertPopup
    parent: Overlay.overlay
    x: Math.round((window.width - width) / 2)
    y: Math.round((window.height - height) / 2)
    width: Math.min(420, window.width - 32)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 0
    topInset: 0
    leftInset: 0
    rightInset: 0
    bottomInset: 0

    onOpened: {
      window.restrictionCountdown = 10
      progressAnim.restart()
    }
    onClosed: {
      restrictionAutoCloseTimer.stop()
      progressAnim.stop()
    }

    Overlay.modal: Rectangle {
      color: Qt.rgba(0, 0, 0, 0.5)
      Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    background: Item {
      Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: 18
        color: Qt.rgba(0, 0, 0, 0.45)
        z: -1
      }

      Rectangle {
        id: restrictionPopupBody
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.98)
        border.color: Qt.rgba(235/255, 87/255, 87/255, 0.5)
        border.width: 1
      }
    }

    contentItem: ColumnLayout {
      id: restrictionPopupCol
      spacing: 0
      width: parent.width

      // Header row
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 16
        Layout.leftMargin: 18
        Layout.rightMargin: 16
        Layout.bottomMargin: 10
        spacing: 12

        Rectangle {
          Layout.preferredWidth: 38
          Layout.preferredHeight: 38
          radius: 19
          color: Qt.rgba(235/255, 87/255, 87/255, 0.15)
          border.color: Qt.rgba(235/255, 87/255, 87/255, 0.35)
          border.width: 1

          Image {
            anchors.centerIn: parent
            source: "qrc:/qt/qml/Silkite/assets/icons/info.svg"
            width: 20
            height: 20
            sourceSize: Qt.size(20, 20)
            layer.enabled: true
            layer.effect: ColorOverlay {
              color: "#EB5757"
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Label {
            text: window.restrictionAlertTitle
            color: Theme.primaryText
            font.pixelSize: 15
            font.weight: Font.DemiBold
            Layout.fillWidth: true
          }

          Label {
            text: "Telegram Notice"
            color: "#EB5757"
            font.pixelSize: 11
            font.weight: Font.Medium
          }
        }

        Item {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28

          Rectangle {
            anchors.fill: parent
            radius: 14
            color: closeRestMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
          }

          Image {
            anchors.centerIn: parent
            source: "qrc:/qt/qml/Silkite/assets/icons/close.svg"
            width: 14
            height: 14
            sourceSize: Qt.size(14, 14)
            layer.enabled: true
            layer.effect: ColorOverlay {
              color: closeRestMouseArea.containsMouse ? Theme.primaryText : Theme.secondaryText
            }
          }

          MouseArea {
            id: closeRestMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: restrictionAlertPopup.close()
          }
        }
      }

      // Divider line
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.divider
        opacity: 0.5
      }

      // Message Body
      Label {
        Layout.fillWidth: true
        Layout.margins: 18
        Layout.topMargin: 14
        Layout.bottomMargin: 14
        text: window.restrictionAlertMessage
        color: Theme.primaryText
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        lineHeight: 1.3
      }

      // 5-second progress bar
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 2
        color: Qt.rgba(255, 255, 255, 0.08)

        Rectangle {
          id: progressBarFill
          height: parent.height
          width: parent.width * progressAnim.progress
          color: "#EB5757"
          opacity: 0.8
        }
      }

      // Footer
      RowLayout {
        Layout.fillWidth: true
        Layout.margins: 14
        Layout.topMargin: 10
        spacing: 12

        RowLayout {
          spacing: 6
          Layout.fillWidth: true

          Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 4
            color: "#EB5757"
          }

          Label {
            text: "Closing in " + window.restrictionCountdown + "s"
            color: Theme.secondaryText
            font.pixelSize: 11
          }
        }

        Button {
          text: "OK"
          font.pixelSize: 12
          font.weight: Font.Medium
          implicitWidth: 80
          implicitHeight: 32
          focusPolicy: Qt.NoFocus
          onClicked: restrictionAlertPopup.close()

          contentItem: Text {
            text: parent.text
            font: parent.font
            color: "#FFFFFF"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          background: Rectangle {
            radius: 8
            color: parent.down ? Qt.darker(Theme.accent, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
          }
        }
      }
    }

    NumberAnimation {
      id: progressAnim
      target: progressAnim
      property: "progress"
      from: 1.0
      to: 0.0
      duration: 10000
      property real progress: 1.0
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
    visible: window.isLoginRequired
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
      height: 36
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
        anchors.leftMargin: 4
        anchors.rightMargin: 8
        spacing: 6

        Image {
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          Layout.alignment: Qt.AlignVCenter
          source: "qrc:/qt/qml/Silkite/assets/logo-transparent.png"
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
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

        Item {
          Layout.fillWidth: true
        }

        // Toggle Split Pane button
        ToolButton {
          visible: window.canEnableSplitPane
          icon.source: "qrc:/qt/qml/Silkite/assets/icons/split-pane.svg"
          icon.width: 18
          icon.height: 18
          icon.color: window.splitPaneActive ? Theme.accent : Theme.primaryText
          focusPolicy: Qt.NoFocus
          padding: 0
          implicitWidth: 28
          implicitHeight: 28
          ToolTip.visible: hovered
          ToolTip.text: window.splitPaneActive ? "Close split pane" : "Open split pane"
          ToolTip.delay: 400
          background: Rectangle {
            radius: 8
            color: window.splitPaneActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : (parent.hovered ? Theme.controlBackground : "transparent")
            border.color: window.splitPaneActive ? Theme.accent : (parent.hovered ? Theme.divider : "transparent")
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
            if (window.splitPaneActive) {
              window.closeSecondaryPane()
            } else {
              window.splitPaneActive = true
            }
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
            if (page === "contacts") {
              telegramClient.loadContacts()
            }
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
          visible: window.activeSection !== "contacts"

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

          onOpenInSplitRequested: function(chatId) {
            window.openInSecondaryPane(chatId)
          }

          onDragStarted: function(chatData, startPos) {
            if (!window.canEnableSplitPane) return
            // Auto-open split pane if not open so user has a drop area!
            if (!window.splitPaneActive) {
              window.splitPaneActive = true
            }
            window.draggedChatData = chatData
            window.dragReplicaTargetX = startPos.x - 40
            window.dragReplicaTargetY = startPos.y - 30
            window.isDraggingChatReplica = true
          }

          onDragMoved: function(globalPos) {
            if (!window.isDraggingChatReplica) return
            window.dragReplicaTargetX = globalPos.x - 40
            window.dragReplicaTargetY = globalPos.y - 30

            // Check if hovered over secondaryPaneContainer
            var secPos = secondaryPaneContainer.mapFromItem(null, globalPos.x, globalPos.y)
            window.dragOverSecondaryPane = (secPos.x >= 0 && secPos.x <= secondaryPaneContainer.width &&
                                            secPos.y >= 0 && secPos.y <= secondaryPaneContainer.height)
          }

          onDragEnded: function(globalPos) {
            if (!window.isDraggingChatReplica) return
            var secPos = secondaryPaneContainer.mapFromItem(null, globalPos.x, globalPos.y)
            var droppedInside = (secPos.x >= 0 && secPos.x <= secondaryPaneContainer.width &&
                                 secPos.y >= 0 && secPos.y <= secondaryPaneContainer.height)

            if (droppedInside && window.draggedChatData && window.draggedChatData.chatId) {
              window.openInSecondaryPane(window.draggedChatData.chatId)
            }
            window.isDraggingChatReplica = false
            window.dragOverSecondaryPane = false
            window.draggedChatData = null
          }
        }

        ContactList {
          id: contactListPane
          anchors.fill: parent
          contactModel: contactListModel
          visible: window.activeSection === "contacts"

          onPointerInsideChanged: {
            if (!pointerInside && window.compactLayout && window.chatListExpanded && window.chatListAutoExpanded)
              collapseChatListTimer.restart()
          }

          onContactSelected: function(userId, chatId) {
            contactListPane.selectedUserId = userId
            if (chatId && chatId !== 0) {
              window.selectedChatId = chatId
              telegramClient.loadConversation(chatId)
              if (window.compactLayout) {
                window.chatListExpanded = false
                window.chatListAutoExpanded = false
              }
            } else {
              telegramClient.createPrivateChatForUser(userId)
            }
          }

          onOpenInSplitRequested: function(chatId) {
            if (chatId && chatId !== 0) {
              window.openInSecondaryPane(chatId)
            }
          }

          onDragStarted: function(contactData, startPos) {
            if (!window.canEnableSplitPane) return
            if (!window.splitPaneActive) {
              window.splitPaneActive = true
            }
            window.draggedChatData = contactData
            window.dragReplicaTargetX = startPos.x - 40
            window.dragReplicaTargetY = startPos.y - 30
            window.isDraggingChatReplica = true
          }

          onDragMoved: function(globalPos) {
            if (!window.isDraggingChatReplica) return
            window.dragReplicaTargetX = globalPos.x - 40
            window.dragReplicaTargetY = globalPos.y - 30

            var secPos = secondaryPaneContainer.mapFromItem(null, globalPos.x, globalPos.y)
            window.dragOverSecondaryPane = (secPos.x >= 0 && secPos.x <= secondaryPaneContainer.width &&
                                            secPos.y >= 0 && secPos.y <= secondaryPaneContainer.height)
          }

          onDragEnded: function(globalPos) {
            if (!window.isDraggingChatReplica) return
            var secPos = secondaryPaneContainer.mapFromItem(null, globalPos.x, globalPos.y)
            var droppedInside = (secPos.x >= 0 && secPos.x <= secondaryPaneContainer.width &&
                                 secPos.y >= 0 && secPos.y <= secondaryPaneContainer.height)

            if (droppedInside && window.draggedChatData) {
              if (window.draggedChatData.chatId && window.draggedChatData.chatId !== 0) {
                window.openInSecondaryPane(window.draggedChatData.chatId)
              } else if (window.draggedChatData.userId) {
                telegramClient.createPrivateChatForUser(window.draggedChatData.userId)
              }
            }
            window.isDraggingChatReplica = false
            window.dragOverSecondaryPane = false
            window.draggedChatData = null
          }
        }

        // Draggable right edge splitter to resize chatbar (disabled when app width is <= 50% or dragging a chat)
        Item {
          id: chatListSplitter
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          width: 8
          z: 30
          visible: window.chatListExpanded && !window.isHalfWidth && !window.isDraggingChatReplica

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

      // Reserved Conversation Area (Supports horizontal split with dual conversation panels)
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

        readonly property real availablePanesWidth: width - (window.splitPaneActive ? 18 : 0)

        // Primary Conversation Pane
        Item {
          id: primaryPaneContainer
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          width: window.splitPaneActive
                 ? Math.max(300, Math.min(conversationReservedArea.availablePanesWidth - 300, conversationReservedArea.availablePanesWidth * window.primaryPaneRatio))
                 : parent.width

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
            canSendMessages: window.selectedChat.canSendMessages !== undefined ? window.selectedChat.canSendMessages : true
            messageModel: telegramClient.messageModel
            messages: telegramClient.conversationMessages
            typing: telegramClient.typing
            appVersion: appController.appVersion
            isSecondaryPane: false

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
              if (window.selectedChat && window.selectedChat.canSendMessages === false) {
                window.showRestrictionAlert("Posting Restricted", "You are not allowed to send messages in this chat.")
                return
              }
              if (window.selectedChatId) {
                telegramClient.sendMessage(window.selectedChatId, text, replyToMessageId || 0, quoteText || "")
              }
            }

            onSendMediaRequested: function(filePath, caption, replyToMessageId, quoteText) {
              if (window.selectedChat && window.selectedChat.canSendMessages === false) {
                window.showRestrictionAlert("Posting Restricted", "You are not allowed to send media in this chat.")
                return
              }
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

        // Draggable Splitter Divider between Primary and Secondary Panes
        Item {
          id: paneSplitter
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: primaryPaneContainer.right
          width: 18
          visible: window.splitPaneActive
          z: 35

          Rectangle {
            anchors.centerIn: parent
            width: 3
            height: 48
            radius: 1.5
            color: paneSplitterMouseArea.containsMouse || window.paneSplitterDragging ? Theme.accent : Theme.divider
            opacity: paneSplitterMouseArea.containsMouse || window.paneSplitterDragging ? 1.0 : 0.45
            Behavior on opacity { NumberAnimation { duration: 150 } }
          }

          MouseArea {
            id: paneSplitterMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SplitHCursor
            preventStealing: true

            property real startX: 0
            property real initialPrimaryWidth: 0

            onPressed: function(mouse) {
              startX = mouse.x
              initialPrimaryWidth = primaryPaneContainer.width
              window.paneSplitterDragging = true
            }

            onPositionChanged: function(mouse) {
              if (window.paneSplitterDragging) {
                var delta = mouse.x - startX
                var newW = Math.max(300, Math.min(conversationReservedArea.availablePanesWidth - 300, initialPrimaryWidth + delta))
                window.primaryPaneRatio = newW / Math.max(1, conversationReservedArea.availablePanesWidth)
              }
            }

            onReleased: {
              window.paneSplitterDragging = false
            }

            onCanceled: {
              window.paneSplitterDragging = false
            }
          }
        }

        // Secondary Conversation Pane Container
        Item {
          id: secondaryPaneContainer
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: paneSplitter.right
          anchors.right: parent.right
          visible: window.splitPaneActive

          // Drop target for dragging and dropping chats from chat list
          DropArea {
            id: chatDropArea
            anchors.fill: parent
            keys: ["silkite/chat"]

            onDropped: function(drop) {
              if (drop.source && drop.source.chatId !== undefined) {
                window.openInSecondaryPane(drop.source.chatId)
                drop.accept()
              }
            }
          }

          // Active conversation panel if secondarySelectedChatId is set
          ConversationPanel {
            anchors.fill: parent
            visible: window.secondarySelectedChatId !== 0 && window.secondarySelectedChat.name !== undefined
            chatId: window.secondarySelectedChatId || 0
            chatName: window.secondarySelectedChat.name || ""
            chatInitials: window.secondarySelectedChat.initials || "?"
            avatarColor: window.secondarySelectedChat.avatarColor || "#526C8A"
            avatarPath: window.secondarySelectedChat.avatarPath || ""
            lastMessage: window.secondarySelectedChat.lastMessage || ""
            statusText: window.secondarySelectedChat.statusText || ""
            isOnline: window.secondarySelectedChat.isOnline || false
            canSendMessages: window.secondarySelectedChat.canSendMessages !== undefined ? window.secondarySelectedChat.canSendMessages : true
            messageModel: telegramClient.secondaryMessageModel
            messages: telegramClient.secondaryConversationMessages
            typing: telegramClient.secondaryTyping
            appVersion: appController.appVersion
            isSecondaryPane: true

            onClosePaneRequested: {
              window.closeSecondaryPane()
            }

            onSendMessageRequested: function(text, replyToMessageId, quoteText) {
              if (window.secondarySelectedChat && window.secondarySelectedChat.canSendMessages === false) {
                window.showRestrictionAlert("Posting Restricted", "You are not allowed to send messages in this chat.")
                return
              }
              if (window.secondarySelectedChatId) {
                telegramClient.sendMessage(window.secondarySelectedChatId, text, replyToMessageId || 0, quoteText || "")
              }
            }

            onSendMediaRequested: function(filePath, caption, replyToMessageId, quoteText) {
              if (window.secondarySelectedChat && window.secondarySelectedChat.canSendMessages === false) {
                window.showRestrictionAlert("Posting Restricted", "You are not allowed to send media in this chat.")
                return
              }
              if (window.secondarySelectedChatId) {
                telegramClient.sendMedia(window.secondarySelectedChatId, filePath, caption, replyToMessageId || 0, quoteText || "")
              }
            }

            onToggleReactionRequested: function(messageId, emoji, isChosen) {
              if (window.secondarySelectedChatId && messageId) {
                telegramClient.toggleReaction(window.secondarySelectedChatId, messageId, emoji, isChosen)
              }
            }
          }

          // Empty state when no chat is selected for the second pane
          Item {
            id: secondaryEmptyState
            anchors.fill: parent
            visible: window.secondarySelectedChatId === 0 || window.secondarySelectedChat.name === undefined

            Rectangle {
              id: emptyStateGlass
              anchors.fill: parent
              radius: 18
              color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
              border.color: (chatDropArea.containsDrag || window.dragOverSecondaryPane) ? Theme.accent : Theme.divider
              border.width: (chatDropArea.containsDrag || window.dragOverSecondaryPane) ? 2 : 1

              Behavior on border.color { ColorAnimation { duration: 150 } }

              Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 17
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
              }
            }

            // Top close button on empty state
            ToolButton {
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: 12
              icon.source: "qrc:/qt/qml/Silkite/assets/icons/close.svg"
              icon.width: 18
              icon.height: 18
              icon.color: parent.hovered ? Theme.accentText : Theme.primaryText
              focusPolicy: Qt.NoFocus
              implicitWidth: 32
              implicitHeight: 32
              ToolTip.visible: hovered
              ToolTip.text: "Close split pane"
              background: Rectangle {
                radius: 8
                color: parent.hovered ? Theme.accent : "transparent"
              }
              onClicked: window.closeSecondaryPane()
            }

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 14
              width: Math.min(320, parent.width - 40)

              // Decorative icon
              Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56
                height: 56
                radius: 28
                color: (chatDropArea.containsDrag || window.dragOverSecondaryPane) ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Theme.controlBackground
                border.color: (chatDropArea.containsDrag || window.dragOverSecondaryPane) ? Theme.accent : Theme.divider
                border.width: 1

                Image {
                  anchors.centerIn: parent
                  width: 26
                  height: 26
                  source: "qrc:/qt/qml/Silkite/assets/icons/split-pane.svg"
                  fillMode: Image.PreserveAspectFit
                }
              }

              Label {
                Layout.alignment: Qt.AlignHCenter
                text: (chatDropArea.containsDrag || window.dragOverSecondaryPane) ? "Drop chat here to open" : "Secondary Chat Pane"
                font.bold: true
                font.pixelSize: 16
                color: (chatDropArea.containsDrag || window.dragOverSecondaryPane) ? Theme.accent : Theme.primaryText
              }

              Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Select a chat from the available list below, or drag & drop any chat here from the chats list."
                font.pixelSize: 12
                color: Theme.secondaryText
              }

              Button {
                Layout.alignment: Qt.AlignHCenter
                text: "Choose Chat..."
                implicitHeight: 36
                onClicked: chatPickerPopup.open()

                contentItem: Label {
                  text: parent.text
                  color: Theme.accentText
                  font.weight: Font.DemiBold
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  leftPadding: 16
                  rightPadding: 16
                }

                background: Rectangle {
                  radius: height / 2
                  color: parent.pressed ? Qt.darker(Theme.accent, 1.15) : (parent.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                }
              }
            }

            // Chat Selector Popup from available chatListModel
            Popup {
              id: chatPickerPopup
              anchors.centerIn: parent
              width: Math.min(320, parent.width - 24)
              implicitHeight: 380
              padding: 12
              modal: true
              focus: true

              background: Item {
                Rectangle {
                  anchors.fill: parent
                  radius: 14
                  color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.96)
                  border.color: Theme.divider
                  border.width: 1

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 13
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                  }
                }
              }

              contentItem: ColumnLayout {
                spacing: 10

                Label {
                  text: "Select Chat for Split Pane"
                  font.bold: true
                  font.pixelSize: 14
                  color: Theme.primaryText
                  Layout.alignment: Qt.AlignLeft
                }

                ListView {
                  id: pickerListView
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  clip: true
                  model: chatListModel
                  spacing: 4

                  delegate: ItemDelegate {
                    width: pickerListView.width
                    height: 48

                    required property string name
                    required property var chatId
                    required property string initials
                    required property string avatarColor

                    background: Rectangle {
                      radius: 8
                      color: parent.hovered ? Theme.controlBackground : "transparent"
                    }

                    contentItem: RowLayout {
                      spacing: 10
                      Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: avatarColor || Theme.accent
                        Label {
                          anchors.centerIn: parent
                          text: initials || "?"
                          color: "#FFFFFF"
                          font.bold: true
                          font.pixelSize: 12
                        }
                      }
                      Label {
                        Layout.fillWidth: true
                        text: name
                        color: Theme.primaryText
                        font.pixelSize: 13
                        elide: Text.ElideRight
                      }
                    }

                    onClicked: {
                      window.openInSecondaryPane(chatId)
                      chatPickerPopup.close()
                    }
                  }
                }

                Button {
                  Layout.alignment: Qt.AlignRight
                  text: "Cancel"
                  implicitHeight: 30
                  onClicked: chatPickerPopup.close()
                  contentItem: Label {
                    text: parent.text
                    color: Theme.secondaryText
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }
                  background: Rectangle {
                    radius: 6
                    color: parent.hovered ? Theme.controlBackground : "transparent"
                  }
                }
              }
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

  // Floating replica of the chat item while dragging across the app
  Item {
    id: dragReplicaItem
    z: 9999
    visible: window.isDraggingChatReplica && window.draggedChatData !== null
    width: 260
    height: 64
    x: window.dragReplicaTargetX
    y: window.dragReplicaTargetY

    // Smooth inertia / lag-free fluid tracking (short gentle spring)
    Behavior on x {
      NumberAnimation { duration: 40; easing.type: Easing.OutQuad }
    }
    Behavior on y {
      NumberAnimation { duration: 40; easing.type: Easing.OutQuad }
    }

    scale: window.dragOverSecondaryPane ? 1.05 : 1.0
    rotation: window.dragOverSecondaryPane ? 1.5 : -1.5
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // Ambient drop shadow
    Rectangle {
      anchors.fill: replicaBody
      anchors.topMargin: 8
      anchors.bottomMargin: -6
      anchors.leftMargin: -3
      anchors.rightMargin: -3
      radius: replicaBody.radius + 2
      color: Qt.rgba(0, 0, 0, 0.35)
      z: -1
    }

    // Glass card replica
    Rectangle {
      id: replicaBody
      anchors.fill: parent
      radius: 14
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.95)
      border.color: window.dragOverSecondaryPane ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
      border.width: 1.5

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 13
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        // Avatar
        Rectangle {
          Layout.preferredWidth: 40
          Layout.preferredHeight: 40
          radius: 20
          color: (window.draggedChatData && window.draggedChatData.avatarColor) ? window.draggedChatData.avatarColor : Theme.accent
          border.color: Qt.rgba(1, 1, 1, 0.2)
          border.width: 1

          Label {
            anchors.centerIn: parent
            text: (window.draggedChatData && window.draggedChatData.initials) ? window.draggedChatData.initials : "?"
            color: "#FFFFFF"
            font.bold: true
            font.pixelSize: 14
          }
        }

        // Details
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Label {
            text: (window.draggedChatData && window.draggedChatData.name) ? window.draggedChatData.name : ""
            color: Theme.primaryText
            font.bold: true
            font.pixelSize: 13
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Label {
            text: window.dragOverSecondaryPane ? "Release to open here" : ((window.draggedChatData && window.draggedChatData.lastMessage) ? window.draggedChatData.lastMessage : "Chat")
            color: window.dragOverSecondaryPane ? Theme.accent : Theme.secondaryText
            font.pixelSize: 11
            font.weight: window.dragOverSecondaryPane ? Font.Medium : Font.Normal
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
