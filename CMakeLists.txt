cmake_minimum_required(VERSION 3.24)

project(TaterTubePlayer
    VERSION 0.3.19
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
    set(TATER_MPV_RELEASE_ROOT "/opt/tater-mpv" CACHE PATH
        "Root of the audited LGPL-only mpv release")
    set(TATER_MPV_EXECUTABLE "${TATER_MPV_RELEASE_ROOT}/bin/mpv" CACHE FILEPATH
        "Audited LGPL-only mpv executable")
    set(TATER_MEDIA_RELEASE_ROOT "/opt/tater-media" CACHE PATH
        "Root of the audited LGPL-only FFmpeg release")
    set(TATER_MPV_BUILD_OPTIONS
        "${TATER_MPV_RELEASE_ROOT}/share/tater/mpv-build-options.txt")
    set(TATER_MPV_COPYRIGHT
        "${TATER_MPV_RELEASE_ROOT}/share/licenses/mpv/Copyright")
    set(TATER_MPV_LICENSE
        "${TATER_MPV_RELEASE_ROOT}/share/licenses/mpv/LICENSE.LGPL")
    set(TATER_MPV_LIBASS
        "${TATER_MPV_RELEASE_ROOT}/lib/libass.so.9")
    set(TATER_MPV_LIBPLACEBO
        "${TATER_MPV_RELEASE_ROOT}/lib/libplacebo.so.349")
    set(TATER_MPV_LIBJPEG
        "${TATER_MPV_RELEASE_ROOT}/lib/libjpeg.so.62")
    set(TATER_MPV_LIBLCMS2
        "${TATER_MPV_RELEASE_ROOT}/lib/liblcms2.so.2")
    set(TATER_MPV_LIBUNIBREAK
        "${TATER_MPV_RELEASE_ROOT}/lib/libunibreak.so.6")
    set(TATER_MPV_LIBDISPLAY_INFO
        "${TATER_MPV_RELEASE_ROOT}/lib/libdisplay-info.so.2")
    set(TATER_MPV_LIBASS_COPYRIGHT
        "${TATER_MPV_RELEASE_ROOT}/share/licenses/runtime/libass-copyright")
    set(TATER_MPV_LIBPLACEBO_COPYRIGHT
        "${TATER_MPV_RELEASE_ROOT}/share/licenses/runtime/libplacebo-copyright")
    set(TATER_MPV_LIBJPEG_COPYRIGHT
        "${TATER_MPV_RELEASE_ROOT}/share/licenses/runtime/libjpeg-turbo-copyright")
    set(TATER_MPV_LIBLCMS2_COPYRIGHT
        "${TATER_MPV_RELEASE_ROOT}/share/licenses/runtime/liblcms2-copyright")
    set(TATER_MPV_LIBUNIBREAK_COPYRIGHT
        "${TATER_MPV_RELEASE_ROOT}/share/licenses/runtime/libunibreak-copyright")
    set(TATER_MPV_LIBDISPLAY_INFO_COPYRIGHT
        "${TATER_MPV_RELEASE_ROOT}/share/licenses/runtime/libdisplay-info-copyright")
    foreach(tater_required_release_file IN ITEMS
            "${TATER_MPV_EXECUTABLE}" "${TATER_MPV_BUILD_OPTIONS}" "${TATER_MPV_COPYRIGHT}"
            "${TATER_MPV_LICENSE}" "${TATER_MPV_LIBASS}"
            "${TATER_MPV_LIBPLACEBO}" "${TATER_MPV_LIBJPEG}"
            "${TATER_MPV_LIBLCMS2}" "${TATER_MPV_LIBUNIBREAK}"
            "${TATER_MPV_LIBDISPLAY_INFO}"
            "${TATER_MPV_LIBASS_COPYRIGHT}"
            "${TATER_MPV_LIBPLACEBO_COPYRIGHT}"
            "${TATER_MPV_LIBJPEG_COPYRIGHT}"
            "${TATER_MPV_LIBLCMS2_COPYRIGHT}"
            "${TATER_MPV_LIBUNIBREAK_COPYRIGHT}"
            "${TATER_MPV_LIBDISPLAY_INFO_COPYRIGHT}"
            "${TATER_MEDIA_RELEASE_ROOT}/ffmpeg-build-config.txt")
        if(NOT EXISTS "${tater_required_release_file}")
            message(FATAL_ERROR
                "The audited LGPL playback release file is missing: ${tater_required_release_file}")
        endif()
    endforeach()
    file(READ "${TATER_MPV_BUILD_OPTIONS}" tater_mpv_build_options_text)
    if(NOT tater_mpv_build_options_text MATCHES "gpl[ ]+false")
        message(FATAL_ERROR "The bundled mpv executable was not built with -Dgpl=false")
    endif()
endif()

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(tater-tube-player
    src/ArtworkNetworkAccessManagerFactory.cpp
    src/ArtworkNetworkAccessManagerFactory.h
    src/MpvProcessPlayer.cpp
    src/MpvProcessPlayer.h
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
        qml/Navigation.js
        qml/ViewingHistory.js
        qml/components/AmbientBackdrop.qml
        qml/components/FocusButton.qml
        qml/components/EpisodeCard.qml
        qml/components/DiscoveryCategoryCard.qml
        qml/components/DiscoveryResultRow.qml
        qml/components/FrostedGlass.qml
        qml/components/GuideProgramCard.qml
        qml/components/HorizontalMediaRow.qml
        qml/components/MediaCard.qml
        qml/components/PosterCard.qml
        qml/components/RecommendationHero.qml
        qml/components/RowActionCard.qml
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

if(TATER_STEAM_RELEASE)
    # Keep the audited LGPL-only mpv build as a separate, replaceable program.
    install(PROGRAMS "${TATER_MPV_EXECUTABLE}"
        DESTINATION ${CMAKE_INSTALL_BINDIR}
        RENAME tater-mpv
    )
    install(FILES "${TATER_MPV_COPYRIGHT}"
        DESTINATION licenses
        RENAME mpv-Copyright.txt
    )
    install(FILES "${TATER_MPV_LICENSE}"
        DESTINATION licenses
        RENAME mpv-LGPL-2.1-or-later.txt
    )
    install(FILES "${TATER_MPV_LIBASS}" "${TATER_MPV_LIBPLACEBO}"
                  "${TATER_MPV_LIBJPEG}" "${TATER_MPV_LIBLCMS2}"
                  "${TATER_MPV_LIBUNIBREAK}" "${TATER_MPV_LIBDISPLAY_INFO}"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )
    install(FILES "${TATER_MPV_LIBASS_COPYRIGHT}"
        DESTINATION licenses
        RENAME libass-Copyright.txt
    )
    install(FILES "${TATER_MPV_LIBPLACEBO_COPYRIGHT}"
        DESTINATION licenses
        RENAME libplacebo-Copyright.txt
    )
    install(FILES "${TATER_MPV_LIBJPEG_COPYRIGHT}"
        DESTINATION licenses
        RENAME libjpeg-turbo-Copyright.txt
    )
    install(FILES "${TATER_MPV_LIBLCMS2_COPYRIGHT}"
        DESTINATION licenses
        RENAME liblcms2-Copyright.txt
    )
    install(FILES "${TATER_MPV_LIBUNIBREAK_COPYRIGHT}"
        DESTINATION licenses
        RENAME libunibreak-Copyright.txt
    )
    install(FILES "${TATER_MPV_LIBDISPLAY_INFO_COPYRIGHT}"
        DESTINATION licenses
        RENAME libdisplay-info-Copyright.txt
    )
    install(FILES
        "${TATER_MPV_BUILD_OPTIONS}"
        "${TATER_MEDIA_RELEASE_ROOT}/ffmpeg-build-config.txt"
        DESTINATION compliance
    )
endif()

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

if(TATER_STEAM_RELEASE)
    # Replace Qt's smaller FFmpeg runtime with the single audited LGPL-only
    # FFmpeg build used by both Qt Multimedia and mpv, and add libavfilter.
    install(DIRECTORY "${TATER_MEDIA_RELEASE_ROOT}/lib/"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}
        FILES_MATCHING
            PATTERN "libavcodec.so*"
            PATTERN "libavfilter.so*"
            PATTERN "libavformat.so*"
            PATTERN "libavutil.so*"
            PATTERN "libswresample.so*"
            PATTERN "libswscale.so*"
    )
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

    qt_add_executable(mpv-process-player-test
        tests/MpvProcessPlayerTest.cpp
        src/MpvProcessPlayer.cpp
        src/MpvProcessPlayer.h
    )
    target_include_directories(mpv-process-player-test PRIVATE src)
    target_link_libraries(mpv-process-player-test PRIVATE
        Qt6::Core Qt6::Network Qt6::Test
    )
    add_test(NAME mpv-process-player-test COMMAND mpv-process-player-test)

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
