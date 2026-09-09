import QtQuick

FocusScope {
    id: actionCard

    property string text: "See all"
    property string symbol: "→"
    signal activated()

    implicitWidth: 148
    implicitHeight: 178
    activeFocusOnTab: true
    z: activeFocus ? 4 : 1
    scale: activeFocus ? 1.045 : (pointer.containsMouse ? 1.025 : 1.0)

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    function reveal() {
        var ancestor = actionCard.parent
        while (ancestor) {
            if (typeof ancestor.revealItem === "function") {
                ancestor.revealItem(actionCard)
                return
            }
            ancestor = ancestor.parent
        }
    }

    function activate() {
        actionCard.forceActiveFocus()
        actionCard.activated()
    }

    onActiveFocusChanged: {
        if (activeFocus)
            reveal()
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true }
    Keys.onEnterPressed: event => { activate(); event.accepted = true }
    Keys.onSpacePressed: event => { activate(); event.accepted = true }

    Rectangle {
        id: tile
        anchors.centerIn: parent
        width: 132
        height: 132
        radius: 23
        color: actionCard.activeFocus || pointer.containsMouse
               ? "#e6341b0d" : "#c51a1d21"
        border.width: actionCard.activeFocus ? 3 : 1
        border.color: actionCard.activeFocus ? "#ff8738" : "#574137"

        Rectangle {
            anchors.centerIn: parent
            width: 54
            height: 54
            radius: 27
            color: actionCard.activeFocus ? "#ff7a1a" : "#2e2926"
            border.width: actionCard.activeFocus ? 0 : 1
            border.color: "#70503b"

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: actionCard.symbol
                color: actionCard.activeFocus ? "#17110e" : "#ff8738"
                font.pixelSize: 29
                font.weight: Font.Black
            }
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 12
            text: actionCard.text.toUpperCase()
            color: "#f5f2ef"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.7
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: tile
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: actionCard.activate()
    }
}
