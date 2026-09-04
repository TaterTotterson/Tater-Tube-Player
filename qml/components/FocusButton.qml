import QtQuick

FocusScope {
    id: control

    property string text: "Button"
    property bool primary: false
    property bool compact: false
    property bool selected: false
    property string soundRole: "select"
    signal clicked()

    implicitWidth: Math.max(compact ? 94 : 142, label.implicitWidth + (compact ? 32 : 46))
    implicitHeight: compact ? 42 : 52
    activeFocusOnTab: true

    function activate() {
        UiSounds.playRole(control.soundRole)
        control.forceActiveFocus()
        control.clicked()
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true }
    Keys.onEnterPressed: event => { activate(); event.accepted = true }
    Keys.onSpacePressed: event => { activate(); event.accepted = true }

    Rectangle {
        anchors.fill: parent
        radius: control.compact ? 13 : 16
        color: control.primary
               ? (control.activeFocus || pointer.containsMouse ? "#ff8129" : "#f46d16")
               : (control.activeFocus || pointer.containsMouse || control.selected
                  ? "#34383d" : "#24272b")
        border.width: control.activeFocus ? 3 : 1
        border.color: control.activeFocus ? "#ff9b54" : (control.primary ? "#ff9349" : "#43474d")

        Behavior on color { ColorAnimation { duration: 110 } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -5
            radius: parent.radius + 5
            color: "transparent"
            border.width: control.activeFocus ? 2 : 0
            border.color: "#66ff7a1a"
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: control.text
        color: control.primary ? "#15100c" : "#f5f5f4"
        font.pixelSize: control.compact ? 15 : 17
        font.weight: Font.DemiBold
        font.letterSpacing: 0.1
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.activate()
    }
}
