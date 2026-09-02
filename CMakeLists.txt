cmake_minimum_required(VERSION 3.24)

project(TaterTubePlayer
    VERSION 0.1.0
    DESCRIPTION "A modern player for Tater Tube Server"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core
    Gui
    Network
    Qml
    Quick
    QuickControls2
)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(tater-tube-player
    src/main.cpp
    src/ServerClient.cpp
    src/ServerClient.h
)

qt_add_qml_module(tater-tube-player
    URI TaterTube.Player
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/FocusButton.qml
        qml/components/MediaCard.qml
        qml/components/PosterCard.qml
        qml/components/SectionTitle.qml
    RESOURCES
        assets/mascot/tater-front.png
        assets/mascot/tater-salute.png
        assets/mascot/tater-wave.png
)

target_link_libraries(tater-tube-player PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

target_compile_definitions(tater-tube-player PRIVATE
    TATER_TUBE_PLAYER_VERSION="${PROJECT_VERSION}"
)

set_target_properties(tater-tube-player PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "Tater Tube Player"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.taterassistant.tatertubeplayer"
    WIN32_EXECUTABLE TRUE
)

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Test)
    qt_add_executable(server-client-test
        tests/ServerClientTest.cpp
        src/ServerClient.cpp
        src/ServerClient.h
    )
    target_include_directories(server-client-test PRIVATE src)
    target_link_libraries(server-client-test PRIVATE Qt6::Core Qt6::Network Qt6::Test)
    add_test(NAME server-client-test COMMAND server-client-test)
endif()
