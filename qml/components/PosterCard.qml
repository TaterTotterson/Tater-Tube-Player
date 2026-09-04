import QtQuick

FocusScope {
    id: card

    property string title: "Title"
    property string meta: ""
    property string number: ""
    property color accent: "#f47a23"
    property url artSource: ""
    signal activated()

    implicitWidth: 178
    implicitHeight: 284
    activeFocusOnTab: true
    scale: activeFocus ? 1.035 : (pointer.containsMouse ? 1.02 : 1.0)
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
        radius: 18
        clip: true
        color: "#23272c"
        border.width: card.activeFocus ? 3 : 1
        border.color: card.activeFocus ? "#ff8738" : "#3a3f45"

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(card.accent, 1.05) }
            GradientStop { position: 0.48; color: Qt.darker(card.accent, 1.8) }
            GradientStop { position: 1.0; color: "#1b1e22" }
        }

        Image {
            id: artwork
            anchors.fill: parent
            source: card.artSource
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
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 108
            color: "#e917191d"
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
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
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 24
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
