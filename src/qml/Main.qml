
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window

    visible: true

    width: 1100
    height: 720

    minimumWidth: 800
    minimumHeight: 500

    title: appController.appName

    color: "#20242b"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16

        Label {
            text: appController.appName

            font.pixelSize: 28
            font.bold: true

            color: "white"

            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: appController.appVersion
            color: "#aab2bf"

            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.preferredWidth: 350
            Layout.preferredHeight: 100

            radius: 10
            color: "#303640"

            Label {
                anchors.centerIn: parent

                text: appController.lastMessage

                color: "white"
                wrapMode: Text.WordWrap
            }
        }

        Button {
            text: "Simulate incoming message"

            Layout.alignment: Qt.AlignHCenter

            onClicked: {
                appController.simulateIncomingMessage()
            }
        }

        Label {
            id: eventLabel

            text: "Waiting for messages..."

            color: "#8b949e"

            Layout.alignment: Qt.AlignHCenter
        }
    }

    Connections {
        target: appController

        function onMessageReceived(message) {
            eventLabel.text = "Received: " + message
        }
    }
}

