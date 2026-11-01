
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var chatModel
    property int selectedChatIndex: 0

    signal chatSelected(int index)

    color: "#29313C"

    // A real QML model for displaying filtered chats
    ListModel {
        id: filteredChatsModel
    }

    // Filter the original chat model
    function updateFilteredChats() {
        filteredChatsModel.clear()

        if (!root.chatModel) {
            return
        }

        const query = searchField.text.trim().toLowerCase()


        for (let i = 0; i < root.chatModel.count; i++) {
            const chat = root.chatModel.get(i)

            const matchesName =
                chat.name.toLowerCase().includes(query)

            const matchesMessage =
                chat.lastMessage.toLowerCase().includes(query)

            if (query === "" || matchesName || matchesMessage) {
                filteredChatsModel.append({
                    name: chat.name,
                    lastMessage: chat.lastMessage,
                    time: chat.time,
                    initials: chat.initials,
                    avatarColor: chat.avatarColor,
                    unreadCount: chat.unreadCount,

                    // Preserve the original model index
                    originalIndex: i
                })
            }
        }

    }

    Component.onCompleted: updateFilteredChats()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Label {
            text: "Chats"
            font.pixelSize: 23
            font.bold: true
            color: "#FFFFFF"
        }

        TextField {
            id: searchField

            Layout.fillWidth: true
            placeholderText: "Search chats..."
            color: "#FFFFFF"
            selectByMouse: true

            onTextChanged: root.updateFilteredChats()

            background: Rectangle {
                radius: 9
                color: "#202630"
            }
        }

        ListView {
            id: chatList

            Layout.fillWidth: true
            Layout.fillHeight: true

            model: filteredChatsModel
            spacing: 5
            clip: true

            delegate: ItemDelegate {
                id: chatDelegate

                required property string name
                required property string lastMessage
                required property string time
                required property string initials
                required property string avatarColor
                required property int unreadCount
                required property int originalIndex

                width: chatList.width
                height: 76

                background: Rectangle {
                    radius: 9

                    color: chatDelegate.originalIndex === root.selectedChatIndex
                           ? "#414D5D"
                           : "transparent"
                }

                onClicked: root.chatSelected(chatDelegate.originalIndex)

                contentItem: RowLayout {
                    spacing: 10

                    // Avatar
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: chatDelegate.avatarColor

                        Label {
                            anchors.centerIn: parent
                            text: chatDelegate.initials
                            color: "#FFFFFF"
                            font.bold: true
                        }
                    }

                    // Chat details
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Label {
                                text: chatDelegate.name
                                color: "#FFFFFF"
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Label {
                                text: chatDelegate.time
                                color: "#AAB3C0"
                                font.pixelSize: 10
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Label {
                                text: chatDelegate.lastMessage
                                color: "#AAB3C0"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 10
                                color: "#82AFFF"

                                visible: chatDelegate.unreadCount > 0

                                Label {
                                    anchors.centerIn: parent
                                    text: chatDelegate.unreadCount.toString()
                                    color: "#202630"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: chatList.count === 0
                text: "No chats found"
                color: "#AAB3C0"
                font.pixelSize: 14
            }
        }
    }
}

