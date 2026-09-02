import QtQuick

Item {
    id: root

    property string title: "Section"
    property string actionText: ""

    implicitHeight: 42

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: "#f4f4f2"
        font.pixelSize: 24
        font.weight: Font.DemiBold
    }

    Text {
        visible: root.actionText.length > 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.actionText
        color: "#ff8738"
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
}

