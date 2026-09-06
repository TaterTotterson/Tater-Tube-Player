import QtQuick
import QtQuick.Effects

Item {
    id: glass

    property Item sourceItem: null
    property Item coordinateItem: parent
    property real updateToken: 0
    property real blurAmount: 0.48
    property color tint: "#38101418"

    visible: sourceItem !== null && width > 0 && height > 0
    clip: true

    ShaderEffectSource {
        id: capturedBackground
        anchors.fill: parent
        sourceItem: glass.sourceItem
        sourceRect: {
            if (!glass.sourceItem || !glass.coordinateItem)
                return Qt.rect(0, 0, 1, 1)
            var point = glass.coordinateItem.mapToItem(glass.sourceItem, 0, 0)
            return Qt.rect(point.x, point.y + glass.updateToken * 0,
                           glass.coordinateItem.width, glass.coordinateItem.height)
        }
        textureSize: Qt.size(Math.max(1, Math.ceil(glass.width * 0.5)),
                             Math.max(1, Math.ceil(glass.height * 0.5)))
        live: glass.visible
        hideSource: false
        recursive: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: capturedBackground
        blurEnabled: true
        blur: glass.blurAmount
        blurMax: 16
        blurMultiplier: 1.0
        autoPaddingEnabled: false
        opacity: 0.86
    }

    Rectangle {
        anchors.fill: parent
        color: glass.tint
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: "#30ffffff"
    }
}
