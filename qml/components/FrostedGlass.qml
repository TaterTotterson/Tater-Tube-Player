import QtQuick
import QtQuick.Effects

Item {
    id: glass

    property Item sourceItem: null
    property Item coordinateItem: parent
    property real updateToken: 0
    property real blurAmount: 0.72
    property real brightness: -0.08
    property real cornerRadius: 20
    property real samplingMargin: 22
    property color tint: "#42101418"

    visible: sourceItem !== null && width > 0 && height > 0
    clip: true

    ShaderEffectSource {
        id: capturedBackground
        x: -glass.samplingMargin
        y: -glass.samplingMargin
        width: glass.width + glass.samplingMargin * 2
        height: glass.height + glass.samplingMargin * 2
        sourceItem: glass.sourceItem
        sourceRect: {
            if (!glass.sourceItem || !glass.coordinateItem)
                return Qt.rect(0, 0, 1, 1)
            var point = glass.coordinateItem.mapToItem(glass.sourceItem, 0, 0)
            return Qt.rect(point.x - glass.samplingMargin,
                           point.y - glass.samplingMargin + glass.updateToken * 0,
                           glass.coordinateItem.width + glass.samplingMargin * 2,
                           glass.coordinateItem.height + glass.samplingMargin * 2)
        }
        textureSize: Qt.size(Math.max(1, Math.ceil(width * 0.5)),
                             Math.max(1, Math.ceil(height * 0.5)))
        live: glass.visible
        hideSource: false
        recursive: false
        visible: false
    }

    MultiEffect {
        x: -glass.samplingMargin
        y: -glass.samplingMargin
        width: glass.width + glass.samplingMargin * 2
        height: glass.height + glass.samplingMargin * 2
        source: capturedBackground
        blurEnabled: true
        blur: glass.blurAmount
        blurMax: 20
        blurMultiplier: 1.0
        brightness: glass.brightness
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: roundedMask
        opacity: 0.96
    }

    Item {
        id: roundedMask
        x: -glass.samplingMargin
        y: -glass.samplingMargin
        width: glass.width + glass.samplingMargin * 2
        height: glass.height + glass.samplingMargin * 2
        visible: false
        layer.enabled: true

        Rectangle {
            x: glass.samplingMargin
            y: glass.samplingMargin
            width: glass.width
            height: glass.height
            radius: glass.cornerRadius
            color: "white"
            antialiasing: true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: glass.cornerRadius
        color: glass.tint
        antialiasing: true
    }
}
