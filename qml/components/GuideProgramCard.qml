import QtQuick

FocusScope {
    id: card

    property string timeLabel: "NOW"
    property string title: "Tater Tube"
    property string meta: ""
    property bool isCurrent: false
    property bool showProgress: true
    property real progress: 0
    property color accent: "#ff781f"
    property url artSource: ""
    property url fallbackArtSource: ""
    property real artworkOpacity: 0.62
    property bool logoArtwork: false
    property bool fallbackArtworkActive: false
    signal activated()

    onArtSourceChanged: fallbackArtworkActive = false
    onFallbackArtSourceChanged: fallbackArtworkActive = false

    implicitWidth: 300
    implicitHeight: 160
    activeFocusOnTab: true
    scale: activeFocus ? 1.018 : (pointer.containsMouse ? 1.01 : 1.0)
    z: activeFocus ? 3 : 1

    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    function activate() {
        forceActiveFocus()
        activated()
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true }
    Keys.onEnterPressed: event => { activate(); event.accepted = true }
    Keys.onSpacePressed: event => { activate(); event.accepted = true }

    Rectangle {
        anchors.fill: parent
        radius: 20
        clip: true
        color: "#22262b"
        border.width: card.activeFocus ? 3 : (card.isCurrent ? 2 : 1)
        border.color: card.activeFocus ? "#ff9b54"
                                      : (card.isCurrent ? "#c86427" : "#41464c")

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.darker(card.accent, 2.4) }
            GradientStop { position: 0.62; color: "#24282d" }
            GradientStop { position: 1.0; color: "#191c20" }
        }

        Image {
            id: artwork
            anchors.fill: parent
            anchors.margins: card.logoArtwork ? 14 : 0
            source: card.fallbackArtworkActive || String(card.artSource).length === 0
                    ? card.fallbackArtSource : card.artSource
            sourceSize: Qt.size(Math.max(600, Math.ceil(card.width * 2)),
                                Math.max(320, Math.ceil(card.height * 2)))
            fillMode: card.logoArtwork ? Image.PreserveAspectFit : Image.PreserveAspectCrop
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
                GradientStop { position: 0.0; color: card.logoArtwork ? "#10000000" : "#18000000" }
                GradientStop { position: 0.48; color: card.logoArtwork ? "#18000000" : "#67000000" }
                GradientStop { position: 1.0; color: card.logoArtwork ? "#34131518" : "#ea131518" }
            }
        }

        Rectangle {
            visible: card.logoArtwork
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 10
            width: channelBadge.implicitWidth + 16
            height: 24
            radius: 12
            color: "#b8181b1f"
            border.width: 1
            border.color: "#67554b"

            Text {
                id: channelBadge
                anchors.centerIn: parent
                text: card.timeLabel
                color: "#f4c29e"
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.7
            }
        }

        Rectangle {
            width: 112
            height: 112
            radius: 56
            anchors.right: parent.right
            anchors.rightMargin: -22
            anchors.top: parent.top
            anchors.topMargin: -30
            color: "transparent"
            visible: !artwork.visible
            border.width: 18
            border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.17)
        }

        Column {
            visible: !card.logoArtwork
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: progressTrack.visible ? progressTrack.top : parent.bottom
            anchors.margins: 17
            anchors.leftMargin: 17
            anchors.bottomMargin: progressTrack.visible ? 13 : 17
            spacing: 6

            Text {
                text: card.timeLabel
                color: card.isCurrent ? card.accent : "#c3c6c9"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.0
            }

            Text {
                width: parent.width
                text: card.title
                color: "#f7f7f5"
                elide: Text.ElideRight
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: card.meta
                color: "#aeb2b7"
                elide: Text.ElideRight
                font.pixelSize: 12
            }
        }

        Rectangle {
            id: progressTrack
            visible: card.showProgress && card.isCurrent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 5
            color: "#4a4039"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, card.progress))
                height: parent.height
                color: card.accent
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -5
            radius: 24
            color: "transparent"
            border.width: card.activeFocus ? 2 : 0
            border.color: "#66ff7a1a"
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
