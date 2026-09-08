import QtQuick

FocusScope {
    id: card

    property string title: "Title"
    property string meta: ""
    property string number: ""
    property string badge: ""
    property color accent: "#f47a23"
    property url artSource: ""
    property Item artworkViewport: null
    property real artworkScrollOffset: 0
    property real artworkPreloadMargin: 480
    property bool artworkRequested: false
    property real progress: 0
    signal activated()

    implicitWidth: 178
    implicitHeight: 284
    activeFocusOnTab: true
    z: activeFocus ? 2 : 1

    function activate() {
        card.forceActiveFocus()
        card.activated()
    }

    function artworkViewportY() {
        return artworkViewport ? card.mapToItem(artworkViewport, 0, 0).y : 0
    }

    function artworkNearViewport() {
        if (!artworkViewport)
            return true
        var viewportY = artworkViewportY()
        return viewportY + card.height >= -artworkPreloadMargin
                && viewportY <= artworkViewport.height + artworkPreloadMargin
    }

    function scheduleArtwork() {
        if (artworkRequested || !artworkNearViewport()
                || String(artSource || "").length === 0)
            return
        artworkRequestDelay.interval = Math.min(180, Math.max(0,
                    Math.floor(Math.max(0, artworkViewportY())
                               / Math.max(1, card.height))) * 24)
        artworkRequestDelay.restart()
    }

    Component.onCompleted: scheduleArtwork()
    onArtworkViewportChanged: scheduleArtwork()
    onArtworkScrollOffsetChanged: scheduleArtwork()
    onArtSourceChanged: {
        artworkRequested = false
        scheduleArtwork()
    }

    Timer {
        id: artworkRequestDelay
        onTriggered: {
            if (card.artworkNearViewport())
                card.artworkRequested = true
        }
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true }
    Keys.onEnterPressed: event => { activate(); event.accepted = true }
    Keys.onSpacePressed: event => { activate(); event.accepted = true }

    Rectangle {
        anchors.fill: parent
        radius: 10
        clip: true
        color: "#23272c"
        border.width: 1
        border.color: "#3a3f45"

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(card.accent, 1.05) }
            GradientStop { position: 0.48; color: Qt.darker(card.accent, 1.8) }
            GradientStop { position: 1.0; color: "#1b1e22" }
        }

        Image {
            id: artwork
            anchors.fill: parent
            source: card.artworkRequested ? card.artSource : ""
            sourceSize: Qt.size(Math.max(360, Math.ceil(card.width * 2)),
                                Math.max(568, Math.ceil(card.height * 2)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: status === Image.Ready
        }

        Rectangle {
            width: 150
            height: 150
            radius: 75
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 26
            color: "#24000000"
            border.width: 2
            border.color: "#33ffffff"
            visible: !artwork.visible
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 57
            text: card.number.length > 0 ? card.number : "●"
            color: "#eaffffff"
            font.pixelSize: card.number.length > 0 ? 48 : 72
            font.weight: Font.Black
            visible: !artwork.visible
        }

        Rectangle {
            visible: card.badge.length > 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 12
            width: posterBadgeText.implicitWidth + 18
            height: 27
            radius: 9
            color: "#e61a1d21"
            border.width: 1
            border.color: "#6a4a33"

            Text {
                id: posterBadgeText
                anchors.centerIn: parent
                text: card.badge
                color: "#ff9a55"
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.8
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 108
            color: "#e917191d"
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: progressTrack.visible ? progressTrack.top : parent.bottom
            anchors.margins: 16
            anchors.bottomMargin: progressTrack.visible ? 13 : 16
            spacing: 6

            Text {
                width: parent.width
                text: card.title
                color: "#ffffff"
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: card.meta
                color: "#b9bcc0"
                elide: Text.ElideRight
                font.pixelSize: 12
            }
        }

        Rectangle {
            id: progressTrack
            visible: card.progress > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 6
            color: "#4b5055"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, card.progress))
                height: parent.height
                color: "#ff7a1a"
            }
        }
    }

    // Keep the controller focus ring above asynchronously loaded artwork.
    // A border on the clipped background is painted below its Image children
    // and disappears as soon as a poster finishes loading.
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "transparent"
        visible: card.activeFocus
        border.width: 3
        border.color: "#ff8738"
        z: 20
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activate()
    }
}
