import QtQuick

FocusScope {
    id: card

    property string title: "Season"
    property string meta: ""
    property string resumeTitle: ""
    property url artSource: ""
    property real progress: 0
    property color accent: "#f47a23"
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
        color: "#22262b"
        border.width: card.activeFocus ? 3 : 1
        border.color: card.activeFocus ? "#ff9349" : "#3b4147"

        Image {
            id: artwork
            anchors.fill: parent
            source: card.artSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: status === Image.Ready
            opacity: 0.56
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: artwork.visible ? "#ea121416" : Qt.darker(card.accent, 2.4) }
                GradientStop { position: 0.62; color: "#b5171a1e" }
                GradientStop { position: 1.0; color: "#f017191d" }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 5
            color: card.accent
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 20
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
