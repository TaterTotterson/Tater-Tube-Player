cmake_minimum_required(VERSION 3.24)

project(TaterTubePlayer
    VERSION 0.3.0
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
    Multimedia
    Network
    Qml
    Quick
    QuickControls2
)
find_package(SDL2 CONFIG QUIET)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(tater-tube-player
    src/main.cpp
    src/GamepadInput.cpp
    src/GamepadInput.h
    src/PlaybackCapabilities.cpp
    src/PlaybackCapabilities.h
    src/ServerClient.cpp
    src/ServerClient.h
)

set_source_files_properties(qml/components/UiSounds.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(tater-tube-player
    URI TaterTube.Player
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/FocusButton.qml
        qml/components/EpisodeCard.qml
        qml/components/GuideProgramCard.qml
        qml/components/MediaCard.qml
        qml/components/PosterCard.qml
        qml/components/SeasonCard.qml
        qml/components/SectionTitle.qml
        qml/components/UiSounds.qml
    RESOURCES
        assets/mascot/tater-front.png
        assets/mascot/tater-hero-remote.png
        assets/mascot/tater-salute.png
        assets/mascot/tater-wave.png
        assets/tater-scanlines.png
        assets/tater-tube-logo-leaning-transparent.png
        assets/sounds/tater-alert.wav
        assets/sounds/tater-back.wav
        assets/sounds/tater-select.wav
        assets/sounds/tater-step.wav
)

target_link_libraries(tater-tube-player PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Multimedia
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

if(SDL2_FOUND)
    target_link_libraries(tater-tube-player PRIVATE SDL2::SDL2)
    target_compile_definitions(tater-tube-player PRIVATE TATER_PLAYER_HAS_SDL2=1)
endif()

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
