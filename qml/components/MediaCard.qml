import QtQuick

FocusScope {
    id: card

    property string eyebrow: "MOVIE"
    property string title: "Title"
    property string subtitle: ""
    property color accent: "#f47a23"
    property url artSource: ""
    property url fallbackArtSource: ""
    property real artworkOpacity: 0.58
    property real progress: 0
    property string badge: ""
    property bool fallbackArtworkActive: false
    signal activated()

    onArtSourceChanged: fallbackArtworkActive = false
    onFallbackArtSourceChanged: fallbackArtworkActive = false

    implicitWidth: 300
    implicitHeight: 178
    activeFocusOnTab: true
    scale: activeFocus ? 1.035 : (pointer.containsMouse ? 1.02 : 1.0)
    z: activeFocus ? 2 : 1

    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    function activate() {
        card.forceActiveFocus()
        card.activated()
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true }
    Keys.onEnterPressed: event => { activate(); event.accepted = true }
    Keys.onSpacePressed: event => { activate(); event.accepted = true }

    Rectangle {
        anchors.fill: parent
        radius: 18
        clip: true
        color: "#22262b"
        border.width: card.activeFocus ? 3 : 1
        border.color: card.activeFocus ? "#ff8738" : "#383d43"

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.darker(card.accent, 2.35) }
            GradientStop { position: 0.58; color: "#24282d" }
            GradientStop { position: 1.0; color: "#191c20" }
        }

        Image {
            id: artwork
            anchors.fill: parent
            source: card.fallbackArtworkActive || String(card.artSource).length === 0
                    ? card.fallbackArtSource : card.artSource
            sourceSize: Qt.size(Math.max(600, Math.ceil(card.width * 2)),
                                Math.max(356, Math.ceil(card.height * 2)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: status === Image.Ready
            opacity: card.artworkOpacity
            onStatusChanged: {
                if (status === Image.Error && !card.fallbackArtworkActive
                        && String(card.fallbackArtSource).length > 0
                        && String(card.fallbackArtSource) !== String(card.artSource)) {
                    card.fallbackArtworkActive = true
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: artwork.visible
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#16000000" }
                GradientStop { position: 0.55; color: "#74000000" }
                GradientStop { position: 1.0; color: "#e5131518" }
            }
        }

        Rectangle {
            width: 124
            height: 124
            radius: 62
            anchors.right: parent.right
            anchors.rightMargin: -20
            anchors.top: parent.top
            anchors.topMargin: -34
            color: "transparent"
            visible: !artwork.visible
            border.width: 20
            border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.18)
        }

        Rectangle {
            width: 74
            height: 6
            radius: 3
            color: card.accent
            rotation: -38
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            opacity: artwork.visible ? 0.0 : 0.55
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.bottom: progressTrack.visible ? progressTrack.top : parent.bottom
            anchors.bottomMargin: progressTrack.visible ? 15 : 18
            spacing: 5

            Text {
                text: card.eyebrow
                color: card.accent
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.4
            }

            Text {
                width: parent.width
                text: card.title
                color: "#f7f7f5"
                elide: Text.ElideRight
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Text {
                visible: text.length > 0
                width: parent.width
                text: card.subtitle
                color: "#b4b7bb"
                elide: Text.ElideRight
                font.pixelSize: 13
            }
        }

        Rectangle {
            visible: card.badge.length > 0
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 16
            width: badgeText.implicitWidth + 18
            height: 26
            radius: 9
            color: "#d9191c20"
            border.width: 1
            border.color: "#4b5056"

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: card.badge
                color: "#e9e9e6"
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        Rectangle {
            id: progressTrack
            visible: card.progress > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 5
            color: "#484d52"

            Rectangle {
                width: parent.width * Math.min(1, Math.max(0, card.progress))
                height: parent.height
                color: "#ff7a1a"
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activate()
    }
}
