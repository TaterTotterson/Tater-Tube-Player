cmake_minimum_required(VERSION 3.24)

project(TaterTubePlayer
    VERSION 0.3.0
    DESCRIPTION "A modern player for Tater Tube Server"
    LANGUAGES CXX
)

include(GNUInstallDirs)

option(TATER_STEAM_RELEASE
    "Apply the Steam/Linux release checks and packaging layout"
    OFF
)
option(TATER_DEPLOY_QT_RUNTIME
    "Deploy the shared Qt runtime and QML imports during installation"
    OFF
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

if(TATER_STEAM_RELEASE)
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
        message(FATAL_ERROR "TATER_STEAM_RELEASE may only be used for a Linux build")
    endif()
    if(NOT QT6_IS_SHARED_LIBS_BUILD)
        message(FATAL_ERROR
            "The Steam release must use dynamically linked Qt libraries for LGPLv3 compliance")
    endif()
endif()

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(tater-tube-player
    src/ArtworkNetworkAccessManagerFactory.cpp
    src/ArtworkNetworkAccessManagerFactory.h
    src/main.cpp
    src/GamepadInput.cpp
    src/GamepadInput.h
    src/PlaybackCapabilities.cpp
    src/PlaybackCapabilities.h
    src/ServerClient.cpp
    src/ServerClient.h
)

qt_add_qml_module(tater-tube-player
    URI TaterTube.Player
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/ViewingHistory.js
        qml/components/AmbientBackdrop.qml
        qml/components/FocusButton.qml
        qml/components/EpisodeCard.qml
        qml/components/DiscoveryCategoryCard.qml
        qml/components/FrostedGlass.qml
        qml/components/GuideProgramCard.qml
        qml/components/HorizontalMediaRow.qml
        qml/components/MediaCard.qml
        qml/components/PosterCard.qml
        qml/components/RecommendationHero.qml
        qml/components/SeasonCard.qml
        qml/components/SectionTitle.qml
    RESOURCES
        assets/demo/after-midnight.png
        assets/demo/cartoon-channel.png
        assets/demo/cosmic-drift.png
        assets/demo/cosmic-drift-poster.png
        assets/demo/creature-features.png
        assets/demo/harbor-street.png
        assets/demo/neon-nights.png
        assets/demo/northern-lights.png
        assets/demo/orange-county-skies.png
        assets/demo/the-long-winter.png
        assets/discovery/featured-movies.png
        assets/discovery/featured-tv.png
        assets/discovery/new-movies.png
        assets/discovery/new-tv.png
        assets/discovery/popular-movies.png
        assets/discovery/popular-tv.png
        assets/mascot/tater-front.png
        assets/mascot/tater-hero-remote.png
        assets/mascot/tater-salute.png
        assets/mascot/tater-wave.png
        assets/tater-scanlines.png
        assets/tater-tube-logo-leaning-transparent.png
        assets/ui/tater-orange-glow.png
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
    INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}"
)

install(TARGETS tater-tube-player
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES
    LICENSE
    NOTICE
    PRIVACY.md
    THIRD_PARTY_NOTICES.md
    TRADEMARKS.md
    docs/RELINKING_QT.md
    docs/SOURCE_CODE.md
    DESTINATION licenses
)

install(DIRECTORY packaging/licenses/
    DESTINATION licenses
)

if(UNIX AND NOT APPLE)
    install(PROGRAMS packaging/linux/tater-tube-player-launcher.sh
        DESTINATION .
        RENAME tater-tube-player
    )
    install(FILES packaging/linux/com.taterassistant.TaterTubePlayer.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
    )
    install(FILES store/steam/graphics/client/shortcut-icon-256.png
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps
        RENAME com.taterassistant.TaterTubePlayer.png
    )
endif()

if(TATER_DEPLOY_QT_RUNTIME)
    qt_generate_deploy_qml_app_script(
        TARGET tater-tube-player
        OUTPUT_SCRIPT tater_deploy_qt_script
        NO_TRANSLATIONS
        EXCLUDE_PLUGIN_TYPES
            platformthemes
            qmltooling
    )
    install(SCRIPT ${tater_deploy_qt_script})
endif()

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

    qt_add_executable(playback-capabilities-test
        tests/PlaybackCapabilitiesTest.cpp
        src/PlaybackCapabilities.cpp
        src/PlaybackCapabilities.h
    )
    target_include_directories(playback-capabilities-test PRIVATE src)
    target_link_libraries(playback-capabilities-test PRIVATE
        Qt6::Core Qt6::Gui Qt6::Multimedia Qt6::Test
    )
    add_test(NAME playback-capabilities-test COMMAND playback-capabilities-test)

    qt_add_executable(artwork-network-cache-test
        tests/ArtworkNetworkCacheTest.cpp
        src/ArtworkNetworkAccessManagerFactory.cpp
        src/ArtworkNetworkAccessManagerFactory.h
    )
    target_include_directories(artwork-network-cache-test PRIVATE src)
    target_link_libraries(artwork-network-cache-test PRIVATE
        Qt6::Core Qt6::Network Qt6::Qml Qt6::Test
    )
    add_test(NAME artwork-network-cache-test COMMAND artwork-network-cache-test)

    qt_add_executable(viewing-history-test tests/ViewingHistoryTest.cpp)
    target_compile_definitions(viewing-history-test PRIVATE
        TATER_PLAYER_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml"
    )
    target_link_libraries(viewing-history-test PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    add_test(NAME viewing-history-test COMMAND viewing-history-test)
endif()
