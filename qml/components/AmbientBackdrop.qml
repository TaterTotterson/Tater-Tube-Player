import QtQuick

Item {
    id: backdrop

    property real intensity: 1.0

    clip: true

    Image {
        anchors.fill: parent
        source: "../../assets/ui/tater-orange-glow.png"
        fillMode: Image.Stretch
        smooth: true
        asynchronous: true
        cache: true
        opacity: Math.max(0, Math.min(1, backdrop.intensity))
    }

    Image {
        anchors.fill: parent
        source: "../../assets/tater-scanlines.png"
        fillMode: Image.Tile
        opacity: 0.055 * Math.max(0, Math.min(1, backdrop.intensity))
    }
}
