import QtQuick

FocusScope {
    id: resultRow

    property string title: "Release"
    property string meta: ""
    property string number: "01"
    signal activated()

    implicitWidth: 960
    implicitHeight: Math.max(92, releaseName.implicitHeight + 48)
    activeFocusOnTab: true
    z: activeFocus ? 2 : 1

    function activate() {
        resultRow.forceActiveFocus()
        resultRow.activated()
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true }
    Keys.onEnterPressed: event => { activate(); event.accepted = true }
    Keys.onSpacePressed: event => { activate(); event.accepted = true }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: resultRow.activeFocus || pointer.containsMouse ? "#2a211c" : "#181b1f"
        border.width: resultRow.activeFocus ? 3 : 1
        border.color: resultRow.activeFocus ? "#ff8738" : "#363b41"

        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            id: releaseNumber
            anchors.left: parent.left
            anchors.leftMargin: 17
            anchors.verticalCenter: parent.verticalCenter
            width: 54
            height: 54
            radius: 13
            color: "#2c3035"
            border.width: 1
            border.color: resultRow.activeFocus ? "#d66a26" : "#444a50"

            Text {
                anchors.centerIn: parent
                text: resultRow.number
                color: resultRow.activeFocus ? "#ff9a55" : "#d5d8da"
                font.pixelSize: 16
                font.weight: Font.Bold
            }
        }

        Column {
            anchors.left: releaseNumber.right
            anchors.leftMargin: 17
            anchors.right: arrow.left
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Text {
                id: releaseName
                width: parent.width
                text: resultRow.title
                color: "#f7f7f4"
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                visible: resultRow.meta.length > 0
                text: resultRow.meta
                color: "#aeb3b8"
                elide: Text.ElideRight
                font.pixelSize: 12
                font.letterSpacing: 0.15
            }
        }

        Text {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 21
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: resultRow.activeFocus ? "#ff964f" : "#747a80"
            font.pixelSize: 34
            font.weight: Font.Light
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        radius: 21
        color: "transparent"
        visible: resultRow.activeFocus
        border.width: 2
        border.color: "#55ff781f"
        z: -1
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: resultRow.activate()
    }
}
