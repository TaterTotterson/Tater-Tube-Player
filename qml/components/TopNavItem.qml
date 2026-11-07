import QtQuick

FocusScope {
    id: control

    property string text: ""
    property string destination: ""
    property bool selected: false
    property bool compact: false
    property bool activateOnFocus: !compact
    property color accent: "#ff7a1a"
    signal requested(string destination)

    implicitWidth: Math.max(compact ? 48 : 96, label.implicitWidth + (compact ? 24 : 34))
    implicitHeight: 48
    activeFocusOnTab: true

    function activate() {
        control.forceActiveFocus()
        control.requested(control.destination)
    }

    onActiveFocusChanged: {
        if (activeFocus && !selected && activateOnFocus)
            requested(destination)
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true }
    Keys.onEnterPressed: event => { activate(); event.accepted = true }
    Keys.onSpacePressed: event => { activate(); event.accepted = true }

    Text {
        id: label
        anchors.centerIn: parent
        text: control.text
        color: control.activeFocus || control.selected ? "#f8f7f5" : "#b8b8b6"
        font.pixelSize: control.compact ? 22 : 14
        font.weight: Font.Bold
        font.letterSpacing: control.compact ? 0 : 1.1
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 3
        radius: 2
        visible: control.selected
        color: control.accent
    }

    Rectangle {
        width: 5
        height: 5
        radius: 3
        anchors.left: label.left
        anchors.leftMargin: -12
        anchors.verticalCenter: label.verticalCenter
        visible: control.selected && control.activeFocus && !control.compact
        color: control.accent
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.activate()
    }
}
