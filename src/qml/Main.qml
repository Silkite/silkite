import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
  id: window

  visible: true

  width: 1200
  height: 760

  minimumWidth: 320
  minimumHeight: 600

  title: appController.appName

  color: "#1C222B"

  property int selectedChatIndex: 1
  property string activeSection: "chats"

  property var selectedChat: chatListModel.chatAt(selectedChatIndex)

  property bool phoneLoginStarted: false
  property bool showQrLogin: true
  property bool compactLogin: width <= Screen.width * 0.5
  property string selectedCountryCode: "+91"
  property string selectedCountryFlag: "🇮🇳"
  property var countries: [
    { name: "India", code: "+91", flag: "🇮🇳" },
    { name: "United States", code: "+1", flag: "🇺🇸" },
    { name: "United Kingdom", code: "+44", flag: "🇬🇧" },
    { name: "Canada", code: "+1", flag: "🇨🇦" },
    { name: "Australia", code: "+61", flag: "🇦🇺" },
    { name: "Germany", code: "+49", flag: "🇩🇪" },
    { name: "France", code: "+33", flag: "🇫🇷" },
    { name: "Japan", code: "+81", flag: "🇯🇵" },
    { name: "Singapore", code: "+65", flag: "🇸🇬" },
    { name: "United Arab Emirates", code: "+971", flag: "🇦🇪" }
  ]

  function submitOtp() {
    var code = ""
    for (var i = 0; i < otpRepeater.count; ++i)
      code += otpRepeater.itemAt(i).text
    if (code.length === 5 || code.length === 6)
      telegramClient.submitCode(code)
  }

  Rectangle {
    anchors.fill: parent
    color: "#1C222B"
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
          onClicked: window.showQrLogin = true
          background: Rectangle {
            radius: 9
            color: parent.checked ? "#414D5D" : "#29313C"
          }
        }
        Button {
          text: "Phone number"
          checkable: true
          checked: !window.showQrLogin
          onClicked: window.showQrLogin = false
          background: Rectangle {
            radius: 9
            color: parent.checked ? "#414D5D" : "#29313C"
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        spacing: compactLogin ? 0 : 42

      ColumnLayout {
        Layout.preferredWidth: compactLogin ? (showQrLogin ? 360 : 0) : 360
        Layout.maximumWidth: compactLogin ? (showQrLogin ? 360 : 0) : 360
        opacity: compactLogin && !showQrLogin ? 0 : 1
        enabled: !compactLogin || showQrLogin
        spacing: 12
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Label { text: "Log in with QR code"; color: "white"; font.pixelSize: 22; Layout.alignment: Qt.AlignHCenter }
        Rectangle {
          Layout.preferredWidth: 260; Layout.preferredHeight: 260
          Layout.alignment: Qt.AlignHCenter
          radius: 14
          color: "white"
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
          color: "#AAB3C0"; wrapMode: Text.WordWrap; Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
        }
      }

      Rectangle {
        Layout.preferredWidth: compactLogin ? 0 : 1
        Layout.preferredHeight: compactLogin ? 0 : 440
        opacity: compactLogin ? 0 : 1
        color: "#39424F"
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
      }

      ColumnLayout {
        Layout.preferredWidth: compactLogin ? (showQrLogin ? 0 : 360) : 360
        Layout.maximumWidth: compactLogin ? (showQrLogin ? 0 : 360) : 360
        opacity: compactLogin && showQrLogin ? 0 : 1
        enabled: !compactLogin || !showQrLogin
        spacing: 14
        visible: telegramClient.authorizationState !== "waitCode"
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Label { text: "Log in with phone number"; color: "white"; font.pixelSize: 22; Layout.alignment: Qt.AlignHCenter }
        Label { text: "Choose your country and enter your number"; color: "#AAB3C0"; Layout.alignment: Qt.AlignHCenter }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          ComboBox {
            id: countryBox
            Layout.preferredWidth: 122
            Layout.preferredHeight: 48
            model: window.countries
            textRole: "name"
            displayText: window.selectedCountryFlag + "  " + window.selectedCountryCode
            contentItem: Label {
              leftPadding: 14
              text: countryBox.displayText
              color: "white"
              verticalAlignment: Text.AlignVCenter
              font.pixelSize: 15
            }
            background: Rectangle {
              radius: 9
              color: "#29313C"
              border.color: countryBox.activeFocus ? "#82AFFF" : "transparent"
            }
            delegate: ItemDelegate {
              width: countryBox.width
              text: modelData.flag + "  " + modelData.name + "  " + modelData.code
              contentItem: Label {
                text: modelData.flag + "  " + modelData.name + "  " + modelData.code
                color: "white"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }
              background: Rectangle {
                color: highlighted ? "#414D5D" : "#29313C"
                radius: 7
              }
            }
            onActivated: {
              window.selectedCountryCode = window.countries[index].code
              window.selectedCountryFlag = window.countries[index].flag
            }
          }

          TextField {
            id: phoneInput
            Layout.fillWidth: true; color: "white"
            Layout.preferredHeight: 48
            placeholderText: "Phone number"
            inputMethodHints: Qt.ImhDialableCharactersOnly
            background: Rectangle { radius: 9; color: "#29313C" }
          }
        }
        Button {
          text: "Continue"
          Layout.alignment: Qt.AlignHCenter
          enabled: phoneInput.text.length > 3 && telegramClient.authorizationState !== "waitCode"
          onClicked: {
            window.phoneLoginStarted = true
            telegramClient.submitPhoneNumber(window.selectedCountryCode + phoneInput.text)
            phoneInput.clear()
          }
        }
      }

      ColumnLayout {
        Layout.preferredWidth: 360
        spacing: 14
        visible: telegramClient.authorizationState === "waitCode"
        Label { text: "Enter Telegram code"; color: "white"; font.pixelSize: 22; Layout.alignment: Qt.AlignHCenter }
        Label { text: "Enter the code sent to your Telegram account"; color: "#AAB3C0"; Layout.alignment: Qt.AlignHCenter }
        Row {
          Layout.alignment: Qt.AlignHCenter
          spacing: 8
          Repeater {
            id: otpRepeater
            model: 5
            delegate: TextField {
              width: 48; height: 58
              color: "white"; horizontalAlignment: Text.AlignHCenter
              font.pixelSize: 22; maximumLength: 1
              inputMethodHints: Qt.ImhDigitsOnly
              background: Rectangle { radius: 8; color: "#29313C"; border.color: parent.activeFocus ? "#82AFFF" : "transparent" }
              onTextChanged: if (text.length === 1 && index + 1 < otpRepeater.count) otpRepeater.itemAt(index + 1).forceActiveFocus()
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Backspace && text.length === 0 && index > 0) {
                  otpRepeater.itemAt(index - 1).forceActiveFocus()
                  event.accepted = true
                }
              }
            }
          }
        }
        Button { text: "Verify"; Layout.alignment: Qt.AlignHCenter; enabled: true; onClicked: window.submitOtp() }
      }
      }
    }
  }

  Component.onCompleted: telegramClient.requestQrLogin()

  RowLayout {
    anchors.fill: parent
    spacing: 0

    Sidebar {
      Layout.preferredWidth: 68
      Layout.fillHeight: true

      currentPage: window.activeSection

      onNavigationRequested: function(page) {
        window.activeSection = page
        console.log("Navigation:", page)
      }
    }

    ChatList {
      Layout.preferredWidth: 340
      Layout.fillHeight: true

      chatModel: chatListModel
      selectedChatIndex: window.selectedChatIndex

      onChatSelected: function(index) {
        window.selectedChatIndex = index
      }
    }

    ConversationPanel {
      Layout.fillWidth: true
      Layout.fillHeight: true

      chatName: window.selectedChat.name
      chatInitials: window.selectedChat.initials
      avatarColor: window.selectedChat.avatarColor
      lastMessage: window.selectedChat.lastMessage
    }
  }
}
