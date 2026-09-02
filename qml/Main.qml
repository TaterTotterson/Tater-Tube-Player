import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: root

    width: 1600
    height: 900
    minimumWidth: 1180
    minimumHeight: 720
    visible: true
    title: "Tater Tube Player"
    color: "#101215"

    readonly property color orange: "#ff781f"
    readonly property color orangeBright: "#ff964f"
    readonly property color panel: "#202328"
    readonly property color panelSoft: "#282c31"
    readonly property color textPrimary: "#f6f6f3"
    readonly property color textSecondary: "#aaafb4"

    function itemTitle(item, fallback) {
        return item && item.title ? item.title : fallback
    }

    function mediaLabel(item) {
        if (!item)
            return "MEDIA"
        var value = item.mediaType || item.type || "media"
        return String(value).toUpperCase()
    }

    function continueSubtitle(item) {
        if (!item)
            return ""
        if (item.sizeText)
            return item.sizeText
        if (item.durationDisplay)
            return "Resume • " + item.durationDisplay
        return "Resume playback"
    }

    function itemMeta(item) {
        if (!item)
            return ""
        var parts = []
        if (item.date)
            parts.push(item.date)
        if (item.category)
            parts.push(item.category)
        else if (item.sizeText)
            parts.push(item.sizeText)
        return parts.join("  •  ")
    }

    function progressValue(value) {
        var number = Number(value || 0) / 100.0
        return Math.max(0, Math.min(1, number))
    }

    function cardAccent(index) {
        var colors = ["#ef7423", "#547d8b", "#bd633d", "#6b5b7d", "#75864b", "#805a3d"]
        return colors[index % colors.length]
    }

    function channelNow(channel) {
        return channel && channel.now ? channel.now : null
    }

    function channelTitle(channel) {
        var now = channelNow(channel)
        return now && now.title ? now.title : itemTitle(channel, "Live channel")
    }

    function channelSubtitle(channel) {
        if (channel && channel.next && channel.next.title)
            return "Up next: " + channel.next.title
        return itemTitle(channel, "Tater Tube")
    }

    function taterLiveMessage() {
        if (serverClient.liveChannels.length === 0)
            return "Your channels are ready whenever you are."
        var channel = serverClient.liveChannels[0]
        if (channel.next && channel.next.title)
            return channel.next.title + " is coming up on channel " + channel.number + "."
        return channelTitle(channel) + " is live now on channel " + channel.number + "."
    }

    Component.onCompleted: homeNav.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: root.color

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#171a1e" }
            GradientStop { position: 0.52; color: "#111316" }
            GradientStop { position: 1.0; color: "#0c0e10" }
        }
    }

    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 86
        color: "#e917191d"
        border.width: 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#31353a"
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            spacing: 13

            Rectangle {
                width: 48
                height: 48
                radius: 16
                color: "#241b16"
                border.width: 1
                border.color: "#70401f"

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: "../assets/mascot/tater-wave.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2

                Text {
                    text: "TATER TUBE PLAYER"
                    color: root.textPrimary
                    font.pixelSize: 21
                    font.weight: Font.Black
                    font.letterSpacing: 1.3
                }

                Text {
                    text: "YOUR MEDIA, YOUR CHANNELS"
                    color: root.orange
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.15
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            FocusButton {
                id: homeNav
                text: "Home"
                compact: true
                selected: true
            }
            FocusButton { text: "Library"; compact: true }
            FocusButton { text: "Live TV"; compact: true }
            FocusButton { text: "Search"; compact: true }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            width: statusRow.implicitWidth + 26
            height: 38
            radius: 13
            color: "#202429"
            border.width: 1
            border.color: "#3c4147"

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 9

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9
                    height: 9
                    radius: 5
                    color: demoMode || serverClient.online ? "#73d68a" : "#71767c"
                }

                Text {
                    text: demoMode ? "DEMO LIBRARY"
                                   : (serverClient.online ? "SERVER ONLINE" : "SERVER OFFLINE")
                    color: "#d9dbdc"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                }
            }
        }
    }

    Flickable {
        id: page
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        contentHeight: contentColumn.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            background: Item {}
            contentItem: Rectangle { radius: 2; color: "#70575c61" }
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 46
            anchors.rightMargin: 46
            anchors.top: parent.top
            anchors.topMargin: 30
            spacing: 28

            Rectangle {
                id: hero
                width: contentColumn.width
                height: 304
                radius: 28
                clip: true
                color: root.panel
                border.width: 1
                border.color: "#3b3f44"

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#2c1b11" }
                    GradientStop { position: 0.52; color: "#24272c" }
                    GradientStop { position: 1.0; color: "#171a1e" }
                }

                Rectangle {
                    width: 520
                    height: 520
                    radius: 260
                    anchors.right: parent.right
                    anchors.rightMargin: -95
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#12ff781f"
                    border.width: 74
                    border.color: "#13ff8a3d"
                }

                Rectangle {
                    width: 280
                    height: 280
                    radius: 140
                    anchors.right: parent.right
                    anchors.rightMargin: 120
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#1617191d"
                    border.width: 1
                    border.color: "#3aff9a58"
                }

                Image {
                    anchors.right: parent.right
                    anchors.rightMargin: 82
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -17
                    width: 330
                    height: 330
                    source: "../assets/mascot/tater-salute.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(720, parent.width - 480)
                    spacing: 13

                    Row {
                        spacing: 10

                        Rectangle {
                            width: 9
                            height: 9
                            radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.orange
                        }

                        Text {
                            text: "TATER'S PICK FOR TONIGHT"
                            color: root.orangeBright
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                        }
                    }

                    Text {
                        text: "Everything good,\nright where you left it."
                        color: root.textPrimary
                        font.pixelSize: 38
                        font.weight: Font.Black
                        lineHeight: 0.94
                    }

                    Text {
                        width: parent.width
                        text: "Movies, shows, and your own live channels—served privately from Tater Tube Server."
                        color: "#c4c6c8"
                        font.pixelSize: 16
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        topPadding: 7
                        spacing: 12

                        FocusButton { text: "▶  Watch live"; primary: true }
                        FocusButton { text: "Browse library" }
                    }
                }
            }

            Rectangle {
                visible: !demoMode && serverClient.homeReady
                         && serverClient.homeWarnings.length > 0
                width: contentColumn.width
                height: 48
                radius: 14
                color: "#28231f"
                border.width: 1
                border.color: "#65462f"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tater Tube Server: " + serverClient.homeWarnings[0]
                    color: "#e4c4ab"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: demoMode

                SectionTitle {
                    width: parent.width
                    title: "Continue watching"
                    actionText: "SEE ALL  ›"
                }

                Row {
                    width: parent.width
                    spacing: 15

                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "MOVIE  •  42 MIN LEFT"
                        title: "The Last Signal"
                        subtitle: "Resume from 01:16:08"
                        accent: "#f27822"
                        progress: 0.58
                    }
                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "S2  E4"
                        title: "Northern Lights"
                        subtitle: "The Long Way Home"
                        accent: "#547d8b"
                        progress: 0.31
                    }
                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "MOVIE  •  18 MIN LEFT"
                        title: "Orange County Skies"
                        subtitle: "Resume from 01:34:22"
                        accent: "#bd633d"
                        progress: 0.81
                    }
                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "S1  E7"
                        title: "After Midnight"
                        subtitle: "Static in the Valley"
                        accent: "#6b5b7d"
                        progress: 0.46
                    }
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: !demoMode && serverClient.homeReady
                         && serverClient.continueWatching.length > 0

                SectionTitle {
                    width: parent.width
                    title: "Continue watching"
                    actionText: "SEE ALL  ›"
                }

                Row {
                    width: parent.width
                    spacing: 15

                    Repeater {
                        model: Math.min(4, serverClient.continueWatching.length)

                        MediaCard {
                            required property int index
                            property var media: serverClient.continueWatching[index]

                            width: (parent.width - 45) / 4
                            eyebrow: root.mediaLabel(media)
                            title: root.itemTitle(media, "Untitled")
                            subtitle: root.continueSubtitle(media)
                            artSource: media && media.poster ? media.poster : ""
                            accent: root.cardAccent(index)
                            progress: root.progressValue(media ? media.progressPercent : 0)
                        }
                    }
                }
            }

            Row {
                width: contentColumn.width
                spacing: 22
                visible: demoMode

                Column {
                    id: liveColumn
                    width: parent.width * 0.72
                    spacing: 12

                    SectionTitle {
                        width: parent.width
                        title: "Live on Tater Tube"
                        actionText: "OPEN GUIDE  ›"
                    }

                    Row {
                        width: parent.width
                        spacing: 15

                        MediaCard {
                            width: (parent.width - 30) / 3
                            eyebrow: "CH 12  •  LIVE"
                            title: "Saturday Cartoons"
                            subtitle: "Up next: Galaxy Rangers"
                            badge: "12"
                            accent: "#ef7423"
                            progress: 0.67
                        }
                        MediaCard {
                            width: (parent.width - 30) / 3
                            eyebrow: "CH 24  •  LIVE"
                            title: "Creature Features"
                            subtitle: "Up next: Night Visitors"
                            badge: "24"
                            accent: "#75864b"
                            progress: 0.38
                        }
                        MediaCard {
                            width: (parent.width - 30) / 3
                            eyebrow: "CH 88  •  LIVE"
                            title: "Neon Nights"
                            subtitle: "Up next: Electric Dreams"
                            badge: "88"
                            accent: "#6a597d"
                            progress: 0.52
                        }
                    }
                }

                Rectangle {
                    width: parent.width - liveColumn.width - parent.spacing
                    height: 232
                    anchors.bottom: parent.bottom
                    radius: 22
                    color: "#24282d"
                    border.width: 1
                    border.color: "#41464c"
                    clip: true

                    Image {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -12
                        anchors.bottomMargin: -4
                        width: 145
                        height: 145
                        source: "../assets/mascot/tater-wave.png"
                        fillMode: Image.PreserveAspectFit
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 22
                        width: parent.width - 130
                        spacing: 9

                        Text {
                            text: "TATER SAYS"
                            color: root.orange
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.4
                        }
                        Text {
                            width: parent.width
                            text: "Your sci-fi channel starts a new movie in 8 minutes."
                            color: root.textPrimary
                            wrapMode: Text.WordWrap
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "VIEW CHANNEL  ›"
                            color: root.orangeBright
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            Row {
                width: contentColumn.width
                spacing: 22
                visible: !demoMode && serverClient.homeReady
                         && serverClient.liveChannels.length > 0

                Column {
                    id: serverLiveColumn
                    width: parent.width * 0.72
                    spacing: 12

                    SectionTitle {
                        width: parent.width
                        title: "Live on Tater Tube"
                        actionText: "OPEN GUIDE  ›"
                    }

                    Row {
                        width: parent.width
                        spacing: 15

                        Repeater {
                            model: Math.min(3, serverClient.liveChannels.length)

                            MediaCard {
                                required property int index
                                property var channel: serverClient.liveChannels[index]
                                property var currentProgram: root.channelNow(channel)

                                width: (parent.width - 30) / 3
                                eyebrow: "CH " + channel.number + "  •  LIVE"
                                title: root.channelTitle(channel)
                                subtitle: root.channelSubtitle(channel)
                                badge: channel.number || "TV"
                                artSource: currentProgram && currentProgram.poster
                                           ? currentProgram.poster : ""
                                accent: root.cardAccent(index)
                                progress: root.progressValue(currentProgram
                                                             ? currentProgram.progressPercent : 0)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - serverLiveColumn.width - parent.spacing
                    height: 232
                    anchors.bottom: parent.bottom
                    radius: 22
                    color: "#24282d"
                    border.width: 1
                    border.color: "#41464c"
                    clip: true

                    Image {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -12
                        anchors.bottomMargin: -4
                        width: 145
                        height: 145
                        source: "../assets/mascot/tater-wave.png"
                        fillMode: Image.PreserveAspectFit
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 22
                        width: parent.width - 130
                        spacing: 9

                        Text {
                            text: "TATER SAYS"
                            color: root.orange
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.4
                        }
                        Text {
                            width: parent.width
                            text: root.taterLiveMessage()
                            color: root.textPrimary
                            wrapMode: Text.WordWrap
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "VIEW CHANNEL  ›"
                            color: root.orangeBright
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: demoMode

                SectionTitle {
                    width: parent.width
                    title: "Recently added"
                    actionText: "BROWSE LIBRARY  ›"
                }

                Row {
                    spacing: 15
                    PosterCard { title: "Cosmic Drift"; meta: "2026  •  1h 52m"; number: "01"; accent: "#7d4d91" }
                    PosterCard { title: "Harbor Street"; meta: "2024  •  2 seasons"; number: "02"; accent: "#4d7485" }
                    PosterCard { title: "The Long Winter"; meta: "2025  •  1h 44m"; number: "03"; accent: "#506c79" }
                    PosterCard { title: "Signal Lost"; meta: "2023  •  8 episodes"; number: "04"; accent: "#9c5a39" }
                    PosterCard { title: "Dust & Thunder"; meta: "2026  •  2h 06m"; number: "05"; accent: "#805a3d" }
                    PosterCard { title: "Side Streets"; meta: "2022  •  1h 37m"; number: "06"; accent: "#526158" }
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: !demoMode && serverClient.homeReady
                         && serverClient.recentlyAdded.length > 0

                SectionTitle {
                    width: parent.width
                    title: "Recently added"
                    actionText: "BROWSE LIBRARY  ›"
                }

                Row {
                    spacing: 15

                    Repeater {
                        model: Math.min(6, serverClient.recentlyAdded.length)

                        PosterCard {
                            required property int index
                            property var media: serverClient.recentlyAdded[index]

                            title: root.itemTitle(media, "Untitled")
                            meta: root.itemMeta(media)
                            number: index < 9 ? "0" + (index + 1) : String(index + 1)
                            artSource: media && media.poster ? media.poster : ""
                            accent: root.cardAccent(index)
                        }
                    }
                }
            }

            Rectangle {
                readonly property bool hasHomeContent:
                    serverClient.continueWatching.length > 0
                    || serverClient.recentlyAdded.length > 0
                    || serverClient.liveChannels.length > 0

                visible: !demoMode && serverClient.paired
                         && (!serverClient.homeReady || !hasHomeContent)
                width: contentColumn.width
                height: 244
                radius: 24
                color: root.panel
                border.width: 1
                border.color: "#3b4046"

                Row {
                    anchors.centerIn: parent
                    spacing: 28

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 142
                        height: 142
                        source: "../assets/mascot/tater-front.png"
                        fillMode: Image.PreserveAspectFit
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 560
                        spacing: 10

                        Text {
                            text: serverClient.homeErrorMessage.length > 0
                                  ? "Couldn’t load your home screen"
                                  : (serverClient.homeLoading || !serverClient.homeReady
                                     ? "Loading your Tater Tube"
                                     : "Connected and ready")
                            color: root.textPrimary
                            font.pixelSize: 28
                            font.weight: Font.Bold
                        }
                        Text {
                            width: parent.width
                            text: serverClient.homeErrorMessage.length > 0
                                  ? serverClient.homeErrorMessage
                                  : (serverClient.homeLoading || !serverClient.homeReady
                                     ? "Fetching Continue Watching, Tube TV, artwork, and your newest media."
                                     : "The server is paired, but there isn’t any home-screen media to show yet.")
                            color: root.textSecondary
                            wrapMode: Text.WordWrap
                            font.pixelSize: 16
                        }
                        Text {
                            text: serverClient.serverName.length > 0
                                  ? serverClient.serverName + "  •  " + serverClient.serverUrl
                                  : serverClient.serverUrl
                            color: root.orangeBright
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        FocusButton {
                            visible: serverClient.homeErrorMessage.length > 0
                            width: 180
                            text: "Try again"
                            primary: true
                            onClicked: serverClient.refreshHome()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: pairingOverlay
        visible: !demoMode && !serverClient.paired
        anchors.fill: parent
        color: "#e608090b"
        z: 100

        Rectangle {
            anchors.centerIn: parent
            width: 620
            height: 560
            radius: 28
            color: "#202328"
            border.width: 1
            border.color: "#484d53"

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 24
                width: 122
                height: 122
                source: "../assets/mascot/tater-wave.png"
                fillMode: Image.PreserveAspectFit
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 150
                anchors.leftMargin: 60
                anchors.rightMargin: 60
                spacing: 15

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome to Tater Tube Player"
                    color: root.textPrimary
                    font.pixelSize: 29
                    font.weight: Font.Bold
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Pair this screen with Tater Tube Server to bring in your library and channels."
                    color: root.textSecondary
                    wrapMode: Text.WordWrap
                    font.pixelSize: 15
                }

                TextField {
                    id: serverField
                    width: parent.width
                    height: 54
                    placeholderText: "Server address  •  192.168.1.50:8080"
                    color: root.textPrimary
                    placeholderTextColor: "#7f858b"
                    font.pixelSize: 16
                    selectByMouse: true
                    background: Rectangle {
                        radius: 14
                        color: "#16181c"
                        border.width: serverField.activeFocus ? 2 : 1
                        border.color: serverField.activeFocus ? root.orange : "#41464c"
                    }
                }

                TextField {
                    id: pinField
                    width: parent.width
                    height: 54
                    placeholderText: "Six-digit pairing code"
                    color: root.textPrimary
                    placeholderTextColor: "#7f858b"
                    font.pixelSize: 18
                    font.letterSpacing: 4
                    maximumLength: 6
                    inputMethodHints: Qt.ImhDigitsOnly
                    horizontalAlignment: Text.AlignHCenter
                    background: Rectangle {
                        radius: 14
                        color: "#16181c"
                        border.width: pinField.activeFocus ? 2 : 1
                        border.color: pinField.activeFocus ? root.orange : "#41464c"
                    }
                    onAccepted: serverClient.pair(serverField.text, text)
                }

                Text {
                    visible: serverClient.errorMessage.length > 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: serverClient.errorMessage
                    color: "#ff967f"
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                }

                FocusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 220
                    text: serverClient.busy ? "Pairing…" : "Pair this screen"
                    primary: true
                    onClicked: {
                        if (!serverClient.busy)
                            serverClient.pair(serverField.text, pinField.text)
                    }
                }
            }
        }
    }
}
