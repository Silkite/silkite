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
)

qt_standard_project_setup(REQUIRES 6.5)

qt_policy(SET QTP0004 NEW)

qt_add_executable(silkite
  src/main.cpp
  src/app_controller.cpp
  src/app_controller.h

  src/models/chat_list_model.cpp
  src/models/chat_list_model.h
)

qt_add_qml_module(silkite
  URI Silkite
  VERSION 1.0

  QML_FILES
    src/qml/Main.qml
    src/qml/Sidebar.qml
    src/qml/ChatList.qml
    src/qml/ConversationPanel.qml
)

target_link_libraries(silkite
  PRIVATE
    Qt6::Quick
    Qt6::Qml
)
