
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

  property int selectedChatIndex: 0
  property string activeSection: "chats"

  property var selectedChat: chatsModel.get(selectedChatIndex)

  ListModel {
    id: chatsModel

    ListElement {
      name: "Alex Morgan"
      lastMessage: "Hello, sup lol"
      time: "10:59"
      initials: "AM"
      avatarColor: "#526C8A"
    }
  }

  RowLayout {
    anchors.fill: parent
    spacing: 0

    Sidebar {
      Layout.preferredWidth: 68
      Layout.fillHeight: true

      onNavigationRequested: function(page) {
        window.activeSection = page
        console.log("Navigation:", page)
      }
    }

    ChatList {
      Layout.preferredWidth: 340
      Layout.fillHeight: true

      chatModel: chatsModel
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
