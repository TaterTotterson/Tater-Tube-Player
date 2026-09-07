.pragma library

function observedWatchMs(previousTime, previousPosition, now, position, playing) {
    var elapsed = now - previousTime
    var advanced = position - previousPosition
    // A seek, a stall, or waking the device must not count as time watched.
    if (!playing || previousTime <= 0 || elapsed <= 0 || elapsed > 2500
            || advanced <= 0 || advanced > elapsed + 1500)
        return 0
    return Math.min(elapsed, advanced, 1500)
}

function isInterstitial(program) {
    var kind = String(program.kind || program.mediaType || "").toLowerCase()
    return kind === "commercial" || kind === "commercial_break"
            || kind === "bumper" || kind === "tater_bumper"
            || program.isCommercialBreak === true
}

function snapshot(item, live, channels, now, position, duration) {
    if (!item)
        return null
    if (!live) {
        return {key: "video", item: item, kind: String(item.mediaType || "video"),
                positionMs: Math.max(0, position), durationMs: Math.max(0, duration)}
    }

    var channel = item
    for (var i = 0; i < channels.length; ++i) {
        if ((item.number && String(channels[i].number) === String(item.number))
                || (item.id && String(channels[i].id) === String(item.id))) {
            channel = channels[i]
            break
        }
    }
    var schedule = channel.schedule || []
    var program = null
    var programPosition = 0
    var programDuration = 0
    var programStart = ""
    if (schedule.length > 0) {
        var elapsed = Number(channel.guideElapsedSeconds || 0)
        if (Number(channel.guideServerNowMs || 0) > 0)
            elapsed += (now - Number(channel.guideServerNowMs)) / 1000
        else if (Number(channel.guideStartedAtMs || 0) > 0)
            elapsed = (now - Number(channel.guideStartedAtMs)) / 1000
        for (var j = 0; j < schedule.length; ++j) {
            if (Number(schedule[j].start) <= elapsed && elapsed < Number(schedule[j].end)) {
                program = schedule[j]
                programPosition = (elapsed - Number(program.start)) * 1000
                programDuration = (Number(program.end) - Number(program.start)) * 1000
                programStart = String(channel.guideStartedAtMs || "") + ":" + program.start
                break
            }
        }
        // Wait for a fresh guide instead of attributing a new show to an old title.
        if (!program)
            return null
    } else if (channel.now) {
        var startsAt = Date.parse(channel.now.startsAt || "")
        var endsAt = Date.parse(channel.now.endsAt || "")
        if (!isFinite(startsAt) || !isFinite(endsAt) || now < startsAt || now >= endsAt)
            return null
        program = channel.now
        programPosition = now - startsAt
        programDuration = endsAt - startsAt
        programStart = String(startsAt)
    }
    if (!program || isInterstitial(program))
        return null

    var trackedChannel = {}
    for (var key in channel)
        trackedChannel[key] = channel[key]
    trackedChannel.now = program
    return {key: "channel:" + String(channel.number || channel.id || channel.title)
                    + ":" + programStart + ":" + String(program.path || program.title),
            item: trackedChannel, kind: "CHANNEL",
            positionMs: Math.max(0, programPosition),
            durationMs: Math.max(0, programDuration)}
}
