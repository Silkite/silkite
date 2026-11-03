import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
  id: window

  visible: true

  width: 1200
  height: 760

  minimumWidth: 900
  minimumHeight: 600

  title: appController.appName

  color: "#1C222B"

  property int selectedChatIndex: 1
  property string activeSection: "chats"

  property var selectedChat: chatListModel.chatAt(selectedChatIndex)

  Rectangle {
    anchors.fill: parent
    color: "#1C222B"
    z: 10
    visible: telegramClient.authorizationState !== "ready"

    ColumnLayout {
      anchors.centerIn: parent
      width: Math.min(parent.width - 80, 420)
      spacing: 14

      Label { text: "Sign in to Telegram"; color: "white"; font.pixelSize: 24; Layout.alignment: Qt.AlignHCenter }
      Label {
        text: telegramClient.authorizationState === "waitCode" ? "Enter the code sent by Telegram" : "Enter your phone number"
        color: "#AAB3C0"; Layout.alignment: Qt.AlignHCenter
      }
      TextField {
        id: authInput; Layout.fillWidth: true; color: "white"
        placeholderText: telegramClient.authorizationState === "waitCode" ? "Code" : "+1234567890"
        inputMethodHints: telegramClient.authorizationState === "waitCode" ? Qt.ImhDigitsOnly : Qt.ImhDialableCharactersOnly
        background: Rectangle { radius: 8; color: "#29313C" }
      }
      Button {
        text: "Continue"; Layout.alignment: Qt.AlignHCenter
        enabled: telegramClient.authorizationState === "waitPhoneNumber" || telegramClient.authorizationState === "waitCode"
        onClicked: {
          if (telegramClient.authorizationState === "waitCode") telegramClient.submitCode(authInput.text)
          else telegramClient.submitPhoneNumber(authInput.text)
          authInput.clear()
        }
      }
      Label {
        text: telegramClient.authorizationState === "starting" || telegramClient.authorizationState === "waitTdlibParameters" ? "Waiting for TDLib configuration…" : ""
        color: "#AAB3C0"; wrapMode: Text.WordWrap; Layout.fillWidth: true
      }
    }
  }

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
