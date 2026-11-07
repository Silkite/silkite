import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  property var organizationManager: chatOrganizationManager
  property var chatModel: chatListModel
  property var selectedChatId: 0

  signal createFolderRequested()

  implicitHeight: contentColumn.implicitHeight

  Connections {
    target: root.organizationManager
    function onFolderCreated(folderId) {
      Qt.callLater(function() {
        if (folderListView.count > 0) {
          var targetIndex = folderListView.count - 1
          folderListView.positionViewAtIndex(targetIndex, ListView.End)
          var maxX = Math.max(0, folderListView.contentWidth - folderListView.width)
          scrollAnim.stop()
          scrollAnim.from = folderListView.contentX
          scrollAnim.to = maxX
          scrollAnim.start()
        }
      })
    }
  }

  ColumnLayout {
    id: contentColumn
    anchors.fill: parent
    spacing: 8

    // Row with "New Folder" action button and quick stats
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Button {
        id: newFolderBtn
        Layout.fillWidth: true
        Layout.preferredHeight: 32

        background: Rectangle {
          radius: 10
          color: newFolderBtn.down 
                 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                 : (newFolderBtn.hovered 
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                    : Theme.controlBackground)
          border.color: newFolderBtn.hovered ? Theme.accent : Theme.divider
          border.width: 1

          Behavior on color { ColorAnimation { duration: 150 } }
        }

        contentItem: RowLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            text: "+"
            font.pixelSize: 16
            font.bold: true
            color: Theme.accent
          }

          Label {
            text: "New Folder"
            font.pixelSize: 12
            font.bold: true
            color: Theme.primaryText
          }
        }

        onClicked: root.createFolderRequested()
      }
    }

    // Horizontal Scrollable Folder Pills
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 34
      clip: true

      ListView {
        id: folderListView
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: 6
        model: root.organizationManager
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        NumberAnimation {
          id: scrollAnim
          target: folderListView
          property: "contentX"
          duration: 180
          easing.type: Easing.OutQuad
        }

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            // Smooth multiplier per wheel tick
            var step = delta * 1.5
            var startX = scrollAnim.running ? scrollAnim.to : folderListView.contentX
            var targetX = startX - step
            var maxX = Math.max(0, folderListView.contentWidth - folderListView.width)
            var clampedX = Math.max(0, Math.min(targetX, maxX))

            scrollAnim.stop()
            scrollAnim.from = folderListView.contentX
            scrollAnim.to = clampedX
            scrollAnim.start()
          }
        }

        delegate: ItemDelegate {
          id: folderDelegate

          required property string folderId
          required property string name
          required property string folderIcon
          required property int chatCount
          required property bool isActive

          height: 32
          implicitWidth: folderContent.implicitWidth + 20

          background: Rectangle {
            radius: 16
            color: folderDelegate.isActive
                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.9)
                   : (folderDelegate.hovered ? Theme.controlBackground : "transparent")
            border.color: folderDelegate.isActive
                          ? Qt.rgba(1, 1, 1, 0.3)
                          : (folderDelegate.hovered ? Theme.divider : Qt.rgba(Theme.divider.r, Theme.divider.g, Theme.divider.b, 0.4))
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
          }

          contentItem: RowLayout {
            id: folderContent
            spacing: 5
            anchors.centerIn: parent

            Text {
              text: folderDelegate.folderIcon
              font.pixelSize: 13
            }

            Label {
              text: folderDelegate.name
              font.pixelSize: 12
              font.bold: folderDelegate.isActive
              color: folderDelegate.isActive ? Theme.accentText : Theme.primaryText
            }

            // Chat count indicator for custom folders
            Rectangle {
              visible: folderDelegate.folderId !== "all" && folderDelegate.chatCount > 0
              Layout.preferredWidth: Math.max(16, countLabel.implicitWidth + 6)
              Layout.preferredHeight: 16
              radius: 8
              color: folderDelegate.isActive 
                     ? Qt.rgba(0, 0, 0, 0.25) 
                     : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)

              Label {
                id: countLabel
                anchors.centerIn: parent
                text: folderDelegate.chatCount.toString()
                font.pixelSize: 9
                font.bold: true
                color: folderDelegate.isActive ? Theme.accentText : Theme.accent
              }
            }
          }

          onClicked: {
            root.organizationManager.setActiveFolderId(folderDelegate.folderId)
          }

          // Right click context menu for editing or deleting folder
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: {
              if (folderDelegate.folderId !== "all") {
                folderContextMenu.targetFolderId = folderDelegate.folderId
                folderContextMenu.targetFolderName = folderDelegate.name
                folderContextMenu.targetFolderIcon = folderDelegate.folderIcon
                folderContextMenu.popup()
              }
            }
          }
        }
      }
    }
  }

  // Folder Context Menu
  Menu {
    id: folderContextMenu
    property string targetFolderId: ""
    property string targetFolderName: ""
    property string targetFolderIcon: ""

    background: Item {
      implicitWidth: 150
      Rectangle {
        anchors.fill: folderMenuGlass
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: folderMenuGlass.radius + 1
        color: Qt.rgba(0, 0, 0, 0.22)
        z: -1
      }
      Rectangle {
        id: folderMenuGlass
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
          border.color: Qt.rgba(1, 1, 1, 0.08)
          border.width: 1
        }
      }
    }

    MenuItem {
      text: "Delete Folder"
      contentItem: Text {
        text: parent.text
        color: Theme.accentText
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        leftPadding: 12
        rightPadding: 12
      }
      background: Rectangle {
        color: parent.highlighted ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"
        radius: 8
      }
      onTriggered: {
        root.organizationManager.deleteFolder(folderContextMenu.targetFolderId)
      }
    }
  }
}
