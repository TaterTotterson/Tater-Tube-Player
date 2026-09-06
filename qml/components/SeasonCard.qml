import QtQuick

FocusScope {
    id: card

    property string title: "Season"
    property string meta: ""
    property string resumeTitle: ""
    property url artSource: ""
    property Item glassSource: null
    property real glassScrollOffset: 0
    property real progress: 0
    signal activated()

    implicitWidth: 340
    implicitHeight: 184
    activeFocusOnTab: true
    scale: activeFocus ? 1.025 : (pointer.containsMouse ? 1.012 : 1.0)
    z: activeFocus ? 2 : 1

    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    function activate() {
        UiSounds.select()
        card.forceActiveFocus()
        card.activated()
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true }
    Keys.onEnterPressed: event => { activate(); event.accepted = true }
    Keys.onSpacePressed: event => { activate(); event.accepted = true }

    Rectangle {
        anchors.fill: parent
        radius: 20
        clip: true
        color: "#3d16191d"
        border.width: card.activeFocus ? 3 : 0
        border.color: "#ff9349"
        antialiasing: true

        FrostedGlass {
            anchors.fill: parent
            sourceItem: card.glassSource
            coordinateItem: card
            updateToken: card.glassScrollOffset
            cornerRadius: 20
            tint: "#42101418"
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#5c0c0e11" }
                GradientStop { position: 0.62; color: "#38171a1e" }
                GradientStop { position: 1.0; color: "#24171412" }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: seasonPoster.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: card.resumeTitle.length > 0 ? "CONTINUE WATCHING" : "TATER TV"
                color: card.resumeTitle.length > 0 ? "#ff8a3d" : "#b5b9bd"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.25
            }

            Text {
                width: parent.width
                text: card.title
                color: "#f7f6f2"
                elide: Text.ElideRight
                font.pixelSize: 27
                font.weight: Font.Black
            }

            Text {
                width: parent.width
                text: card.resumeTitle.length > 0 ? "Resume " + card.resumeTitle : card.meta
                color: "#c1c4c6"
                elide: Text.ElideRight
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: seasonPoster
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 11
            width: Math.min(108, parent.width * 0.31)
            radius: 13
            clip: true
            color: "#66272b30"
            border.width: 1
            border.color: "#8f68462f"

            Image {
                id: seasonArtwork
                anchors.fill: parent
                source: card.artSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }

            Image {
                anchors.centerIn: parent
                width: 64
                height: 64
                source: "../../assets/mascot/tater-front.png"
                fillMode: Image.PreserveAspectFit
                visible: !seasonArtwork.visible
                opacity: 0.72
            }
        }

        Rectangle {
            id: progressTrack
            visible: card.resumeTitle.length > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 6
            color: "#4b5055"

            Rectangle {
                width: parent.width * Math.max(0.025, Math.min(1, card.progress))
                height: parent.height
                color: "#ff7a1a"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 26
        color: "transparent"
        border.width: card.activeFocus ? 2 : 0
        border.color: "#55ff7a1a"
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activate()
    }
}
