import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
  id: root

  property string selectedCategory: "account"
  property string selectedSection: "profile_info"
  property bool pointerInside: false

  signal categorySelected(string category)
  signal sectionSelected(string category, string section)

  readonly property bool compactMode: width < 140

  // Outer soft ambient elevation shadow
  Rectangle {
    anchors.fill: glassBody
    anchors.topMargin: 2
    anchors.bottomMargin: -2
    anchors.leftMargin: -1
    anchors.rightMargin: -1
    radius: glassBody.radius + 1
    color: Qt.rgba(0, 0, 0, 0.18)
    z: -1
  }

  // Liquid glass background container
  Rectangle {
    id: glassBody
    anchors.fill: parent
    radius: 18
    color: Qt.rgba(Theme.panelBackground.r, Theme.panelBackground.g, Theme.panelBackground.b, 0.75)
    border.color: Theme.divider
    border.width: 1

    // Inner subtle border highlight
    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: 17
      color: "transparent"
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1
    }
  }

  HoverHandler {
    onHoveredChanged: root.pointerInside = hovered
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: root.compactMode ? 6 : 14
    anchors.rightMargin: root.compactMode ? 6 : 14
    anchors.topMargin: 14
    anchors.bottomMargin: 14
    spacing: root.compactMode ? 8 : 12

    // Header Title
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 32
      spacing: 6

      Label {
        text: "Settings"
        font.pixelSize: Theme.uiFontSize + 9
        font.bold: true
        color: Theme.primaryText
        visible: !root.compactMode
        Layout.fillWidth: true
        elide: Text.ElideRight
      }

      Image {
        visible: root.compactMode
        Layout.alignment: Qt.AlignHCenter
        source: "qrc:/qt/qml/Silkite/assets/icons/settings.svg"
        sourceSize.width: 22
        sourceSize.height: 22
      }
    }

    // Category & Sub-sections Accordion List
    ListView {
      id: categoryListView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: 4

      model: [
        {
          id: "account",
          name: "Account & Profile",
          icon: "qrc:/qt/qml/Silkite/assets/icons/person.svg",
          sections: [
            { id: "profile_card", name: "Profile info" },
            { id: "edit_details", name: "Edit details" },
            { id: "account_actions", name: "Account actions" }
          ]
        },
        {
          id: "appearance",
          name: "Appearance",
          icon: "qrc:/qt/qml/Silkite/assets/icons/paint-brush.svg",
          sections: [
            { id: "themes_section", name: "Themes" },
            { id: "irc_mode_section", name: "IRC Mode" },
            { id: "font_sizes_section", name: "Font Sizes" },
            { id: "chat_spacing_section", name: "Chat Spacing" }
          ]
        },
        {
          id: "privacy",
          name: "Privacy & Security",
          icon: "qrc:/qt/qml/Silkite/assets/icons/shield.svg",
          sections: [
            { id: "two_step_section", name: "Two-step verification" },
            { id: "sessions_section", name: "Active sessions" },
            { id: "visibility_section", name: "Visibility & online" }
          ]
        },
        {
          id: "notifications",
          name: "Notifications & Sounds",
          icon: "qrc:/qt/qml/Silkite/assets/icons/notification.svg",
          sections: [
            { id: "chat_alerts_section", name: "Chat notifications" },
            { id: "sounds_section", name: "Sound effects" }
          ]
        },
        {
          id: "data_storage",
          name: "Data & Storage",
          icon: "qrc:/qt/qml/Silkite/assets/icons/storage.svg",
          sections: [
            { id: "auto_download_section", name: "Media auto-download" },
            { id: "cache_section", name: "Cache storage" }
          ]
        },
        {
          id: "chat_folders",
          name: "Chat Folders",
          icon: "qrc:/qt/qml/Silkite/assets/icons/folder.svg",
          sections: [
            { id: "folders_list_section", name: "Manage folders" },
            { id: "create_folder_section", name: "Create folder" }
          ]
        },
        {
          id: "language",
          name: "Language",
          icon: "qrc:/qt/qml/Silkite/assets/icons/language.svg",
          sections: [
            { id: "interface_lang_section", name: "Interface language" }
          ]
        },
        {
          id: "about",
          name: "About Silkite",
          icon: "qrc:/qt/qml/Silkite/assets/icons/about.svg",
          sections: [
            { id: "about_silkite_section", name: "Silkite client" },
            { id: "libraries_section", name: "Components & TDLib" }
          ]
        }
      ]

      delegate: Item {
        id: categoryItemRoot
        width: categoryListView.width

        readonly property var catData: modelData
        readonly property bool isSelected: root.selectedCategory === catData.id
        readonly property bool isExpanded: isSelected && !root.compactMode

        implicitHeight: headerButton.height + (isExpanded ? subSectionsColumn.height + 6 : 0)

        Behavior on implicitHeight {
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Header Category Button
        Rectangle {
          id: headerButton
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: root.compactMode ? 42 : 46
          radius: 12
          color: isSelected
                 ? Theme.controlBackground
                 : (mouseArea.containsMouse ? Qt.rgba(Theme.controlBackground.r, Theme.controlBackground.g, Theme.controlBackground.b, 0.45) : "transparent")
          border.color: isSelected ? Theme.accent : "transparent"
          border.width: 1

          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.compactMode ? 0 : 12
            anchors.rightMargin: root.compactMode ? 0 : 12
            spacing: 12

            Item {
              Layout.alignment: root.compactMode ? Qt.AlignHCenter : Qt.AlignVCenter
              Layout.preferredWidth: 26
              Layout.preferredHeight: 26

              Image {
                id: itemIcon
                anchors.centerIn: parent
                source: catData.icon
                sourceSize.width: 20
                sourceSize.height: 20
                smooth: true
                visible: false
              }

              ColorOverlay {
                anchors.fill: itemIcon
                source: itemIcon
                color: isSelected ? Theme.accent : Theme.primaryText
              }
            }

            Label {
              text: catData.name
              color: isSelected ? Theme.accent : Theme.primaryText
              font.pixelSize: Theme.uiFontSize
              font.weight: isSelected ? Font.DemiBold : Font.Normal
              visible: !root.compactMode
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            // Expand / Collapse Chevron indicator
            Item {
              visible: !root.compactMode && catData.sections && catData.sections.length > 0
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16

              Image {
                id: chevronIcon
                anchors.centerIn: parent
                source: "qrc:/qt/qml/Silkite/assets/icons/chevron-down.svg"
                sourceSize.width: 14
                sourceSize.height: 14
                smooth: true
                rotation: isExpanded ? 180 : 0
                visible: false

                Behavior on rotation {
                  NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
              }

              ColorOverlay {
                anchors.fill: chevronIcon
                source: chevronIcon
                color: isSelected ? Theme.accent : Theme.secondaryText
                rotation: chevronIcon.rotation
              }
            }
          }

          ToolTip.visible: root.compactMode && mouseArea.containsMouse
          ToolTip.text: catData.name
          ToolTip.delay: 300

          MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.categorySelected(catData.id)
              if (catData.sections && catData.sections.length > 0) {
                root.sectionSelected(catData.id, catData.sections[0].id)
              }
            }
          }
        }

        // Sub-sections accordion branch with vertical guide line
        Item {
          id: subSectionsColumn
          anchors.top: headerButton.bottom
          anchors.topMargin: 4
          anchors.left: parent.left
          anchors.right: parent.right
          height: sectionsLayout.implicitHeight
          clip: true
          opacity: isExpanded ? 1.0 : 0.0
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation { duration: 180 }
          }

          // Vertical guide line for the nested tree branch
          Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            width: 2
            radius: 1
            color: Qt.rgba(Theme.divider.r, Theme.divider.g, Theme.divider.b, 0.4)
          }

          ColumnLayout {
            id: sectionsLayout
            anchors.fill: parent
            anchors.leftMargin: 36
            anchors.rightMargin: 4
            spacing: 2

            Repeater {
              model: catData.sections || []
              delegate: Rectangle {
                id: sectionItem
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 8

                readonly property bool isSecActive: isSelected && (root.selectedSection === modelData.id)

                color: isSecActive
                       ? Theme.controlBackground
                       : (secMouse.containsMouse ? Qt.rgba(Theme.controlBackground.r, Theme.controlBackground.g, Theme.controlBackground.b, 0.35) : "transparent")

                Behavior on color { ColorAnimation { duration: 140 } }

                // Small active accent indicator dot on left
                Rectangle {
                  anchors.left: parent.left
                  anchors.leftMargin: 4
                  anchors.verticalCenter: parent.verticalCenter
                  width: 4
                  height: 4
                  radius: 2
                  color: Theme.accent
                  visible: isSecActive
                }

                Label {
                  anchors.fill: parent
                  anchors.leftMargin: isSecActive ? 14 : 8
                  anchors.rightMargin: 8
                  text: modelData.name
                  color: isSecActive ? Theme.primaryText : Theme.secondaryText
                  font.pixelSize: Math.max(9, Theme.uiFontSize - 1)
                  font.weight: isSecActive ? Font.DemiBold : Font.Normal
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight

                  Behavior on anchors.leftMargin {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                  }
                  Behavior on color {
                    ColorAnimation { duration: 140 }
                  }
                }

                MouseArea {
                  id: secMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedCategory = catData.id
                    root.selectedSection = modelData.id
                    root.sectionSelected(catData.id, modelData.id)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
