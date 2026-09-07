import QtQuick

FocusScope {
    id: card

    property string title: "Discover"
    property url artSource: ""
    signal activated()

    implicitWidth: 400
    implicitHeight: 238
    activeFocusOnTab: true
    scale: activeFocus ? 1.025 : (pointer.containsMouse ? 1.012 : 1.0)
    z: activeFocus ? 2 : 1

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    function activate() {
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
        color: "#151719"
        border.width: card.activeFocus ? 3 : 1
        border.color: card.activeFocus ? "#ff8738" : "#34383d"

        Image {
            id: artwork
            anchors.fill: parent
            source: card.artSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            visible: artwork.status !== Image.Ready
            color: "#1d2024"

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#4b2411" }
                GradientStop { position: 0.55; color: "#24272b" }
                GradientStop { position: 1.0; color: "#151719" }
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24
                text: card.title.toUpperCase()
                color: "#ffffff"
                wrapMode: Text.Wrap
                maximumLineCount: 2
                font.pixelSize: 28
                font.weight: Font.Black
            }
        }

        Rectangle {
            anchors.fill: parent
            color: card.activeFocus ? "#08ffffff"
                                    : (pointer.containsMouse ? "#05ffffff" : "transparent")
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
