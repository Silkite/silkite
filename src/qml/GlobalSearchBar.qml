import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Popup {
  id: root

  property var searchModel: globalSearchModel

  signal openChatRequested(var chatId, var userId)

  parent: Overlay.overlay
  x: Math.round((parent ? parent.width - width : window.width - width) / 2)
  y: 42
  width: Math.min(window.width - 32, 620)
  height: Math.min(window.height - 70, 520)

  modal: true
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
  padding: 0
  topInset: 0
  leftInset: 0
  rightInset: 0
  bottomInset: 0

  onOpened: {
    searchInput.forceActiveFocus()
  }

  onClosed: {
    searchInput.clear()
    remoteSearchTimer.stop()
    if (root.searchModel) {
      root.searchModel.clear()
    }
  }

  Overlay.modal: Rectangle {
    color: Qt.rgba(0, 0, 0, 0.45)
    Behavior on opacity { NumberAnimation { duration: 150 } }
  }

  // Timer to debounce remote server requests (~320ms) like Telegram Android
  Timer {
    id: remoteSearchTimer
    interval: 320
    repeat: false
    onTriggered: {
      var q = searchInput.text.trim()
      if (q.length > 0) {
        telegramClient.searchGlobal(q)
      }
    }
  }

  background: Item {
    // Outer drop shadow
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 4
      anchors.bottomMargin: -4
      anchors.leftMargin: -2
      anchors.rightMargin: -2
      radius: 18
      color: Qt.rgba(0, 0, 0, 0.35)
      z: -1
    }

    // Glass container
    Rectangle {
      id: searchContainer
      anchors.fill: parent
      radius: 16
      color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.96)
      border.color: Theme.divider
      border.width: 1
      clip: true

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 15
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
      }
    }
  }

  contentItem: ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // Search Input Header Bar
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 52
      color: "transparent"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        Image {
          source: "qrc:/qt/qml/Silkite/assets/icons/search.svg"
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          fillMode: Image.PreserveAspectFit
          layer.enabled: true
          layer.effect: ColorOverlay {
            color: searchInput.activeFocus ? Theme.accent : Theme.secondaryText
          }
        }

        TextField {
          id: searchInput
          Layout.fillWidth: true
          placeholderText: "Search chats, contacts, channels, @username..."
          placeholderTextColor: Theme.secondaryText
          color: Theme.primaryText
          font.pixelSize: 15
          selectByMouse: true
          focus: true
          background: Item {}

          onTextChanged: {
            var q = text.trim()
            if (root.searchModel) {
              root.searchModel.query = q
            }

            if (q.length === 0) {
              remoteSearchTimer.stop()
              if (root.searchModel) root.searchModel.clear()
              return
            }

            // Phase 1: Local Search immediately (0ms delay)
            telegramClient.searchLocal(q)

            // Phase 2: Global public entities search (debounced 320ms)
            remoteSearchTimer.restart()
          }

          Keys.onEscapePressed: root.close()
        }

        // Clear button
        Item {
          Layout.preferredWidth: 26
          Layout.preferredHeight: 26
          visible: searchInput.text.length > 0

          Rectangle {
            anchors.fill: parent
            radius: 13
            color: clearMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
          }

          Image {
            anchors.centerIn: parent
            source: "qrc:/qt/qml/Silkite/assets/icons/close.svg"
            width: 14
            height: 14
            sourceSize: Qt.size(14, 14)
            layer.enabled: true
            layer.effect: ColorOverlay {
              color: Theme.secondaryText
            }
          }

          MouseArea {
            id: clearMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: searchInput.clear()
          }
        }

        // Close ESC badge / button
        Rectangle {
          Layout.preferredHeight: 24
          Layout.preferredWidth: escLabel.implicitWidth + 14
          radius: 6
          color: escMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
          border.color: Theme.divider
          border.width: 1

          Label {
            id: escLabel
            anchors.centerIn: parent
            text: "ESC"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Theme.secondaryText
          }

          MouseArea {
            id: escMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }
      }

      // Header bottom hairline
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.divider
      }
    }

    // Result List / Empty State Area
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Empty query state
      ColumnLayout {
        anchors.centerIn: parent
        visible: searchInput.text.trim().length === 0
        spacing: 8

        Image {
          source: "qrc:/qt/qml/Silkite/assets/icons/search.svg"
          Layout.preferredWidth: 40
          Layout.preferredHeight: 40
          Layout.alignment: Qt.AlignHCenter
          opacity: 0.25
          layer.enabled: true
          layer.effect: ColorOverlay {
            color: Theme.secondaryText
          }
        }

        Label {
          text: "Global Search"
          color: Theme.primaryText
          font.pixelSize: 16
          font.bold: true
          Layout.alignment: Qt.AlignHCenter
        }

        Label {
          text: "Search for contacts, chats, public groups, channels or @username"
          color: Theme.secondaryText
          font.pixelSize: 13
          Layout.alignment: Qt.AlignHCenter
        }
      }

      // No results found state
      ColumnLayout {
        anchors.centerIn: parent
        visible: searchInput.text.trim().length > 0 && resultsListView.count === 0
        spacing: 6

        Label {
          text: "No results found"
          color: Theme.primaryText
          font.pixelSize: 15
          font.bold: true
          Layout.alignment: Qt.AlignHCenter
        }

        Label {
          text: "No chats or public channels matched \"" + searchInput.text.trim() + "\""
          color: Theme.secondaryText
          font.pixelSize: 13
          Layout.alignment: Qt.AlignHCenter
        }
      }

      // Search Results ListView
      ListView {
        id: resultsListView
        anchors.fill: parent
        anchors.margins: 6
        clip: true
        spacing: 4
        model: root.searchModel

        // Section headers
        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: Rectangle {
          width: resultsListView.width
          height: 30
          color: "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            Label {
              text: section === "local" ? "Chats and Contacts" : "Global Search Results"
              color: Theme.accent
              font.pixelSize: 12
              font.weight: Font.DemiBold
              Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Theme.divider
              opacity: 0.5
            }
          }
        }

        delegate: ItemDelegate {
          id: itemDelegate
          width: resultsListView.width
          height: 56
          padding: 0

          required property var model
          required property int index

          background: Rectangle {
            radius: 10
            color: itemDelegate.hovered ? Theme.controlBackground : "transparent"
            border.color: itemDelegate.hovered ? Theme.divider : "transparent"
            border.width: 1
          }

          contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            // Avatar
            Rectangle {
              Layout.preferredWidth: 38
              Layout.preferredHeight: 38
              radius: 19
              color: model.avatarColor ? model.avatarColor : "#526C8A"
              clip: true

              Image {
                anchors.fill: parent
                source: model.avatarPath ? "file://" + model.avatarPath : ""
                fillMode: Image.PreserveAspectCrop
                visible: model.avatarPath !== ""
              }

              Label {
                anchors.centerIn: parent
                text: model.initials ? model.initials : "?"
                color: "#FFFFFF"
                font.bold: true
                font.pixelSize: 14
                visible: !model.avatarPath || model.avatarPath === ""
              }
            }

            // Name and details
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Label {
                  text: model.name ? model.name : ""
                  color: Theme.primaryText
                  font.pixelSize: 14
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                // Entity type badge
                Rectangle {
                  Layout.preferredHeight: 18
                  Layout.preferredWidth: badgeLabel.implicitWidth + 10
                  radius: 4
                  visible: model.type !== "" && model.type !== "user"
                  color: model.type === "channel" ? Qt.rgba(41/255, 182/255, 246/255, 0.15)
                         : (model.type === "bot" ? Qt.rgba(255/255, 167/255, 38/255, 0.15)
                         : Qt.rgba(102/255, 187/255, 106/255, 0.15))
                  border.color: model.type === "channel" ? Qt.rgba(41/255, 182/255, 246/255, 0.4)
                                : (model.type === "bot" ? Qt.rgba(255/255, 167/255, 38/255, 0.4)
                                : Qt.rgba(102/255, 187/255, 106/255, 0.4))
                  border.width: 1

                  Label {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: model.type === "channel" ? "channel"
                          : (model.type === "bot" ? "bot"
                          : (model.type === "group" ? "group" : model.type))
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: model.type === "channel" ? "#29B6F6"
                           : (model.type === "bot" ? "#FFA726" : "#66BB6A")
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                  visible: model.username && model.username !== ""
                  text: "@" + model.username
                  color: Theme.accent
                  font.pixelSize: 12
                  elide: Text.ElideRight
                }

                Label {
                  Layout.fillWidth: true
                  text: model.subtitle ? model.subtitle : ""
                  color: Theme.secondaryText
                  font.pixelSize: 12
                  elide: Text.ElideRight
                }
              }
            }
          }

          onClicked: {
            if (model.chatId && model.chatId !== 0) {
              telegramClient.addRecentlyFoundChat(model.chatId)
              root.openChatRequested(model.chatId, 0)
            } else if (model.userId && model.userId !== 0) {
              root.openChatRequested(0, model.userId)
            }
            root.close()
          }
        }
      }
    }
  }
}
