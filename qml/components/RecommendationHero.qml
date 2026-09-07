import QtQuick

Rectangle {
    id: hero

    property string assistantName: "Tater"
    property string eyebrow: "A NOTE FROM TATER"
    property string title: "Tater Picks"
    property string message: "Your next set of recommendations is on the way."
    property url artSource: ""
    property int pickCount: 0
    property bool speechLoading: false
    property bool speaking: false
    property string speechError: ""

    implicitHeight: Math.max(278, messageColumn.implicitHeight + 64)
    radius: 28
    color: "#151719"
    border.color: "#554331"
    border.width: 1
    clip: true

    Image {
        anchors.fill: parent
        source: hero.artSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: 0.15
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#fa141618" }
            GradientStop { position: 0.62; color: "#e0141517" }
            GradientStop { position: 1; color: "#902c1b10" }
        }
    }

    Image {
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: Math.min(245, hero.width * 0.21)
        height: Math.min(260, hero.height - 32)
        source: "../../assets/mascot/tater-hero-remote.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Column {
        id: messageColumn
        x: 34
        anchors.verticalCenter: parent.verticalCenter
        width: hero.width - Math.min(290, hero.width * 0.25) - 68
        spacing: 14

        Text {
            text: hero.eyebrow
            color: "#ff984e"
            font.pixelSize: 12
            font.weight: Font.Bold
            font.letterSpacing: 1.6
        }

        Text {
            width: parent.width
            text: hero.title
            color: "#faf7f2"
            font.pixelSize: 32
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: hero.message
            textFormat: Text.PlainText
            color: "#e2dfd9"
            font.pixelSize: 21
            font.weight: Font.Medium
            lineHeight: 1.2
            wrapMode: Text.WordWrap
        }

        Text {
            text: hero.speechLoading ? "Getting " + hero.assistantName + "’s voice…"
                  : hero.speaking ? hero.assistantName + " is speaking"
                  : hero.pickCount > 0 ? hero.pickCount + " picks for you" : "Made for your next watch"
            color: "#b9b4ad"
            font.pixelSize: 13
        }

        Text {
            visible: hero.speechError.length > 0
            width: parent.width
            text: hero.speechError
            textFormat: Text.PlainText
            color: "#dcb491"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }
}
