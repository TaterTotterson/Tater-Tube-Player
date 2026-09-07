import QtQuick
import QtQuick.Controls.Basic

Flickable {
    id: shelf

    default property alias shelfData: shelfRow.data
    property int visibleCardCount: 4
    property real cardSpacing: 15
    readonly property real cardWidth:
        (width - Math.max(0, visibleCardCount - 1) * cardSpacing) / visibleCardCount

    implicitHeight: 188
    contentWidth: Math.max(width, shelfRow.implicitWidth)
    contentHeight: height
    clip: true
    interactive: contentWidth > width
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    pixelAligned: true

    function revealItem(item) {
        if (!item || shelf.contentWidth <= shelf.width)
            return
        var point = item.mapToItem(shelf.contentItem, 0, 0)
        var padding = 5
        var target = shelf.contentX
        if (point.x < shelf.contentX + padding)
            target = point.x - padding
        else if (point.x + item.width > shelf.contentX + shelf.width - padding)
            target = point.x + item.width - shelf.width + padding
        shelf.contentX = Math.max(0, Math.min(shelf.contentWidth - shelf.width, target))
    }

    onContentWidthChanged: contentX = Math.min(contentX, Math.max(0, contentWidth - width))

    Row {
        id: shelfRow
        y: 5
        spacing: shelf.cardSpacing
    }

    ScrollBar.horizontal: ScrollBar {
        policy: shelf.contentWidth > shelf.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        height: 3
        background: Item {}
        contentItem: Rectangle {
            radius: 2
            color: "#805e646a"
        }
    }
}
