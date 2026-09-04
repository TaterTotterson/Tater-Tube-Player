import QtQuick

Item {
    id: root

    property string title: "Section"
    property string actionText: ""
    property bool actionEnabled: false
    readonly property alias actionItem: actionControl
    signal actionActivated()

    implicitHeight: 42

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: "#f4f4f2"
        font.pixelSize: 24
        font.weight: Font.DemiBold
    }

    FocusScope {
        id: actionControl
        visible: root.actionText.length > 0
        enabled: root.actionEnabled
        activeFocusOnTab: root.actionEnabled
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: actionLabel.implicitWidth + 26
        height: 36

        function activate() {
            if (!enabled)
                return
            UiSounds.select()
            forceActiveFocus()
            root.actionActivated()
        }

        Keys.onReturnPressed: event => { activate(); event.accepted = true }
        Keys.onEnterPressed: event => { activate(); event.accepted = true }
        Keys.onSpacePressed: event => { activate(); event.accepted = true }

        Rectangle {
            anchors.fill: parent
            radius: 11
            color: actionControl.activeFocus || actionPointer.containsMouse
                   ? "#34383d" : "transparent"
            border.width: actionControl.activeFocus ? 2 : 0
            border.color: "#ff8738"
        }

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: root.actionText
            color: root.actionEnabled ? "#ff8738" : "#90959a"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: actionPointer
            anchors.fill: parent
            enabled: actionControl.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionControl.activate()
        }
    }
}
