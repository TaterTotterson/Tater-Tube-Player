import QtQuick

FocusScope {
    id: card

    property string title: "Episode"
    property string meta: ""
    property string description: ""
    property url artSource: ""
    property real progress: 0
    property bool current: false
    signal activated()

    implicitWidth: 680
    implicitHeight: 205
    activeFocusOnTab: true
    scale: activeFocus ? 1.018 : (pointer.containsMouse ? 1.01 : 1.0)
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
        color: "#2e16191d"
        border.width: card.activeFocus ? 3 : (card.current ? 2 : 1)
        border.color: card.activeFocus ? "#ff9349"
                                      : (card.current ? "#b086502e" : "#704b5157")

        Row {
            anchors.fill: parent

            Rectangle {
                width: parent.width * 0.39
                height: parent.height
                color: "#2e171a1e"
                clip: true

                Image {
                    id: artwork
                    anchors.fill: parent
                    source: card.artSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                    opacity: 0.8
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !artwork.visible
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#8061351d" }
                        GradientStop { position: 1.0; color: "#521b1f23" }
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: 90
                    height: 90
                    source: "../../assets/mascot/tater-front.png"
                    fillMode: Image.PreserveAspectFit
                    visible: !artwork.visible
                    opacity: 0.72
                }

                Rectangle {
                    visible: card.current
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 13
                    width: currentText.implicitWidth + 18
                    height: 27
                    radius: 9
                    color: "#e61b1d20"
                    border.width: 1
                    border.color: "#765039"

                    Text {
                        id: currentText
                        anchors.centerIn: parent
                        text: "UP NEXT"
                        color: "#ff9a55"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }
            }

            Column {
                width: parent.width * 0.61
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 22
                rightPadding: 20
                spacing: 8

                Text {
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    text: card.meta
                    color: card.current ? "#ff8d43" : "#b4b8bc"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.0
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    text: card.title
                    color: "#f7f6f2"
                    font.pixelSize: 21
                    font.weight: Font.Bold
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }

                Text {
                    visible: card.description.length > 0
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    text: card.description
                    color: "#aeb2b5"
                    font.pixelSize: 13
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }
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
