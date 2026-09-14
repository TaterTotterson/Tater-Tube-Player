.pragma library

function verticalGridTarget(currentIndex, itemCount, columnCount, direction) {
    if (itemCount <= 0 || columnCount <= 0 || currentIndex < 0
            || currentIndex >= itemCount || direction === 0)
        return -1

    if (direction < 0) {
        var above = currentIndex - columnCount
        return above >= 0 ? above : -1
    }

    var below = currentIndex + columnCount
    if (below < itemCount)
        return below

    var finalRowStart = Math.floor((itemCount - 1) / columnCount) * columnCount
    if (finalRowStart <= currentIndex)
        return -1

    // Preserve the current column when it exists in the partial last row;
    // otherwise clamp to that row's final available card.
    return Math.min(finalRowStart + currentIndex % columnCount, itemCount - 1)
}

function verticalFocusTarget(points, currentIndex, direction, rowTolerance) {
    if (!points || points.length === 0 || currentIndex < 0
            || currentIndex >= points.length || direction === 0)
        return -1

    var origin = points[currentIndex]
    var nearestDistance = Number.MAX_VALUE
    for (var i = 0; i < points.length; ++i) {
        if (i === currentIndex)
            continue
        var deltaY = Number(points[i].y) - Number(origin.y)
        if ((direction < 0 && deltaY >= -4) || (direction > 0 && deltaY <= 4))
            continue
        nearestDistance = Math.min(nearestDistance, Math.abs(deltaY))
    }
    if (nearestDistance === Number.MAX_VALUE)
        return -1

    // Choose within the nearest visual row before considering horizontal
    // alignment. A shelf left on its trailing action card can otherwise be
    // skipped in favor of a farther shelf whose first card happens to line up.
    var tolerance = rowTolerance === undefined ? 36 : Math.max(0, rowTolerance)
    var winner = -1
    var winnerScore = Number.MAX_VALUE
    for (var j = 0; j < points.length; ++j) {
        if (j === currentIndex)
            continue
        var dy = Number(points[j].y) - Number(origin.y)
        if ((direction < 0 && dy >= -4) || (direction > 0 && dy <= 4))
            continue
        var primary = Math.abs(dy)
        if (primary > nearestDistance + tolerance)
            continue
        var cross = Math.abs(Number(points[j].x) - Number(origin.x))
        var score = cross + (primary - nearestDistance) * 0.1
        if (score < winnerScore) {
            winner = j
            winnerScore = score
        }
    }
    return winner
}

function homeShelfEntry(rows, shelf) {
    var requested = String(shelf || "").toLowerCase()
    var sourceRows = rows || []
    for (var i = 0; i < sourceRows.length; ++i) {
        var entry = sourceRows[i] && sourceRows[i].entry
                ? sourceRows[i].entry : ({})
        var type = String(entry.type || "").toLowerCase()
        var id = String(entry.id || entry.categoryId || "").toLowerCase()
        if ((requested === "continue" && type === "continue")
                || (requested === "recent" && id === "local-discover:recent"))
            return entry
    }

    if (requested === "continue")
        return {type: "continue", title: "Continue Watching", detail: "LOCAL"}
    if (requested === "recent") {
        return {id: "local-discover:recent", type: "localDiscover",
                title: "Recently Added", detail: "LOCAL"}
    }
    return ({})
}

function recentlyAddedLabel(item) {
    var recent = item && item.recentItems ? item.recentItems : []
    if (!recent || recent.length === 0)
        return ""
    if (recent.length === 1)
        return String(recent[0].title || "New episode")
    return recent.length + " recently added episodes"
}

function recentlyAddedAction(item) {
    var recent = item && item.recentItems ? item.recentItems : []
    if (!recent || recent.length === 0)
        return {kind: "default"}
    if (recent.length === 1)
        return {kind: "details", item: recent[0]}

    // The server orders an import batch by season and episode. Open the
    // earliest episode's season so a multi-episode download remains one card
    // without making the viewer hunt for where the new batch starts.
    var firstEpisode = recent[0]
    var episodePath = String(firstEpisode.path || "")
    var separator = episodePath.lastIndexOf("/")
    if (separator <= 0)
        return {kind: "default"}
    var parentPath = episodePath.slice(0, separator)
    var parentSeparator = parentPath.lastIndexOf("/")
    var parentTitle = parentSeparator >= 0
            ? parentPath.slice(parentSeparator + 1) : parentPath
    var sourceIndex = firstEpisode.sourceIndex
    if (sourceIndex === undefined || sourceIndex === null)
        sourceIndex = item && item.sourceIndex !== undefined
                ? item.sourceIndex : 0

    return {
        kind: "browse",
        focusPath: episodePath,
        item: {
            title: parentTitle || String(item && item.title || "Season"),
            categoryId: String(firstEpisode.categoryId
                               || (item && item.categoryId) || ""),
            sourceIndex: Number(sourceIndex),
            path: parentPath,
            mediaType: "season"
        }
    }
}
