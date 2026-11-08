cmake_minimum_required(VERSION 3.24)

project(Silkite
  VERSION 0.1.0
  LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 REQUIRED COMPONENTS
  Quick
  Qml
  QuickControls2
)

find_package(Td REQUIRED CONFIG
  PATHS "$ENV{HOME}/Projects/dependencies/td/tdlib/lib/cmake/Td"
  NO_DEFAULT_PATH
)

find_library(QRENCODE_LIBRARY qrencode REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

qt_policy(SET QTP0004 NEW)

qt_add_executable(silkite
  src/main.cpp
  src/app_controller.cpp
  src/app_controller.h
  src/theme/theme_manager.cpp
  src/theme/theme_manager.h

  src/models/chat_list_model.cpp
  src/models/chat_list_model.h
  src/models/contact_list_model.cpp
  src/models/contact_list_model.h
  src/models/chat_organization_manager.cpp
  src/models/chat_organization_manager.h
  src/models/message_list_model.cpp
  src/models/message_list_model.h

  src/telegram/telegram_client.cpp
  src/telegram/telegram_client.h
  src/telegram/telegram_worker.cpp
  src/telegram/telegram_worker.h

)

qt_add_qml_module(silkite
  URI Silkite
  VERSION 1.0

  QML_FILES
    src/qml/Main.qml
    src/qml/Sidebar.qml
    src/qml/ChatList.qml
    src/qml/ContactList.qml
    src/qml/NewContactDialog.qml
    src/qml/ContactProfileDialog.qml
    src/qml/ConversationPanel.qml
    src/qml/FolderBar.qml
    src/qml/NewFolderDialog.qml
    src/qml/ManageChatFoldersDialog.qml

  RESOURCES
    assets/logo-transparent.png
    assets/icons/chat.svg
    assets/icons/people.svg
    assets/icons/people-team.svg
    assets/icons/add.svg
    assets/icons/checkmark.svg
    assets/icons/arrow-left.svg
    assets/icons/call.svg
    assets/icons/video.svg
    assets/icons/settings.svg
    assets/icons/search.svg
    assets/icons/more.svg
    assets/icons/menu.svg
    assets/icons/block.svg
    assets/icons/delete.svg
    assets/icons/panel-left.svg
    assets/icons/split-pane.svg
    assets/icons/close.svg
    assets/icons/send.svg
    assets/icons/arrow-down.svg
    assets/icons/emoji.svg
    assets/icons/sticker.svg
    assets/icons/gif.svg
    assets/icons/attach.svg
    assets/fonts/Fredoka-Variable.ttf
    assets/fonts/Fredoka-OFL.txt
)

target_include_directories(silkite
    PRIVATE
        "$ENV{HOME}/Projects/dependencies/td/tdlib/include"
)

target_link_libraries(silkite
  PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Td::TdStatic
    ${QRENCODE_LIBRARY}
)
