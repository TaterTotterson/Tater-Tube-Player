import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtMultimedia
import "components"

ApplicationWindow {
    id: root

    width: 1600
    height: 900
    minimumWidth: 1180
    minimumHeight: 720
    visible: true
    title: "Tater Tube Player"
    color: "#101215"

    readonly property color orange: "#ff781f"
    readonly property color orangeBright: "#ff964f"
    readonly property color panel: "#202328"
    readonly property color panelSoft: "#282c31"
    readonly property color textPrimary: "#f6f6f3"
    readonly property color textSecondary: "#aaafb4"
    property string currentPage: "home"
    property var selectedItem: ({})
    property string selectedKind: "MEDIA"
    property bool detailsOpen: false
    property var returnFocusItem: null
    property bool playbackOpen: false
    property var playbackItem: ({})
    property bool playbackIsLive: false
    property string playbackSourceUrl: ""
    property string playbackPlanUrl: ""
    property string playbackSourceVideoRange: "sdr"
    property bool playbackUsingFallback: false
    property bool playbackUsingAudioTranscode: false
    property bool playbackUsingVideoTranscode: false
    property bool playbackPlanPending: false
    property string playbackAudioCodec: ""
    property string playbackAudioMode: "direct"
    property real playbackBaseOffsetMs: 0
    property real playbackPendingResumeMs: 0
    property string playbackError: ""
    property string playbackStatusMessage: ""
    property string playbackQuality: "Direct play"
    property bool playbackControlsVisible: true
    property bool playbackEnded: false
    property bool playbackHasVideoFrame: false
    readonly property bool compatiblePlayback: compatiblePlaybackMode === true
    property int libraryVisibleLimit: 60
    property int discoverVisibleLimit: 60
    property bool sideMenuOpen: false
    property var sideMenuReturnFocus: null
    property bool uiFocusSoundsArmed: false
    property var uiLastFocusItem: null
    property double guideClockMs: Date.now()

    function hasPersonalizedHero() {
        var heroCopy = serverClient.homeHero
        return !demoMode && heroCopy && heroCopy.personalized === true
                && String(heroCopy.message || "").trim().length > 0
    }

    function personalizedHeroHeadline() {
        var hour = (new Date()).getHours()
        if (hour >= 5 && hour < 12)
            return "Good morning.\nSomething good is waiting."
        if (hour >= 12 && hour < 17)
            return "Good afternoon.\nHere’s a pick for right now."
        if (hour >= 17 && hour < 22)
            return "Good evening.\nYour next watch is ready."
        return "Still up?\nTater found something good."
    }

    onActiveFocusItemChanged: {
        var nextItem = root.activeFocusItem
        if (root.uiFocusSoundsArmed && !root.playbackOpen
                && nextItem && nextItem !== root.uiLastFocusItem)
            UiSounds.navigate()
        root.uiLastFocusItem = nextItem
    }

    function itemTitle(item, fallback) {
        return item && item.title ? item.title : fallback
    }

    function mediaLabel(item) {
        if (!item)
            return "MEDIA"
        var value = item.mediaType || item.type || "media"
        return String(value).toUpperCase()
    }

    function continueSubtitle(item) {
        if (!item)
            return ""
        if (item.sizeText)
            return item.sizeText
        if (item.durationDisplay)
            return "Resume • " + item.durationDisplay
        return "Resume playback"
    }

    function itemMeta(item) {
        if (!item)
            return ""
        var parts = []
        if (item.date)
            parts.push(item.date)
        if (item.category)
            parts.push(item.category)
        else if (item.sizeText)
            parts.push(item.sizeText)
        return parts.join("  •  ")
    }

    function progressValue(value) {
        var number = Number(value || 0) / 100.0
        return Math.max(0, Math.min(1, number))
    }

    function cardAccent(index) {
        var colors = ["#ef7423", "#547d8b", "#bd633d", "#6b5b7d", "#75864b", "#805a3d"]
        return colors[index % colors.length]
    }

    function channelNow(channel) {
        return channel && channel.now ? channel.now : null
    }

    function channelTitle(channel) {
        var now = channelNow(channel)
        return now && now.title ? now.title : itemTitle(channel, "Live channel")
    }

    function channelSubtitle(channel) {
        if (channel && channel.next && channel.next.title)
            return "Up next: " + channel.next.title
        return itemTitle(channel, "Tater Tube")
    }

    function localArtworkVariant(item, kind) {
        if (!item || !item.poster)
            return ""
        var poster = String(item.poster)
        if (poster.indexOf("/api/v1/player/artwork/local") < 0)
            return ""
        if (poster.match(/[?&]kind=[^&]*/))
            return poster.replace(/([?&])kind=[^&]*/, "$1kind=" + kind)
        return poster + (poster.indexOf("?") >= 0 ? "&" : "?") + "kind=" + kind
    }

    function homeWideArtwork(item) {
        if (!item)
            return ""
        return String(item.backdrop || localArtworkVariant(item, "backdrop")
                      || item.episodeStill || item.poster || "")
    }

    function homeArtworkFallback(item) {
        if (!item)
            return ""
        return String(item.episodeStill || item.seasonPoster
                      || item.seriesPoster || item.poster || "")
    }

    function homeChannelArtwork(channel) {
        if (!channel)
            return ""
        return homeWideArtwork(channel.now) || homeWideArtwork(channel.next)
    }

    function homeChannelArtworkFallback(channel) {
        if (!channel)
            return ""
        if (homeWideArtwork(channel.now).length > 0)
            return homeArtworkFallback(channel.now)
        return homeArtworkFallback(channel.next)
    }

    function libraryMediaItems() {
        if (demoMode) {
            return [
                {title: "Cosmic Drift", date: "2026", mediaType: "movie"},
                {title: "Harbor Street", date: "2024", mediaType: "series"},
                {title: "The Long Winter", date: "2025", mediaType: "movie"},
                {title: "Signal Lost", date: "2023", mediaType: "series"},
                {title: "Dust & Thunder", date: "2026", mediaType: "movie"},
                {title: "Side Streets", date: "2022", mediaType: "movie"}
            ]
        }
        return serverClient.recentlyAdded.length > 0
                ? serverClient.recentlyAdded : serverClient.continueWatching
    }

    function displayedLibraryItems() {
        if (demoMode)
            return libraryMediaItems()
        return serverClient.libraryDepth > 0
                ? serverClient.libraryItems : libraryMediaItems()
    }

    function libraryPageRows() {
        if (demoMode) {
            var demoItems = libraryMediaItems()
            return [
                {title: "Movies", entry: {id: "demo:movies", title: "Movies"},
                 items: demoItems.filter(function(item) { return item.mediaType === "movie" })},
                {title: "TV Shows", entry: {id: "demo:tv", title: "TV Shows"},
                 items: demoItems.filter(function(item) { return item.mediaType === "series" })}
            ]
        }
        if (serverClient.libraryRows.length > 0)
            return serverClient.libraryRows
        var recent = libraryMediaItems()
        return recent.length > 0
                ? [{title: "Recently added", entry: ({}), items: recent, loading: false}]
                : []
    }

    function libraryRowItems(row) {
        return row && row.items ? row.items : []
    }

    function libraryCollectionRow(kind) {
        var rows = libraryPageRows()
        var targetId = kind === "movies" ? "local-discover:movies"
                                          : "local-discover:series"
        var fallbackTitles = kind === "movies" ? ["movies"]
                                                : ["series", "tv shows"]
        for (var i = 0; i < rows.length; ++i) {
            var entry = rows[i] && rows[i].entry ? rows[i].entry : ({})
            if (String(entry.id || "").toLowerCase() === targetId)
                return rows[i]
        }
        for (var j = 0; j < rows.length; ++j) {
            var title = String(rows[j] && rows[j].title
                               ? rows[j].title : "").toLowerCase()
            if (fallbackTitles.indexOf(title) >= 0)
                return rows[j]
        }
        return null
    }

    function openLibraryCollection(kind) {
        var row = libraryCollectionRow(kind)
        if (row)
            openLibraryRow(row)
    }

    function openLibraryRow(row) {
        if (!row)
            return
        if (demoMode) {
            if (root.libraryRowItems(row).length > 0)
                root.openDetails(root.libraryRowItems(row)[0], root.mediaLabel(root.libraryRowItems(row)[0]))
            return
        }
        if (row.entry && (row.entry.id || row.entry.categoryId
                          || String(row.entry.type || "").toLowerCase() === "continue")) {
            libraryVisibleLimit = 60
            serverClient.browseLibrary(row.entry)
            sectionScroller.contentY = 0
        }
    }

    function libraryItemMeta(item) {
        if (!item)
            return ""
        if (demoMode)
            return itemMeta(item)
        if (!item.streamUrl)
            return String(item.sizeText || item.mediaType || "BROWSE").toUpperCase()
        return itemMeta(item)
    }

    function libraryBrowseStage() {
        if (demoMode || serverClient.libraryDepth === 0)
            return "root"
        var items = displayedLibraryItems()
        if (items.length === 0)
            return "generic"
        var type = String(items[0] && items[0].mediaType
                          ? items[0].mediaType : "").toLowerCase()
        if (type === "show")
            return "shows"
        if (type === "season")
            return "seasons"
        if (type === "episode")
            return "episodes"
        return "generic"
    }

    function libraryArtwork(items) {
        var rows = items || displayedLibraryItems()
        for (var i = 0; i < rows.length; ++i) {
            if (rows[i] && rows[i].poster)
                return rows[i].poster
            if (rows[i] && rows[i].resumeItem && rows[i].resumeItem.poster)
                return rows[i].resumeItem.poster
        }
        return ""
    }

    function librarySpecificArtwork(field, items) {
        var rows = items || displayedLibraryItems()
        for (var i = 0; i < rows.length; ++i) {
            if (rows[i] && rows[i][field])
                return rows[i][field]
            if (rows[i] && rows[i].resumeItem && rows[i].resumeItem[field])
                return rows[i].resumeItem[field]
        }
        return ""
    }

    function libraryBackdrop(items) {
        return librarySpecificArtwork("backdrop", items) || libraryArtwork(items)
    }

    function librarySeriesPoster(items) {
        return librarySpecificArtwork("seriesPoster", items) || libraryArtwork(items)
    }

    function librarySeasonPoster(items) {
        return librarySpecificArtwork("seasonPoster", items)
                || librarySeriesPoster(items)
                || libraryArtwork(items)
    }

    function libraryHeroArtwork(items) {
        var stage = libraryBrowseStage()
        return librarySpecificArtwork("backdrop", items)
                || (stage === "seasons"
                    ? librarySeriesPoster(items) : librarySeasonPoster(items))
    }

    function libraryResumeItem(items) {
        var rows = items || displayedLibraryItems()
        for (var i = 0; i < rows.length; ++i) {
            if (rows[i] && rows[i].resumeItem && rows[i].resumeItem.streamUrl)
                return rows[i].resumeItem
        }
        for (var j = 0; j < rows.length; ++j) {
            if (rows[j] && rows[j].streamUrl
                    && Number(rows[j].progressPercent || 0) > 0)
                return rows[j]
        }
        return null
    }

    function libraryEpisodeCount(items) {
        var rows = items || displayedLibraryItems()
        var count = 0
        for (var i = 0; i < rows.length; ++i)
            count += Number(rows[i] && rows[i].episodeCount ? rows[i].episodeCount : 0)
        return count
    }

    function showCardMeta(item) {
        if (!item)
            return "SHOW"
        if (item.resumeTitle)
            return "Continue " + item.resumeTitle
        var seasons = Number(item.seasonCount || 0)
        var episodes = Number(item.episodeCount || item.leafCount || 0)
        if (seasons > 0)
            return seasons + (seasons === 1 ? " season" : " seasons")
                    + (episodes > 0 ? "  •  " + episodes + " episodes" : "")
        if (episodes > 0)
            return episodes + (episodes === 1 ? " episode" : " episodes")
        return "SHOW"
    }

    function seasonCardMeta(item) {
        if (!item)
            return "SEASON"
        var episodes = Number(item.episodeCount || item.leafCount || 0)
        return episodes > 0
                ? episodes + (episodes === 1 ? " episode" : " episodes") : "Season"
    }

    function episodeCardMeta(item) {
        if (!item)
            return "EPISODE"
        var parts = ["EPISODE"]
        if (item.durationDisplay)
            parts.push(item.durationDisplay)
        if (Number(item.progressPercent || 0) > 0)
            parts.push("RESUME")
        return parts.join("  •  ")
    }

    function continueButtonText(item) {
        if (!item)
            return "▶  Continue"
        var title = itemTitle(item, "episode")
        var episodeCode = title.match(/S\d+E\d+/i)
        return episodeCode && episodeCode.length > 0
                ? "▶  Continue " + episodeCode[0].toUpperCase()
                : "▶  Continue episode"
    }

    function openLibraryEntry(item) {
        if (!item)
            return
        if (item.streamUrl) {
            openDetails(item, mediaLabel(item))
        } else if (!demoMode && (item.categoryId || item.path)) {
            libraryVisibleLimit = 60
            if (currentPage !== "library")
                showPage("library")
            serverClient.browseLibraryItem(item)
            sectionScroller.contentY = 0
        } else {
            openDetails(item, mediaLabel(item))
        }
    }

    function demoDiscoverCategories() {
        return [
            {id: "movie:top", title: "Popular Movies", detail: "MOVIE", category: "movie"},
            {id: "movie:year", title: "New Movies", detail: "THIS YEAR", category: "movie"},
            {id: "movie:imdbrating", title: "Featured Movies", detail: "MOVIE", category: "movie"},
            {id: "series:top", title: "Popular TV", detail: "TV", category: "series"},
            {id: "series:year", title: "New TV", detail: "THIS YEAR", category: "series"},
            {id: "series:imdbrating", title: "Featured TV", detail: "TV", category: "series"}
        ]
    }

    function displayedDiscoverCategories() {
        return demoMode ? demoDiscoverCategories() : serverClient.discoverCategories
    }

    function displayedDiscoverItems() {
        return demoMode ? libraryMediaItems() : serverClient.discoverItems
    }

    function openDiscoverCategory(category) {
        discoverVisibleLimit = 60
        if (demoMode) {
            if (libraryMediaItems().length > 0)
                openDetails(libraryMediaItems()[0], category.title || "DISCOVER")
            return
        }
        serverClient.browseDiscover(category)
        sectionScroller.contentY = 0
    }

    function activateDiscoverItem(item) {
        if (!item)
            return
        discoverVisibleLimit = 60
        if (demoMode) {
            openDetails(item, mediaLabel(item))
            return
        }
        returnFocusItem = root.activeFocusItem
        serverClient.activateDiscoverItem(item)
        sectionScroller.contentY = 0
    }

    function discoverItemMeta(item) {
        if (!item)
            return ""
        if (serverClient.discoverStage === "results")
            return item.sizeText || item.files || item.category || "NZB RESULT"
        if (serverClient.discoverStage === "streams")
            return "READY TO PLAY"
        return itemMeta(item) || item.sizeText || mediaLabel(item)
    }

    function demoLiveChannels() {
        return [{number: "12", title: "Saturday Cartoons",
                 streamUrl: "", guideElapsedSeconds: 45,
                 guideStartedAtMs: Date.now() - 45000,
                 schedule: [
                     {title: "Station ID", kind: "bumper", start: 30, end: 40},
                     {title: "Snack Attack", kind: "commercial", start: 40, end: 62},
                     {title: "Tater Tube", kind: "tater_bumper", start: 62, end: 72},
                     {title: "Galaxy Rangers", kind: "episode", start: 72, end: 1872},
                     {title: "Creature Features", kind: "movie", start: 1872, end: 7272}
                 ]},
                {number: "24", title: "Creature Features",
                 streamUrl: "", now: {title: "Night Visitors", progressPercent: 38},
                 next: {title: "Midnight Matinee"}, later: {title: "Shock Theater"}},
                {number: "88", title: "Neon Nights",
                 streamUrl: "", now: {title: "Electric Dreams", progressPercent: 52},
                 next: {title: "After Hours"}, later: {title: "Night Drive"}}]
    }

    function displayedLiveChannels() {
        if (demoMode)
            return demoLiveChannels()
        return serverClient.liveGuideChannels.length > 0
                ? serverClient.liveGuideChannels : serverClient.liveChannels
    }

    function isGuideInterstitial(program) {
        if (!program)
            return false
        var kind = String(program.kind || program.mediaType || "").toLowerCase()
        return kind === "commercial" || kind === "bumper" || kind === "tater_bumper"
    }

    function commercialBreakProgram(schedule, currentIndex, elapsed) {
        var first = currentIndex
        var last = currentIndex
        while (first > 0 && root.isGuideInterstitial(schedule[first - 1]))
            --first
        while (last + 1 < schedule.length
               && root.isGuideInterstitial(schedule[last + 1]))
            ++last

        var start = Number(schedule[first].start || 0)
        var end = Number(schedule[last].end || start)
        var progress = end > start ? ((elapsed - start) / (end - start)) * 100 : 0
        return {
            title: "Commercial Break",
            kind: "commercial_break",
            mediaType: "commercial_break",
            start: start,
            end: end,
            progressPercent: Math.max(0, Math.min(100, progress)),
            isCommercialBreak: true,
            breakItemCount: last - first + 1
        }
    }

    function currentGuideElapsed(channel) {
        var elapsed = Number(channel && channel.guideElapsedSeconds
                             ? channel.guideElapsedSeconds : 0)
        var measuredAt = Number(channel && channel.guideServerNowMs
                                ? channel.guideServerNowMs : 0)
        if (measuredAt > 0)
            elapsed += Math.max(0, (root.guideClockMs - measuredAt) / 1000)
        return elapsed
    }

    function guideProgramWithProgress(program, elapsed) {
        if (!program)
            return program
        var enriched = ({})
        for (var key in program)
            enriched[key] = program[key]
        var start = Number(program.start || 0)
        var end = Number(program.end || 0)
        if (end > start)
            enriched.progressPercent = Math.max(0, Math.min(100,
                ((elapsed - start) / (end - start)) * 100))
        return enriched
    }

    function guidePrograms(channel) {
        var programs = []
        if (!channel)
            return programs
        var schedule = channel.schedule || []
        var elapsed = root.currentGuideElapsed(channel)
        if (schedule.length > 0) {
            var currentIndex = -1
            var firstFutureIndex = schedule.length
            for (var i = 0; i < schedule.length; ++i) {
                var start = Number(schedule[i].start || 0)
                var end = Number(schedule[i].end || 0)
                if (start <= elapsed && elapsed < end) {
                    currentIndex = i
                    firstFutureIndex = i + 1
                    break
                }
                if (start > elapsed && firstFutureIndex === schedule.length)
                    firstFutureIndex = i
            }

            if (currentIndex >= 0) {
                var current = schedule[currentIndex]
                programs.push(root.isGuideInterstitial(current)
                              ? root.commercialBreakProgram(schedule, currentIndex, elapsed)
                              : root.guideProgramWithProgress(current, elapsed))
            }

            for (var j = firstFutureIndex;
                 j < schedule.length && programs.length < 3; ++j) {
                if (!root.isGuideInterstitial(schedule[j]))
                    programs.push(schedule[j])
            }
            return programs
        }

        if (channel.now) {
            if (root.isGuideInterstitial(channel.now)) {
                var fallbackBreak = ({})
                for (var key in channel.now)
                    fallbackBreak[key] = channel.now[key]
                fallbackBreak.title = "Commercial Break"
                fallbackBreak.kind = "commercial_break"
                fallbackBreak.mediaType = "commercial_break"
                fallbackBreak.isCommercialBreak = true
                programs.push(fallbackBreak)
            } else {
                programs.push(channel.now)
            }
        }
        if (programs.length < 3 && channel.next
                && !root.isGuideInterstitial(channel.next))
            programs.push(channel.next)
        if (programs.length < 3 && channel.later
                && !root.isGuideInterstitial(channel.later))
            programs.push(channel.later)
        return programs
    }

    function guideProgramIsCurrent(channel, program, index) {
        if (!program)
            return false
        if (program.start !== undefined && program.end !== undefined) {
            var elapsed = root.currentGuideElapsed(channel)
            return Number(program.start) <= elapsed && elapsed < Number(program.end)
        }
        return index === 0
    }

    function guideProgramTime(channel, program, index) {
        if (root.guideProgramIsCurrent(channel, program, index))
            return "NOW"
        if (channel && channel.guideStartedAtMs && program
                && program.start !== undefined) {
            var startsAt = new Date(Number(channel.guideStartedAtMs)
                                    + Number(program.start) * 1000)
            return Qt.formatTime(startsAt, "h:mm AP")
        }
        if (program && program.startsAt)
            return Qt.formatTime(new Date(program.startsAt), "h:mm AP")
        return index === 1 ? "UP NEXT" : "LATER"
    }

    function guideProgramMeta(channel, program) {
        if (!program)
            return "TATER TUBE"
        if (program.isCommercialBreak === true) {
            var duration = Math.max(1, Math.ceil((Number(program.end || 0)
                                                  - Number(program.start || 0)) / 60))
            if (channel && channel.guideStartedAtMs && program.end !== undefined) {
                var endsAt = new Date(Number(channel.guideStartedAtMs)
                                      + Number(program.end) * 1000)
                return "BACK AT " + Qt.formatTime(endsAt, "h:mm AP")
                        + "  •  " + duration + " MIN BREAK"
            }
            return duration + " MIN BREAK"
        }
        var kind = String(program.mediaType || program.kind || "PROGRAM").toUpperCase()
        if (program.start !== undefined && program.end !== undefined) {
            var minutes = Math.max(1, Math.round((Number(program.end) - Number(program.start)) / 60))
            return kind + "  •  " + minutes + " MIN"
        }
        return kind
    }

    function guideCardArtwork(programs, index) {
        if (!programs || index < 0 || index >= programs.length)
            return ""
        var artwork = root.homeWideArtwork(programs[index])
        if (artwork.length > 0)
            return artwork
        for (var nextIndex = index + 1; nextIndex < programs.length; ++nextIndex) {
            artwork = root.homeWideArtwork(programs[nextIndex])
            if (artwork.length > 0)
                return artwork
        }
        return ""
    }

    function guideCardArtworkFallback(programs, index) {
        if (!programs || index < 0 || index >= programs.length)
            return ""
        if (root.homeWideArtwork(programs[index]).length > 0)
            return root.homeArtworkFallback(programs[index])
        for (var nextIndex = index + 1; nextIndex < programs.length; ++nextIndex) {
            if (root.homeWideArtwork(programs[nextIndex]).length > 0)
                return root.homeArtworkFallback(programs[nextIndex])
        }
        return ""
    }

    function activateGuideProgram(channel, program, index) {
        if (root.guideProgramIsCurrent(channel, program, index)
                && channel && channel.streamUrl) {
            root.startPlayback(channel, "CHANNEL " + channel.number)
            return
        }
        var details = ({})
        if (program) {
            for (var key in program)
                details[key] = program[key]
        }
        details.title = root.itemTitle(program, root.itemTitle(channel, "Tater Tube"))
        details.description = "Airs " + root.guideProgramTime(channel, program, index)
                + " on channel " + channel.number + "."
        root.openDetails(details, "GUIDE")
    }

    function searchableMediaItems() {
        var items = []
        var source = libraryMediaItems()
        for (var i = 0; i < source.length; ++i)
            items.push(source[i])
        for (var j = 0; j < serverClient.continueWatching.length; ++j) {
            var candidate = serverClient.continueWatching[j]
            var found = false
            for (var k = 0; k < items.length; ++k) {
                if (itemTitle(items[k], "") === itemTitle(candidate, "")) {
                    found = true
                    break
                }
            }
            if (!found)
                items.push(candidate)
        }
        return items
    }

    function filteredMediaItems(query) {
        var items = searchableMediaItems()
        var needle = String(query || "").trim().toLowerCase()
        if (needle.length === 0)
            return items
        var matches = []
        for (var i = 0; i < items.length; ++i) {
            var haystack = [items[i].title, items[i].artist, items[i].album,
                            items[i].genre, items[i].category].join(" ").toLowerCase()
            if (haystack.indexOf(needle) >= 0)
                matches.push(items[i])
        }
        return matches
    }

    function showPage(name) {
        sideMenuOpen = false
        sideMenuReturnFocus = null
        detailsOpen = false
        currentPage = name
        page.contentY = 0
        sectionScroller.contentY = 0
        if (name === "home" && !demoMode)
            serverClient.refreshHome()
        if (name === "library" && !demoMode) {
            if (serverClient.libraryDepth > 0)
                serverClient.refreshLibrary()
            else {
                serverClient.refreshLibraries()
                serverClient.refreshLibraryRows()
            }
        }
        if (name === "discover" && !demoMode)
            serverClient.refreshDiscover()
        if (name === "live" && !demoMode)
            serverClient.refreshLiveGuide()
        if (name === "search" && !demoMode)
            serverClient.refreshHome()
        if (name === "live")
            guideClockMs = Date.now()
        Qt.callLater(function() {
            if (name === "home")
                heroWatchLive.forceActiveFocus()
            else
                root.focusFirstSectionControl()
        })
    }

    function openSideMenu() {
        if (sideMenuOpen || playbackOpen || detailsOpen || pairingOverlay.visible)
            return false
        sideMenuReturnFocus = root.activeFocusItem
        sideMenuOpen = true
        Qt.callLater(function() {
            if (currentPage === "library")
                sideLibraryNav.forceActiveFocus()
            else if (currentPage === "discover")
                sideDiscoverNav.forceActiveFocus()
            else if (currentPage === "live")
                sideLiveNav.forceActiveFocus()
            else if (currentPage === "search")
                sideSearchNav.forceActiveFocus()
            else
                sideHomeNav.forceActiveFocus()
        })
        return true
    }

    function closeSideMenu(restoreFocus) {
        if (!sideMenuOpen)
            return false
        var target = sideMenuReturnFocus
        sideMenuOpen = false
        sideMenuReturnFocus = null
        if (restoreFocus) {
            Qt.callLater(function() {
                if (target && target.visible && target.enabled)
                    target.forceActiveFocus()
                else if (currentPage === "home")
                    heroWatchLive.forceActiveFocus()
                else
                    root.focusFirstSectionControl()
            })
        }
        return true
    }

    function playbackTitle() {
        if (playbackIsLive)
            return channelTitle(playbackItem)
        return itemTitle(playbackItem, "Tater Tube")
    }

    function playbackDurationMs() {
        var seconds = Number(playbackItem && playbackItem.durationSeconds
                             ? playbackItem.durationSeconds : 0)
        if (seconds <= 0 && playbackItem && playbackItem.duration)
            seconds = Number(playbackItem.duration)
        if (seconds > 0)
            return seconds * 1000
        return Math.max(0, Number(mediaPlayer.duration || 0) + playbackBaseOffsetMs)
    }

    function playbackPositionMs() {
        return Math.max(0, Number(mediaPlayer.position || 0) + playbackBaseOffsetMs)
    }

    function formatPlaybackTime(milliseconds) {
        var total = Math.max(0, Math.floor(Number(milliseconds || 0) / 1000))
        var hours = Math.floor(total / 3600)
        var minutes = Math.floor((total % 3600) / 60)
        var seconds = total % 60
        if (hours > 0)
            return hours + ":" + String(minutes).padStart(2, "0")
                    + ":" + String(seconds).padStart(2, "0")
        return minutes + ":" + String(seconds).padStart(2, "0")
    }

    function showPlaybackControls() {
        playbackControlsVisible = true
        if (mediaPlayer.playbackState === MediaPlayer.PlayingState)
            playbackControlsTimer.restart()
    }

    function startPlayback(item, kind) {
        if (!item)
            return
        var source = String(item.streamUrl || "").trim()
        if (source.length === 0)
            return

        mediaPlayer.stop()
        playbackHasVideoFrame = false
        playbackItem = item
        playbackIsLive = String(kind || "").indexOf("CHANNEL") === 0
        playbackSourceUrl = source
        playbackPlanUrl = ""
        playbackSourceVideoRange = "sdr"
        playbackUsingFallback = false
        playbackUsingAudioTranscode = false
        playbackUsingVideoTranscode = false
        playbackPlanPending = false
        playbackAudioCodec = ""
        playbackAudioMode = "direct"
        playbackBaseOffsetMs = 0
        playbackPendingResumeMs = playbackIsLive ? 0 : Number(item.viewOffset || 0)
        if (playbackPendingResumeMs <= 0 && item.viewOffsetSeconds)
            playbackPendingResumeMs = Number(item.viewOffsetSeconds) * 1000
        playbackError = ""
        playbackStatusMessage = playbackIsLive ? "Tuning your channel…" : "Opening your media…"
        playbackQuality = playbackIsLive ? "Live HLS" : "Direct play"
        playbackEnded = false
        playbackControlsVisible = true
        detailsOpen = false
        playbackOpen = true
        if (playbackIsLive) {
            mediaPlayer.source = source
            mediaPlayer.play()
            playbackControlsTimer.restart()
        } else if (serverClient.paired) {
            playbackPlanPending = true
            playbackStatusMessage = "Matching playback to this screen…"
            playbackQuality = "Choosing best quality"
            serverClient.preparePlayback(item, kind || mediaLabel(item),
                                         playbackCapabilities.report)
        } else {
            applyLegacyPlaybackPlan()
        }
    }

    function applyLegacyPlaybackPlan() {
        playbackPlanPending = false
        playbackUsingFallback = false
        playbackUsingVideoTranscode = false
        playbackPlanUrl = ""
        playbackSourceVideoRange = "sdr"
        if (compatiblePlayback) {
            playbackUsingAudioTranscode = true
            playbackBaseOffsetMs = Math.max(0, playbackPendingResumeMs)
            playbackPendingResumeMs = 0
            playbackStatusMessage = "Preparing compatible audio…"
            playbackQuality = "Video Direct • Audio AAC"
            mediaPlayer.source = serverClient.playbackAudioTranscodeUrl(
                        playbackSourceUrl, "hdmi_1080p", Math.round(playbackBaseOffsetMs))
        } else {
            playbackUsingAudioTranscode = false
            mediaPlayer.source = playbackSourceUrl
        }
        mediaPlayer.play()
        playbackControlsTimer.restart()
    }

    function applyPlaybackPlan(plan) {
        if (!playbackOpen || !plan)
            return
        var plannedUrl = String(plan.stream_url || "").trim()
        if (plannedUrl.length === 0) {
            applyLegacyPlaybackPlan()
            return
        }

        var mode = String(plan.mode || "direct")
        var resumeAt = Math.max(0, playbackPendingResumeMs)
        playbackPlanPending = false
        playbackUsingFallback = mode === "full_transcode"
        playbackUsingAudioTranscode = mode === "audio_transcode"
        playbackUsingVideoTranscode = mode === "video_transcode"
        playbackAudioCodec = String(plan.source && plan.source.audio_codec
                                    ? plan.source.audio_codec
                                    : plan.audio_codec || "")
        playbackAudioMode = String(plan.audio_mode || "direct")
        playbackPlanUrl = plannedUrl
        playbackSourceVideoRange = String(plan.source_video_range
                                          || (plan.source && plan.source.video_range)
                                          || "sdr")
        playbackQuality = String(plan.quality_label || "Direct play")
        playbackError = ""
        playbackHasVideoFrame = false

        if (playbackUsingFallback) {
            playbackBaseOffsetMs = resumeAt
            playbackPendingResumeMs = 0
            playbackStatusMessage = "Optimizing video and audio…"
            mediaPlayer.source = serverClient.playbackUrlAtPosition(
                        playbackPlanUrl, Math.round(resumeAt))
        } else if (playbackUsingAudioTranscode) {
            playbackBaseOffsetMs = resumeAt
            playbackPendingResumeMs = 0
            playbackStatusMessage = "Preparing compatible audio…"
            mediaPlayer.source = serverClient.playbackUrlAtPosition(
                        playbackPlanUrl, Math.round(resumeAt))
        } else if (playbackUsingVideoTranscode) {
            playbackBaseOffsetMs = resumeAt
            playbackPendingResumeMs = 0
            playbackStatusMessage = "Optimizing video and preserving audio…"
            mediaPlayer.source = serverClient.playbackUrlAtPosition(
                        playbackPlanUrl, Math.round(resumeAt))
        } else {
            playbackBaseOffsetMs = 0
            playbackStatusMessage = String(plan.audio_mode || "") === "bitstream"
                    ? "Sending original audio to your sound system…"
                    : "Opening your media…"
            mediaPlayer.source = plannedUrl
        }
        mediaPlayer.play()
        playbackControlsTimer.restart()
    }

    function savePlaybackState(completed) {
        if (!playbackOpen || playbackIsLive || !playbackItem)
            return
        serverClient.savePlaybackProgress(playbackItem,
                                          Math.round(playbackPositionMs()),
                                          Math.round(playbackDurationMs()),
                                          completed === true)
    }

    function closePlayback() {
        if (!playbackOpen)
            return
        if (!playbackEnded)
            savePlaybackState(false)
        mediaPlayer.stop()
        playbackOpen = false
        playbackPlanPending = false
        playbackHasVideoFrame = false
        playbackError = ""
        playbackStatusMessage = ""
        var target = returnFocusItem
        returnFocusItem = null
        if (target && target.visible)
            Qt.callLater(function() { target.forceActiveFocus() })
        else
            Qt.callLater(function() { heroWatchLive.forceActiveFocus() })
    }

    function retryWithCompatibleStream(reason) {
        if (playbackIsLive || playbackUsingFallback || playbackSourceUrl.length === 0)
            return false

        var resumeAt = Math.max(playbackPendingResumeMs, playbackPositionMs())
        playbackUsingFallback = true
        playbackUsingAudioTranscode = false
        playbackUsingVideoTranscode = false
        playbackBaseOffsetMs = resumeAt
        playbackPendingResumeMs = 0
        playbackError = ""
        playbackStatusMessage = "Optimizing video and audio for your Steam Deck…"
        playbackQuality = "Video H.264 • Audio AAC"
        playbackHasVideoFrame = false
        mediaPlayer.stop()
        var fallbackBase = playbackPlanUrl.length > 0
                ? playbackPlanUrl : playbackSourceUrl
        if (playbackSourceVideoRange.length > 0
                && playbackSourceVideoRange !== "sdr") {
            playbackPlanUrl = serverClient.playbackToneMappedTranscodeUrl(
                        fallbackBase, "hdmi_1080p",
                        playbackSourceVideoRange, 0)
        } else {
            playbackPlanUrl = serverClient.playbackTranscodeUrl(
                        fallbackBase, "hdmi_1080p", 0)
        }
        mediaPlayer.source = serverClient.playbackUrlAtPosition(
                    playbackPlanUrl, Math.round(resumeAt))
        Qt.callLater(function() { mediaPlayer.play() })
        return true
    }

    function togglePlayback() {
        if (!playbackOpen || playbackError.length > 0)
            return
        playbackEnded = false
        if (mediaPlayer.playbackState === MediaPlayer.PlayingState)
            mediaPlayer.pause()
        else
            mediaPlayer.play()
        showPlaybackControls()
    }

    function seekPlayback(targetMs) {
        if (!playbackOpen || playbackIsLive)
            return
        var duration = playbackDurationMs()
        var target = Math.max(0, Math.min(duration > 0 ? duration - 1000 : targetMs,
                                          Number(targetMs)))
        playbackEnded = false
        if (playbackPlanUrl.length > 0
                && (playbackUsingFallback || playbackUsingAudioTranscode
                    || playbackUsingVideoTranscode)) {
            playbackBaseOffsetMs = target
            playbackStatusMessage = "Seeking…"
            playbackHasVideoFrame = false
            mediaPlayer.stop()
            mediaPlayer.source = serverClient.playbackUrlAtPosition(
                        playbackPlanUrl, Math.round(target))
            Qt.callLater(function() { mediaPlayer.play() })
        } else if (playbackUsingAudioTranscode) {
            playbackBaseOffsetMs = target
            playbackStatusMessage = "Seeking…"
            playbackHasVideoFrame = false
            mediaPlayer.stop()
            mediaPlayer.source = serverClient.playbackAudioTranscodeUrl(
                        playbackSourceUrl, "hdmi_1080p", Math.round(target))
            Qt.callLater(function() { mediaPlayer.play() })
        } else if (playbackUsingVideoTranscode) {
            playbackBaseOffsetMs = target
            playbackStatusMessage = "Seeking…"
            playbackHasVideoFrame = false
            mediaPlayer.stop()
            mediaPlayer.source = serverClient.playbackVideoTranscodeUrl(
                        playbackSourceUrl, "hdmi_1080p", playbackAudioCodec,
                        playbackAudioMode,
                        Math.round(target))
            Qt.callLater(function() { mediaPlayer.play() })
        } else {
            mediaPlayer.setPosition(Math.round(target))
        }
        showPlaybackControls()
    }

    function seekPlaybackBy(deltaMs) {
        seekPlayback(playbackPositionMs() + deltaMs)
    }

    function changePlaybackVolume(delta) {
        playerAudio.volume = Math.max(0, Math.min(1, playerAudio.volume + delta))
        playerAudio.muted = false
        showPlaybackControls()
    }

    function selectPlaybackAudioTrack() {
        if (mediaPlayer.audioTracks.length > 0 && mediaPlayer.activeAudioTrack < 0)
            mediaPlayer.activeAudioTrack = 0
        playerAudio.muted = false
    }

    function openDetails(item, kind) {
        if (!item)
            return
        returnFocusItem = root.activeFocusItem
        selectedItem = item
        selectedKind = kind || mediaLabel(item)
        detailsOpen = true
        Qt.callLater(function() { detailsPlay.forceActiveFocus() })
    }

    function closeDetails() {
        detailsOpen = false
        var target = returnFocusItem
        returnFocusItem = null
        if (target && target.visible)
            Qt.callLater(function() { target.forceActiveFocus() })
    }

    function goBack() {
        if (sideMenuOpen) {
            closeSideMenu(true)
        } else if (playbackOpen) {
            closePlayback()
        } else if (detailsOpen) {
            closeDetails()
        } else if (currentPage === "library" && !demoMode
                   && serverClient.libraryDepth > 0) {
            libraryVisibleLimit = 60
            serverClient.browseLibraryBack()
            sectionScroller.contentY = 0
        } else if (currentPage === "discover" && !demoMode
                   && serverClient.discoverStage !== "catalog") {
            discoverVisibleLimit = 60
            serverClient.browseDiscoverBack()
            sectionScroller.contentY = 0
        } else if (currentPage !== "home") {
            showPage("home")
        } else {
            openSideMenu()
        }
    }

    function appendFocusable(node, result) {
        if (!node || !node.visible || !node.enabled)
            return
        if (node.activeFocusOnTab === true && node.width > 0 && node.height > 0)
            result.push(node)
        var children = node.children || []
        for (var i = 0; i < children.length; ++i)
            appendFocusable(children[i], result)
    }

    function focusableItems() {
        var result = []
        if (pairingOverlay.visible) {
            appendFocusable(pairingOverlay, result)
        } else if (detailsOpen) {
            appendFocusable(detailsPanel, result)
        } else if (sideMenuOpen) {
            appendFocusable(sideMenu, result)
        } else {
            appendFocusable(currentPage === "home" ? page.contentItem
                                                    : sectionScroller.contentItem, result)
        }
        return result
    }

    function isDescendant(item, ancestor) {
        var candidate = item
        while (candidate) {
            if (candidate === ancestor)
                return true
            candidate = candidate.parent
        }
        return false
    }

    function isItemShown(item) {
        var candidate = item
        while (candidate) {
            if (candidate.visible === false || candidate.enabled === false)
                return false
            if (candidate === root)
                break
            candidate = candidate.parent
        }
        return true
    }

    function revealFocusedItem(item) {
        var scroller = currentPage === "home" ? page : sectionScroller
        if (!isDescendant(item, scroller.contentItem))
            return
        if (currentPage === "home" && isDescendant(item, hero)) {
            scroller.contentY = 0
            return
        }
        var point = item.mapToItem(scroller.contentItem, 0, 0)
        var upper = scroller.contentY + 24
        var lower = scroller.contentY + scroller.height - 30
        if (point.y < upper)
            scroller.contentY = Math.max(0, point.y - 24)
        else if (point.y + item.height > lower)
            scroller.contentY = Math.min(scroller.contentHeight - scroller.height,
                                         point.y + item.height - scroller.height + 30)
    }

    function focusFirstSectionControl() {
        if (currentPage === "library" && serverClient.libraryDepth === 0
                && libraryAllMovies.visible && libraryAllMovies.enabled) {
            libraryAllMovies.forceActiveFocus()
            revealFocusedItem(libraryAllMovies)
            return
        }
        if (currentPage === "library" && serverClient.libraryDepth > 0
                && tvContinueButton.visible && tvContinueButton.enabled) {
            tvContinueButton.forceActiveFocus()
            revealFocusedItem(tvContinueButton)
            return
        }
        var candidates = focusableItems()
        for (var i = 0; i < candidates.length; ++i) {
            if (isDescendant(candidates[i], sectionScroller.contentItem)) {
                candidates[i].forceActiveFocus()
                revealFocusedItem(candidates[i])
                return
            }
        }
    }

    function moveFocus(horizontal, vertical) {
        var candidates = focusableItems()
        if (candidates.length === 0)
            return false
        var current = root.activeFocusItem
        var currentIndex = candidates.indexOf(current)
        if (currentIndex < 0) {
            candidates[0].forceActiveFocus()
            revealFocusedItem(candidates[0])
            return true
        }

        var origin = current.mapToItem(root.contentItem, current.width / 2, current.height / 2)
        var currentTop = origin.y - current.height / 2
        var currentBottom = origin.y + current.height / 2
        var winner = null
        var winnerScore = Number.MAX_VALUE
        for (var i = 0; i < candidates.length; ++i) {
            var candidate = candidates[i]
            if (candidate === current)
                continue
            var point = candidate.mapToItem(root.contentItem,
                                            candidate.width / 2, candidate.height / 2)
            var dx = point.x - origin.x
            var dy = point.y - origin.y
            if ((horizontal < 0 && dx >= -4) || (horizontal > 0 && dx <= 4)
                    || (vertical < 0 && dy >= -4) || (vertical > 0 && dy <= 4))
                continue
            if (horizontal !== 0) {
                var candidateTop = point.y - candidate.height / 2
                var candidateBottom = point.y + candidate.height / 2
                var verticalGap = Math.max(0, Math.max(currentTop, candidateTop)
                                              - Math.min(currentBottom, candidateBottom))
                if (verticalGap > 18)
                    continue
            }
            var primary = horizontal !== 0 ? Math.abs(dx) : Math.abs(dy)
            var cross = horizontal !== 0 ? Math.abs(dy) : Math.abs(dx)
            var score = primary + cross * 2.4
            if (score < winnerScore) {
                winner = candidate
                winnerScore = score
            }
        }
        if (winner) {
            winner.forceActiveFocus()
            revealFocusedItem(winner)
            return true
        }
        return false
    }

    function navigateLeft() {
        if (sideMenuOpen)
            return
        if (!moveFocus(-1, 0))
            openSideMenu()
    }

    function navigateRight() {
        if (sideMenuOpen) {
            UiSounds.back()
            closeSideMenu(true)
            return
        }
        moveFocus(1, 0)
    }

    function activateFocusedItem() {
        var item = root.activeFocusItem
        if (!item)
            return
        if (typeof item.activate === "function") {
            item.activate()
        } else if (item === serverField || item === pinField || item === searchField) {
            item.forceActiveFocus()
            Qt.inputMethod.show()
        }
    }

    Component.onCompleted: {
        if (String(playbackPreviewUrl || "").length > 0) {
            returnFocusItem = heroWatchLive
            startPlayback({title: "Playback preview", mediaType: "video",
                              streamUrl: playbackPreviewUrl}, "VIDEO")
        } else if (pairingOverlay.visible)
            serverField.forceActiveFocus()
        else
            heroWatchLive.forceActiveFocus()
    }

    Timer {
        interval: 450
        running: true
        repeat: false
        onTriggered: {
            root.uiLastFocusItem = root.activeFocusItem
            root.uiFocusSoundsArmed = true
        }
    }

    Timer {
        interval: 1000
        running: root.currentPage === "live" && !root.playbackOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: root.guideClockMs = Date.now()
    }

    Connections {
        target: gamepadInput
        function onNavigateLeft() {
            if (root.playbackOpen) root.seekPlaybackBy(-10000)
            else root.navigateLeft()
        }
        function onNavigateRight() {
            if (root.playbackOpen) root.seekPlaybackBy(10000)
            else root.navigateRight()
        }
        function onNavigateUp() {
            if (root.playbackOpen) root.changePlaybackVolume(0.05)
            else root.moveFocus(0, -1)
        }
        function onNavigateDown() {
            if (root.playbackOpen) root.changePlaybackVolume(-0.05)
            else root.moveFocus(0, 1)
        }
        function onAccept() {
            if (root.playbackOpen) root.togglePlayback()
            else root.activateFocusedItem()
        }
        function onBack() {
            UiSounds.back()
            root.goBack()
        }
    }

    Connections {
        target: serverClient
        function onLibraryChanged() {
            sectionPage.syncLibraryArtwork()
            var current = root.activeFocusItem
            if (root.currentPage === "library" && !serverClient.libraryLoading
                    && (!current || !root.isItemShown(current)
                        || !root.isDescendant(current, sectionScroller.contentItem))) {
                Qt.callLater(function() { root.focusFirstSectionControl() })
            }
        }

        function onDiscoverChanged() {
            var current = root.activeFocusItem
            if (root.currentPage === "discover" && !serverClient.discoverLoading
                    && (!current || !root.isItemShown(current)
                        || !root.isDescendant(current, sectionScroller.contentItem))) {
                Qt.callLater(function() { root.focusFirstSectionControl() })
            }
        }

        function onDiscoverPlaybackReady(item) {
            root.startPlayback(item, root.mediaLabel(item))
        }

        function onPlaybackPlanReady(plan) {
            root.applyPlaybackPlan(plan)
        }

        function onPlaybackPlanFailed(message) {
            if (root.playbackOpen && root.playbackPlanPending)
                root.applyLegacyPlaybackPlan()
        }
    }

    Shortcut { sequence: "Left"; onActivated: root.playbackOpen ? root.seekPlaybackBy(-10000) : root.navigateLeft() }
    Shortcut { sequence: "Right"; onActivated: root.playbackOpen ? root.seekPlaybackBy(10000) : root.navigateRight() }
    Shortcut { sequence: "Up"; onActivated: root.playbackOpen ? root.changePlaybackVolume(0.05) : root.moveFocus(0, -1) }
    Shortcut { sequence: "Down"; onActivated: root.playbackOpen ? root.changePlaybackVolume(-0.05) : root.moveFocus(0, 1) }
    Shortcut {
        sequence: "Esc"
        onActivated: {
            UiSounds.back()
            root.goBack()
        }
    }
    Shortcut { sequence: "Space"; enabled: root.playbackOpen; onActivated: root.togglePlayback() }

    onClosing: function(close) {
        if (root.playbackOpen && !root.playbackEnded)
            root.savePlaybackState(false)
    }

    Rectangle {
        anchors.fill: parent
        color: root.color

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#171a1e" }
            GradientStop { position: 0.52; color: "#111316" }
            GradientStop { position: 1.0; color: "#0c0e10" }
        }
    }

    Flickable {
        id: page
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contentHeight: contentColumn.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            background: Item {}
            contentItem: Rectangle { radius: 2; color: "#70575c61" }
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 46
            anchors.rightMargin: 46
            anchors.top: parent.top
            anchors.topMargin: 30
            spacing: 28

            Rectangle {
                id: hero
                width: contentColumn.width
                height: 304
                radius: 28
                clip: true
                color: root.panel
                border.width: 1
                border.color: "#3b3f44"

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#29190f" }
                    GradientStop { position: 0.52; color: "#1c1f23" }
                    GradientStop { position: 1.0; color: "#090b0d" }
                }

                Image {
                    anchors.fill: parent
                    source: "../assets/tater-scanlines.png"
                    fillMode: Image.Tile
                    opacity: 0.3
                }

                Rectangle {
                    width: 520
                    height: 520
                    radius: 260
                    anchors.right: parent.right
                    anchors.rightMargin: -95
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#12ff781f"
                    border.width: 74
                    border.color: "#13ff8a3d"
                }

                Rectangle {
                    width: 280
                    height: 280
                    radius: 140
                    anchors.right: parent.right
                    anchors.rightMargin: 120
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#1617191d"
                    border.width: 1
                    border.color: "#3aff9a58"
                }

                Image {
                    anchors.right: parent.right
                    anchors.rightMargin: 82
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 340
                    height: 292
                    source: "../assets/mascot/tater-hero-remote.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(720, parent.width - 480)
                    spacing: 13

                    Row {
                        spacing: 10

                        Rectangle {
                            width: 9
                            height: 9
                            radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.orange
                        }

                        Text {
                            text: root.hasPersonalizedHero()
                                  ? String(serverClient.homeHero.eyebrow
                                           || "TATER LINK  •  PICKED FOR YOU")
                                  : "WELCOME TO TATER TUBE"
                            color: root.orangeBright
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                        }
                    }

                    Text {
                        text: root.hasPersonalizedHero()
                              ? root.personalizedHeroHeadline()
                              : "Everything good,\nright where you left it."
                        color: root.textPrimary
                        font.pixelSize: 38
                        font.weight: Font.Black
                        lineHeight: 0.94
                    }

                    Text {
                        width: parent.width
                        text: root.hasPersonalizedHero()
                              ? String(serverClient.homeHero.message)
                              : "Movies, shows, and your own live channels—served privately from Tater Tube Server."
                        color: "#c4c6c8"
                        font.pixelSize: 16
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Row {
                        topPadding: 7
                        spacing: 12

                        FocusButton {
                            id: heroWatchLive
                            text: "▶  Watch live"
                            primary: true
                            onClicked: root.showPage("live")
                        }
                        FocusButton {
                            text: "Browse library"
                            onClicked: root.showPage("library")
                        }
                        FocusButton {
                            visible: demoMode || !!serverClient.capabilities.newznab
                            text: "Discover"
                            onClicked: root.showPage("discover")
                        }
                    }
                }
            }

            Rectangle {
                visible: !demoMode && serverClient.homeReady
                         && serverClient.homeWarnings.length > 0
                width: contentColumn.width
                height: 48
                radius: 14
                color: "#28231f"
                border.width: 1
                border.color: "#65462f"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tater Tube Server: " + serverClient.homeWarnings[0]
                    color: "#e4c4ab"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: demoMode

                SectionTitle {
                    width: parent.width
                    title: "Continue watching"
                    actionText: "SEE ALL  ›"
                    actionEnabled: true
                    onActionActivated: root.showPage("library")
                }

                Row {
                    width: parent.width
                    spacing: 15

                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "MOVIE  •  42 MIN LEFT"
                        title: "The Last Signal"
                        subtitle: "Resume from 01:16:08"
                        accent: "#f27822"
                        progress: 0.58
                        onActivated: root.openDetails({title: title, mediaType: "movie",
                                                        description: subtitle}, "MOVIE")
                    }
                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "S2  E4"
                        title: "Northern Lights"
                        subtitle: "The Long Way Home"
                        accent: "#547d8b"
                        progress: 0.31
                        onActivated: root.openDetails({title: title, mediaType: "episode",
                                                        description: subtitle}, "EPISODE")
                    }
                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "MOVIE  •  18 MIN LEFT"
                        title: "Orange County Skies"
                        subtitle: "Resume from 01:34:22"
                        accent: "#bd633d"
                        progress: 0.81
                        onActivated: root.openDetails({title: title, mediaType: "movie",
                                                        description: subtitle}, "MOVIE")
                    }
                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "S1  E7"
                        title: "After Midnight"
                        subtitle: "Static in the Valley"
                        accent: "#6b5b7d"
                        progress: 0.46
                        onActivated: root.openDetails({title: title, mediaType: "episode",
                                                        description: subtitle}, "EPISODE")
                    }
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: !demoMode && serverClient.homeReady
                         && serverClient.continueWatching.length > 0

                SectionTitle {
                    width: parent.width
                    title: "Continue watching"
                    actionText: "SEE ALL  ›"
                    actionEnabled: true
                    onActionActivated: root.showPage("library")
                }

                Row {
                    width: parent.width
                    spacing: 15

                    Repeater {
                        model: Math.min(4, serverClient.continueWatching.length)

                        MediaCard {
                            required property int index
                            property var media: serverClient.continueWatching[index]

                            width: (parent.width - 45) / 4
                            eyebrow: root.mediaLabel(media)
                            title: root.itemTitle(media, "Untitled")
                            subtitle: root.continueSubtitle(media)
                            artSource: root.homeWideArtwork(media)
                            fallbackArtSource: root.homeArtworkFallback(media)
                            artworkOpacity: 0.74
                            accent: root.cardAccent(index)
                            progress: root.progressValue(media ? media.progressPercent : 0)
                            onActivated: root.openDetails(media, root.mediaLabel(media))
                        }
                    }
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: demoMode

                SectionTitle {
                    width: parent.width
                    title: "Live on Tater Tube"
                    actionText: "OPEN GUIDE  ›"
                    actionEnabled: true
                    onActionActivated: root.showPage("live")
                }

                Row {
                    width: parent.width
                    spacing: 15

                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "CH 12  •  LIVE"
                        title: "Saturday Cartoons"
                        subtitle: "Up next: Galaxy Rangers"
                        badge: "12"
                        accent: "#ef7423"
                        progress: 0.67
                        onActivated: root.showPage("live")
                    }
                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "CH 24  •  LIVE"
                        title: "Creature Features"
                        subtitle: "Up next: Night Visitors"
                        badge: "24"
                        accent: "#75864b"
                        progress: 0.38
                        onActivated: root.showPage("live")
                    }
                    MediaCard {
                        width: (parent.width - 45) / 4
                        eyebrow: "CH 88  •  LIVE"
                        title: "Neon Nights"
                        subtitle: "Up next: Electric Dreams"
                        badge: "88"
                        accent: "#6a597d"
                        progress: 0.52
                        onActivated: root.showPage("live")
                    }
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: !demoMode && serverClient.homeReady
                         && serverClient.liveChannels.length > 0

                SectionTitle {
                    width: parent.width
                    title: "Live on Tater Tube"
                    actionText: "OPEN GUIDE  ›"
                    actionEnabled: true
                    onActionActivated: root.showPage("live")
                }

                Row {
                    width: parent.width
                    spacing: 15

                    Repeater {
                        model: Math.min(4, serverClient.liveChannels.length)

                        MediaCard {
                            required property int index
                            property var channel: serverClient.liveChannels[index]
                            property var currentProgram: root.channelNow(channel)

                            width: (parent.width - 45) / 4
                            eyebrow: "CH " + channel.number + "  •  LIVE"
                            title: root.channelTitle(channel)
                            subtitle: root.channelSubtitle(channel)
                            badge: channel.number || "TV"
                            artSource: root.homeChannelArtwork(channel)
                            fallbackArtSource: root.homeChannelArtworkFallback(channel)
                            artworkOpacity: 0.74
                            accent: root.cardAccent(index)
                            progress: root.progressValue(currentProgram
                                                         ? currentProgram.progressPercent : 0)
                            onActivated: root.openDetails(channel, "CHANNEL " + channel.number)
                        }
                    }
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: demoMode

                SectionTitle {
                    width: parent.width
                    title: "Recently added"
                    actionText: "BROWSE LIBRARY  ›"
                    actionEnabled: true
                    onActionActivated: root.showPage("library")
                }

                Row {
                    id: demoRecentlyAddedRow
                    width: parent.width
                    spacing: 15
                    MediaCard {
                        width: (demoRecentlyAddedRow.width - 3 * demoRecentlyAddedRow.spacing) / 4
                        eyebrow: "MOVIE"; title: "Cosmic Drift"; subtitle: "2026  •  1h 52m"
                        accent: "#7d4d91"
                        onActivated: root.openDetails({title: title, mediaType: "movie"}, "MOVIE")
                    }
                    MediaCard {
                        width: (demoRecentlyAddedRow.width - 3 * demoRecentlyAddedRow.spacing) / 4
                        eyebrow: "SHOW"; title: "Harbor Street"; subtitle: "2024  •  2 seasons"
                        accent: "#4d7485"
                        onActivated: root.openDetails({title: title, mediaType: "show"}, "SHOW")
                    }
                    MediaCard {
                        width: (demoRecentlyAddedRow.width - 3 * demoRecentlyAddedRow.spacing) / 4
                        eyebrow: "MOVIE"; title: "The Long Winter"; subtitle: "2025  •  1h 44m"
                        accent: "#506c79"
                        onActivated: root.openDetails({title: title, mediaType: "movie"}, "MOVIE")
                    }
                    MediaCard {
                        width: (demoRecentlyAddedRow.width - 3 * demoRecentlyAddedRow.spacing) / 4
                        eyebrow: "SHOW"; title: "Signal Lost"; subtitle: "2023  •  8 episodes"
                        accent: "#9c5a39"
                        onActivated: root.openDetails({title: title, mediaType: "show"}, "SHOW")
                    }
                }
            }

            Column {
                width: contentColumn.width
                spacing: 12
                visible: !demoMode && serverClient.homeReady
                         && serverClient.recentlyAdded.length > 0

                SectionTitle {
                    width: parent.width
                    title: "Recently added"
                    actionText: "BROWSE LIBRARY  ›"
                    actionEnabled: true
                    onActionActivated: root.showPage("library")
                }

                Row {
                    id: recentlyAddedRow
                    width: parent.width
                    spacing: 15

                    Repeater {
                        model: Math.min(4, serverClient.recentlyAdded.length)

                        MediaCard {
                            required property int index
                            property var media: serverClient.recentlyAdded[index]

                            width: (recentlyAddedRow.width - 3 * recentlyAddedRow.spacing) / 4
                            eyebrow: root.mediaLabel(media)
                            title: root.itemTitle(media, "Untitled")
                            subtitle: root.itemMeta(media)
                            artSource: root.homeWideArtwork(media)
                            fallbackArtSource: root.homeArtworkFallback(media)
                            artworkOpacity: 0.74
                            accent: root.cardAccent(index)
                            onActivated: root.openLibraryEntry(media)
                        }
                    }
                }
            }

            Rectangle {
                readonly property bool hasHomeContent:
                    serverClient.continueWatching.length > 0
                    || serverClient.recentlyAdded.length > 0
                    || serverClient.liveChannels.length > 0
                    || serverClient.libraryRows.length > 0
                    || serverClient.libraries.length > 0

                visible: !demoMode && serverClient.paired
                         && (!serverClient.homeReady || !hasHomeContent)
                width: contentColumn.width
                height: 244
                radius: 24
                color: root.panel
                border.width: 1
                border.color: "#3b4046"

                Row {
                    anchors.centerIn: parent
                    spacing: 28

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 142
                        height: 142
                        source: "../assets/mascot/tater-front.png"
                        fillMode: Image.PreserveAspectFit
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 560
                        spacing: 10

                        Text {
                            text: serverClient.homeErrorMessage.length > 0
                                  ? "Couldn’t load your home screen"
                                  : (serverClient.homeLoading || !serverClient.homeReady
                                     ? "Loading your Tater Tube"
                                     : "Connected and ready")
                            color: root.textPrimary
                            font.pixelSize: 28
                            font.weight: Font.Bold
                        }
                        Text {
                            width: parent.width
                            text: serverClient.homeErrorMessage.length > 0
                                  ? serverClient.homeErrorMessage
                                  : (serverClient.homeLoading || !serverClient.homeReady
                                     ? "Fetching Continue Watching, Tube TV, artwork, and your newest media."
                                     : "The server is paired, but there isn’t any home-screen media to show yet.")
                            color: root.textSecondary
                            wrapMode: Text.WordWrap
                            font.pixelSize: 16
                        }
                        Text {
                            text: serverClient.serverName.length > 0
                                  ? serverClient.serverName + "  •  " + serverClient.serverUrl
                                  : serverClient.serverUrl
                            color: root.orangeBright
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        FocusButton {
                            visible: serverClient.homeErrorMessage.length > 0
                            width: 180
                            text: "Try again"
                            primary: true
                            onClicked: serverClient.refreshHome()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: sectionPage
        property string heldLibraryArtwork: ""
        readonly property bool showLibraryArtwork:
            root.currentPage === "library" && !demoMode
            && serverClient.libraryDepth > 0
            && heldLibraryArtwork.length > 0
            && (serverClient.libraryLoading
                || root.libraryBrowseStage() === "seasons"
                || root.libraryBrowseStage() === "episodes")

        function syncLibraryArtwork() {
            if (root.currentPage !== "library" || serverClient.libraryLoading)
                return
            var stage = root.libraryBrowseStage()
            if (stage === "seasons") {
                var seriesArtwork = root.libraryHeroArtwork()
                if (seriesArtwork.length > 0)
                    heldLibraryArtwork = seriesArtwork
            } else if (stage === "episodes") {
                // Keep the series artwork already on screen while entering a
                // season. Only resolve a fallback for a directly opened season.
                if (heldLibraryArtwork.length === 0) {
                    var seasonArtwork = root.libraryHeroArtwork()
                    if (seasonArtwork.length > 0)
                        heldLibraryArtwork = seasonArtwork
                }
            } else {
                heldLibraryArtwork = ""
            }
        }
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: root.currentPage !== "home"
        color: root.color
        z: 40

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#171a1e" }
            GradientStop { position: 1.0; color: "#0c0e10" }
        }

        Item {
            id: libraryScreenBackdrop
            anchors.fill: parent
            visible: sectionPage.showLibraryArtwork
                     && libraryScreenArtwork.status === Image.Ready

            Image {
                id: libraryScreenArtwork
                anchors.fill: parent
                source: sectionPage.heldLibraryArtwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: sectionPage.showLibraryArtwork && status === Image.Ready
                opacity: 0.68
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#730a0c0f" }
                    GradientStop { position: 0.52; color: "#a80a0c0f" }
                    GradientStop { position: 1.0; color: "#ed0a0c0f" }
                }
            }
        }

        Flickable {
            id: sectionScroller
            anchors.fill: parent
            contentHeight: sectionColumn.implicitHeight + 72
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: sectionColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 46
                anchors.rightMargin: 46
                anchors.top: parent.top
                anchors.topMargin: 34
                spacing: 28

                Column {
                    width: parent.width
                    visible: root.currentPage === "library"
                    spacing: 22

                    Rectangle {
                        id: libraryQuickBrowse
                        visible: demoMode || serverClient.libraryDepth === 0
                        width: parent.width
                        height: 94
                        radius: 22
                        clip: true
                        color: "#1d2024"
                        border.width: 1
                        border.color: "#41464c"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 5
                            color: root.orange
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Rectangle {
                                width: 58
                                height: 58
                                radius: 18
                                color: "#2b211b"
                                border.width: 1
                                border.color: "#70401f"

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: "../assets/mascot/tater-wave.png"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: "QUICK BROWSE"
                                    color: root.orangeBright
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.35
                                }

                                Text {
                                    text: "Jump straight into your complete collection."
                                    color: root.textPrimary
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Row {
                            id: libraryQuickActions
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            FocusButton {
                                id: libraryAllMovies
                                width: 220
                                text: "All Movies  ›"
                                primary: true
                                enabled: !!root.libraryCollectionRow("movies")
                                onClicked: root.openLibraryCollection("movies")
                            }

                            FocusButton {
                                id: libraryAllTvShows
                                width: 220
                                text: "All TV Shows  ›"
                                enabled: !!root.libraryCollectionRow("series")
                                onClicked: root.openLibraryCollection("series")
                            }

                            FocusButton {
                                id: libraryDiscover
                                visible: demoMode || !!serverClient.capabilities.newznab
                                width: 190
                                text: "Discover  ›"
                                onClicked: root.showPage("discover")
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        visible: demoMode || serverClient.libraryDepth === 0
                        spacing: 30

                        Repeater {
                            model: root.libraryPageRows().length

                            Column {
                                id: shelfColumn
                                required property int index
                                property var shelf: root.libraryPageRows()[index]
                                property var shelfItems: root.libraryRowItems(shelf)
                                width: parent.width
                                visible: shelfItems.length > 0 || !!shelf.loading
                                spacing: 12

                                SectionTitle {
                                    width: parent.width
                                    title: root.itemTitle(shelf, "Library")
                                    actionText: shelf.loading ? "LOADING…" : "SEE ALL  ›"
                                    actionEnabled: !shelf.loading && shelfItems.length > 0
                                    onActionActivated: root.openLibraryRow(shelf)
                                }

                                Row {
                                    width: parent.width
                                    visible: shelfItems.length > 0
                                    spacing: 15

                                    Repeater {
                                        model: Math.min(4, shelfColumn.shelfItems.length)

                                        MediaCard {
                                            required property int index
                                            property var media: shelfColumn.shelfItems[index]
                                            width: (shelfColumn.width - 3 * 15) / 4
                                            eyebrow: root.mediaLabel(media)
                                            title: root.itemTitle(media, "Untitled")
                                            subtitle: String(media && media.mediaType || "").toLowerCase() === "show"
                                                      ? root.showCardMeta(media)
                                                      : root.libraryItemMeta(media)
                                            artSource: root.homeWideArtwork(media)
                                            fallbackArtSource: root.homeArtworkFallback(media)
                                            artworkOpacity: 0.74
                                            progress: root.progressValue(media
                                                                         ? media.progressPercent : 0)
                                            accent: root.cardAccent(index + shelfColumn.index)
                                            onActivated: root.openLibraryEntry(media)
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: !!shelf.loading && shelfItems.length === 0
                                    width: parent.width
                                    height: 132
                                    radius: 18
                                    color: root.panel
                                    border.width: 1
                                    border.color: "#3b4046"

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 14

                                        BusyIndicator {
                                            anchors.verticalCenter: parent.verticalCenter
                                            running: parent.parent.visible
                                            palette.highlight: root.orange
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Tater is filling this shelf…"
                                            color: root.textSecondary
                                            font.pixelSize: 16
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        visible: !demoMode && serverClient.libraryDepth > 0
                        spacing: 22

                        Rectangle {
                            id: tvCollectionHero
                            readonly property string browseStage: root.libraryBrowseStage()
                            readonly property var resumeMedia: root.libraryResumeItem()
                            visible: !serverClient.libraryLoading
                                     && serverClient.libraryErrorMessage.length === 0
                                     && (browseStage === "seasons" || browseStage === "episodes")
                            width: parent.width
                            height: browseStage === "seasons" ? 290 : 224
                            radius: 26
                            clip: true
                            color: "#3d16191d"
                            border.width: 0
                            antialiasing: true

                            FrostedGlass {
                                anchors.fill: parent
                                sourceItem: libraryScreenArtwork.visible
                                            ? libraryScreenBackdrop : null
                                coordinateItem: tvCollectionHero
                                updateToken: sectionScroller.contentY
                                cornerRadius: tvCollectionHero.radius
                                tint: "#42101418"
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: tvCollectionHero.radius
                                antialiasing: true
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#5c0c0e11" }
                                    GradientStop { position: 0.64; color: "#2e121417" }
                                    GradientStop { position: 1.0; color: "#14121417" }
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 36
                                anchors.right: heroPoster.left
                                anchors.rightMargin: 34
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 11

                                Text {
                                    text: tvCollectionHero.browseStage === "seasons"
                                          ? "TATER TV  •  SERIES" : "TATER TV  •  SEASON"
                                    color: root.orangeBright
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.35
                                }

                                Text {
                                    width: parent.width
                                    text: serverClient.libraryTitle
                                    color: root.textPrimary
                                    font.pixelSize: tvCollectionHero.browseStage === "seasons" ? 42 : 36
                                    font.weight: Font.Black
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: tvCollectionHero.browseStage === "seasons"
                                          ? root.displayedLibraryItems().length
                                            + (root.displayedLibraryItems().length === 1 ? " season" : " seasons")
                                            + (root.libraryEpisodeCount() > 0
                                               ? "  •  " + root.libraryEpisodeCount() + " episodes" : "")
                                          : root.displayedLibraryItems().length
                                            + (root.displayedLibraryItems().length === 1 ? " episode" : " episodes")
                                    color: "#c6c9cb"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    visible: !tvCollectionHero.resumeMedia
                                    text: tvCollectionHero.browseStage === "seasons"
                                          ? "Choose a season and settle in."
                                          : "Pick an episode and Tater will remember your place."
                                    color: root.textSecondary
                                    font.pixelSize: 14
                                }

                                FocusButton {
                                    id: tvContinueButton
                                    visible: !!tvCollectionHero.resumeMedia
                                    width: Math.min(390, Math.max(240, implicitWidth))
                                    text: root.continueButtonText(tvCollectionHero.resumeMedia)
                                    primary: true
                                    onClicked: root.startPlayback(tvCollectionHero.resumeMedia,
                                                                  root.mediaLabel(tvCollectionHero.resumeMedia))
                                }
                            }

                            Rectangle {
                                id: heroPoster
                                anchors.right: parent.right
                                anchors.rightMargin: 28
                                anchors.verticalCenter: parent.verticalCenter
                                width: tvCollectionHero.browseStage === "seasons" ? 176 : 150
                                height: parent.height - 30
                                radius: 20
                                clip: true
                                color: "#8a25292d"
                                border.width: 1
                                border.color: "#8f765d4b"

                                Image {
                                    id: heroPosterArtwork
                                    anchors.fill: parent
                                    source: tvCollectionHero.browseStage === "seasons"
                                            ? root.librarySeriesPoster()
                                            : root.librarySeasonPoster()
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    visible: status === Image.Ready
                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: 120
                                    height: 120
                                    source: "../assets/mascot/tater-salute.png"
                                    fillMode: Image.PreserveAspectFit
                                    visible: !heroPosterArtwork.visible
                                }
                            }
                        }

                        SectionTitle {
                            width: parent.width
                            title: root.libraryBrowseStage() === "seasons"
                                   ? "Seasons"
                                   : (root.libraryBrowseStage() === "episodes"
                                      ? "Episodes" : serverClient.libraryTitle)
                            actionText: serverClient.libraryLoading
                                        ? "LOADING…"
                                        : root.displayedLibraryItems().length + " ITEMS"
                        }

                        Grid {
                            id: libraryGrid
                            width: parent.width
                            visible: !serverClient.libraryLoading
                                     && serverClient.libraryErrorMessage.length === 0
                                     && root.libraryBrowseStage() !== "seasons"
                                     && root.libraryBrowseStage() !== "episodes"
                            columns: Math.max(1, Math.floor(width / 205))
                            columnSpacing: 15
                            rowSpacing: 18

                            Repeater {
                                model: Math.min(root.libraryVisibleLimit,
                                                root.displayedLibraryItems().length)

                                PosterCard {
                                    required property int index
                                    property var media: root.displayedLibraryItems()[index]
                                    width: (libraryGrid.width
                                            - (libraryGrid.columns - 1) * libraryGrid.columnSpacing)
                                           / libraryGrid.columns
                                    title: root.itemTitle(media, "Untitled")
                                    meta: String(media && media.mediaType || "").toLowerCase() === "show"
                                          ? root.showCardMeta(media) : root.libraryItemMeta(media)
                                    number: media && media.streamUrl
                                            ? (index < 9 ? "0" + (index + 1) : String(index + 1))
                                            : "›"
                                    badge: media && media.resumeTitle ? "IN PROGRESS" : ""
                                    artSource: media && media.poster ? media.poster : ""
                                    progress: root.progressValue(media ? media.progressPercent : 0)
                                    accent: root.cardAccent(index)
                                    onActivated: root.openLibraryEntry(media)
                                }
                            }
                        }

                        Grid {
                            id: seasonGrid
                            width: parent.width
                            visible: !serverClient.libraryLoading
                                     && serverClient.libraryErrorMessage.length === 0
                                     && root.libraryBrowseStage() === "seasons"
                            columns: 4
                            columnSpacing: 18
                            rowSpacing: 20

                            Repeater {
                                model: Math.min(root.libraryVisibleLimit,
                                                root.displayedLibraryItems().length)

                                SeasonCard {
                                    required property int index
                                    property var media: root.displayedLibraryItems()[index]
                                    width: (seasonGrid.width - 3 * seasonGrid.columnSpacing) / 4
                                    title: root.itemTitle(media, "Season")
                                    meta: root.seasonCardMeta(media)
                                    resumeTitle: media && media.resumeTitle ? media.resumeTitle : ""
                                    artSource: media && media.seasonPoster
                                               ? media.seasonPoster
                                               : (media && media.poster ? media.poster : "")
                                    progress: root.progressValue(media ? media.progressPercent : 0)
                                    glassSource: libraryScreenArtwork.visible
                                                 ? libraryScreenBackdrop : null
                                    glassScrollOffset: sectionScroller.contentY
                                    onActivated: root.openLibraryEntry(media)
                                }
                            }
                        }

                        Grid {
                            id: episodeGrid
                            width: parent.width
                            visible: !serverClient.libraryLoading
                                     && serverClient.libraryErrorMessage.length === 0
                                     && root.libraryBrowseStage() === "episodes"
                            columns: 2
                            columnSpacing: 18
                            rowSpacing: 18

                            Repeater {
                                model: Math.min(root.libraryVisibleLimit,
                                                root.displayedLibraryItems().length)

                                EpisodeCard {
                                    required property int index
                                    property var media: root.displayedLibraryItems()[index]
                                    property var resumeMedia: root.libraryResumeItem()
                                    width: (episodeGrid.width - episodeGrid.columnSpacing) / 2
                                    title: root.itemTitle(media, "Episode")
                                    meta: root.episodeCardMeta(media)
                                    description: media && media.description ? media.description : ""
                                    artSource: media && media.episodeStill
                                               ? media.episodeStill
                                               : (media && media.poster ? media.poster : "")
                                    progress: root.progressValue(media ? media.progressPercent : 0)
                                    current: !!resumeMedia && media
                                             && String(resumeMedia.path || "") === String(media.path || "")
                                    glassSource: libraryScreenArtwork.visible
                                                 ? libraryScreenBackdrop : null
                                    glassScrollOffset: sectionScroller.contentY
                                    onActivated: root.openLibraryEntry(media)
                                }
                            }
                        }

                        FocusButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !serverClient.libraryLoading
                                     && serverClient.libraryErrorMessage.length === 0
                                     && root.displayedLibraryItems().length > root.libraryVisibleLimit
                            width: 220
                            text: "Show more titles"
                            onClicked: root.libraryVisibleLimit += 60
                        }

                        Rectangle {
                            visible: serverClient.libraryLoading
                            width: parent.width
                            height: 220
                            radius: 24
                            color: root.panel
                            border.width: 1
                            border.color: "#3b4046"

                            Row {
                                anchors.centerIn: parent
                                spacing: 20

                                BusyIndicator {
                                    anchors.verticalCenter: parent.verticalCenter
                                    running: parent.parent.visible
                                    palette.highlight: root.orange
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Loading your library…"
                                    color: root.textPrimary
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Rectangle {
                            visible: !serverClient.libraryLoading
                                     && serverClient.libraryErrorMessage.length > 0
                            width: parent.width
                            height: 220
                            radius: 24
                            color: root.panel
                            border.width: 1
                            border.color: "#6b4b38"

                            Row {
                                anchors.centerIn: parent
                                spacing: 20

                                Image {
                                    width: 120
                                    height: 120
                                    source: "../assets/mascot/tater-wave.png"
                                    fillMode: Image.PreserveAspectFit
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 520
                                    spacing: 12

                                    Text {
                                        width: parent.width
                                        text: serverClient.libraryErrorMessage
                                        color: root.textPrimary
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: 17
                                    }

                                    FocusButton {
                                        width: 160
                                        text: "Try again"
                                        primary: true
                                        onClicked: serverClient.refreshLibrary()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: !serverClient.libraryLoading
                                     && serverClient.libraryErrorMessage.length === 0
                                     && root.displayedLibraryItems().length === 0
                            width: parent.width
                            height: 220
                            radius: 24
                            color: root.panel
                            border.width: 1
                            border.color: "#3b4046"

                            Text {
                                anchors.centerIn: parent
                                text: "This folder does not contain any playable media."
                                color: root.textSecondary
                                font.pixelSize: 17
                            }
                        }
                    }

                    Rectangle {
                        visible: !demoMode && serverClient.libraryDepth === 0
                                 && !serverClient.libraryRowsLoading
                                 && !serverClient.libraryLoading
                                 && root.libraryPageRows().length === 0
                        width: parent.width
                        height: 220
                        radius: 24
                        color: root.panel
                        border.width: 1
                        border.color: "#3b4046"

                        Text {
                            anchors.centerIn: parent
                            text: "No local library titles were returned yet."
                            color: root.textSecondary
                            font.pixelSize: 17
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: root.currentPage === "discover"
                    spacing: 22

                    Rectangle {
                        visible: demoMode || serverClient.discoverStage === "catalog"
                        width: parent.width
                        height: 94
                        radius: 22
                        clip: true
                        color: "#1d2024"
                        border.width: 1
                        border.color: "#41464c"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 5
                            color: root.orange
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Image {
                                width: 62
                                height: 62
                                source: "../assets/mascot/tater-salute.png"
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: "TATER DISCOVER"
                                    color: root.orangeBright
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.35
                                }

                                Text {
                                    text: "Find something great, then stream it through your own server."
                                    color: root.textPrimary
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    Grid {
                        id: discoverCategoryGrid
                        width: parent.width
                        visible: (demoMode || serverClient.discoverStage === "catalog")
                                 && !serverClient.discoverLoading
                                 && (demoMode || serverClient.discoverErrorMessage.length === 0)
                        columns: 3
                        columnSpacing: 16
                        rowSpacing: 18

                        Repeater {
                            model: root.displayedDiscoverCategories().length

                            PosterCard {
                                required property int index
                                property var category: root.displayedDiscoverCategories()[index]
                                width: (discoverCategoryGrid.width - 2 * discoverCategoryGrid.columnSpacing) / 3
                                height: 238
                                title: root.itemTitle(category, "Discover")
                                meta: String(category.detail || category.category || "DISCOVER").toUpperCase()
                                number: index < 9 ? "0" + (index + 1) : String(index + 1)
                                accent: index < 3 ? "#d8651c" : "#5a6067"
                                onActivated: root.openDiscoverCategory(category)
                            }
                        }
                    }

                    Grid {
                        id: discoverItemsGrid
                        width: parent.width
                        visible: !demoMode && serverClient.discoverStage !== "catalog"
                                 && !serverClient.discoverLoading
                                 && serverClient.discoverErrorMessage.length === 0
                        columns: Math.max(1, Math.floor(width / 205))
                        columnSpacing: 15
                        rowSpacing: 18

                        Repeater {
                            model: Math.min(root.discoverVisibleLimit,
                                            root.displayedDiscoverItems().length)

                            PosterCard {
                                required property int index
                                property var media: root.displayedDiscoverItems()[index]
                                width: (discoverItemsGrid.width
                                        - (discoverItemsGrid.columns - 1)
                                          * discoverItemsGrid.columnSpacing)
                                       / discoverItemsGrid.columns
                                title: root.itemTitle(media, "Untitled")
                                meta: root.discoverItemMeta(media)
                                number: serverClient.discoverStage === "titles"
                                        ? "›" : (index < 9 ? "0" + (index + 1)
                                                            : String(index + 1))
                                artSource: media && media.poster ? media.poster : ""
                                accent: root.cardAccent(index)
                                onActivated: root.activateDiscoverItem(media)
                            }
                        }
                    }

                    FocusButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !demoMode && !serverClient.discoverLoading
                                 && serverClient.discoverErrorMessage.length === 0
                                 && root.displayedDiscoverItems().length
                                    > root.discoverVisibleLimit
                        width: 220
                        text: "Show more titles"
                        onClicked: root.discoverVisibleLimit += 60
                    }

                    Rectangle {
                        visible: !demoMode && serverClient.discoverLoading
                        width: parent.width
                        height: 230
                        radius: 24
                        color: root.panel
                        border.width: 1
                        border.color: "#3b4046"

                        Row {
                            anchors.centerIn: parent
                            spacing: 20

                            BusyIndicator {
                                anchors.verticalCenter: parent.verticalCenter
                                running: parent.parent.visible
                                palette.highlight: root.orange
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                Text {
                                    text: serverClient.discoverStage === "results"
                                          ? "Tater is preparing your stream…"
                                          : "Tater is exploring…"
                                    color: root.textPrimary
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: serverClient.discoverStage === "results"
                                          ? "The first play can take a little while while the NZB becomes streamable."
                                          : "Loading artwork and titles from your server."
                                    color: root.textSecondary
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: !demoMode && !serverClient.discoverLoading
                                 && serverClient.discoverErrorMessage.length > 0
                        width: parent.width
                        height: 230
                        radius: 24
                        color: root.panel
                        border.width: 1
                        border.color: "#6b4b38"

                        Row {
                            anchors.centerIn: parent
                            spacing: 20

                            Image {
                                width: 120
                                height: 120
                                source: "../assets/mascot/tater-wave.png"
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 560
                                spacing: 12

                                Text {
                                    width: parent.width
                                    text: serverClient.discoverErrorMessage
                                    color: root.textPrimary
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 17
                                }

                                FocusButton {
                                    width: 180
                                    text: serverClient.discoverStage === "catalog"
                                          ? "Try again" : "Go back"
                                    primary: true
                                    onClicked: serverClient.discoverStage === "catalog"
                                               ? serverClient.refreshDiscover()
                                               : serverClient.browseDiscoverBack()
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: !demoMode && !serverClient.discoverLoading
                                 && serverClient.discoverErrorMessage.length === 0
                                 && serverClient.discoverStage !== "catalog"
                                 && root.displayedDiscoverItems().length === 0
                        width: parent.width
                        height: 210
                        radius: 24
                        color: root.panel
                        border.width: 1
                        border.color: "#3b4046"

                        Text {
                            anchors.centerIn: parent
                            text: "No titles were returned for this selection."
                            color: root.textSecondary
                            font.pixelSize: 17
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: root.currentPage === "live"
                    spacing: 22

                    Column {
                        id: liveGuide
                        width: parent.width
                        visible: root.displayedLiveChannels().length > 0
                        spacing: 12

                        readonly property real channelWidth: 210
                        readonly property real programWidth:
                            (width - channelWidth - 3 * 12) / 3

                        Rectangle {
                            width: parent.width
                            height: 48
                            radius: 14
                            color: "#1e2125"
                            border.width: 1
                            border.color: "#383d43"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 18
                                spacing: 12

                                Text {
                                    width: liveGuide.channelWidth - 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "CHANNEL"
                                    color: root.textSecondary
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.2
                                }

                                Repeater {
                                    model: ["ON NOW", "UP NEXT", "LATER"]

                                    Text {
                                        required property string modelData
                                        width: liveGuide.programWidth
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        color: modelData === "ON NOW" ? root.orange
                                                                      : root.textSecondary
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1.2
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.displayedLiveChannels().length

                            Row {
                                id: guideRow
                                required property int index
                                property var channel: root.displayedLiveChannels()[index]
                                property var programs: root.guidePrograms(channel)
                                property var currentProgram: programs.length > 0
                                    ? programs[0] : (channel && channel.now ? channel.now : null)
                                width: liveGuide.width
                                spacing: 12

                                GuideProgramCard {
                                    width: liveGuide.channelWidth
                                    timeLabel: "CH " + guideRow.channel.number + "  •  LIVE"
                                    title: root.itemTitle(guideRow.channel, "Tater Tube")
                                    meta: "WATCH CHANNEL"
                                    isCurrent: true
                                    artSource: guideRow.currentProgram && guideRow.currentProgram.poster
                                               ? guideRow.currentProgram.poster : ""
                                    accent: root.cardAccent(guideRow.index)
                                    progress: root.progressValue(guideRow.currentProgram
                                                                 ? guideRow.currentProgram.progressPercent : 0)
                                    onActivated: {
                                        if (guideRow.channel && guideRow.channel.streamUrl)
                                            root.startPlayback(guideRow.channel,
                                                               "CHANNEL " + guideRow.channel.number)
                                        else
                                            root.openDetails(guideRow.channel,
                                                             "CHANNEL " + guideRow.channel.number)
                                    }
                                }

                                Repeater {
                                    model: Math.min(3, guideRow.programs.length)

                                    GuideProgramCard {
                                        required property int index
                                        property var program: guideRow.programs[index]
                                        width: liveGuide.programWidth
                                        timeLabel: root.guideProgramTime(guideRow.channel,
                                                                         program, index)
                                        title: root.itemTitle(program, "Tater Tube")
                                        meta: root.guideProgramMeta(guideRow.channel, program)
                                        isCurrent: root.guideProgramIsCurrent(guideRow.channel,
                                                                              program, index)
                                        artSource: root.guideCardArtwork(guideRow.programs, index)
                                        fallbackArtSource: root.guideCardArtworkFallback(
                                                               guideRow.programs, index)
                                        artworkOpacity: 0.74
                                        accent: root.cardAccent(guideRow.index + index)
                                        progress: root.progressValue(program
                                                                     ? program.progressPercent : 0)
                                        onActivated: root.activateGuideProgram(guideRow.channel,
                                                                               program, index)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: !demoMode && serverClient.liveGuideLoading
                                 && root.displayedLiveChannels().length === 0
                        width: parent.width
                        height: 220
                        radius: 24
                        color: root.panel
                        border.width: 1
                        border.color: "#3b4046"

                        Row {
                            anchors.centerIn: parent
                            spacing: 20

                            BusyIndicator {
                                anchors.verticalCenter: parent.verticalCenter
                                running: parent.parent.visible
                                palette.highlight: root.orange
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Tater is loading the channel guide…"
                                color: root.textPrimary
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Rectangle {
                        visible: !demoMode && !serverClient.liveGuideLoading
                                 && serverClient.liveGuideErrorMessage.length > 0
                                 && root.displayedLiveChannels().length === 0
                        width: parent.width
                        height: 220
                        radius: 24
                        color: root.panel
                        border.width: 1
                        border.color: "#6b4b38"

                        Row {
                            anchors.centerIn: parent
                            spacing: 20

                            Image {
                                width: 120
                                height: 120
                                source: "../assets/mascot/tater-wave.png"
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 520
                                spacing: 12

                                Text {
                                    width: parent.width
                                    text: serverClient.liveGuideErrorMessage
                                    color: root.textPrimary
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 17
                                }

                                FocusButton {
                                    width: 180
                                    text: "Try again"
                                    primary: true
                                    onClicked: serverClient.refreshLiveGuide()
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: !demoMode && !serverClient.liveGuideLoading
                                 && serverClient.liveGuideErrorMessage.length === 0
                                 && serverClient.liveGuideReady
                                 && root.displayedLiveChannels().length === 0
                        width: parent.width
                        height: 220
                        radius: 24
                        color: root.panel
                        border.width: 1
                        border.color: "#3b4046"

                        Text {
                            anchors.centerIn: parent
                            text: "No live channels are configured on this server."
                            color: root.textSecondary
                            font.pixelSize: 17
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: root.currentPage === "search"
                    spacing: 22

                    TextField {
                        id: searchField
                        width: Math.min(parent.width, 680)
                        height: 58
                        activeFocusOnTab: true
                        placeholderText: "Search loaded titles"
                        color: root.textPrimary
                        placeholderTextColor: "#7f858b"
                        font.pixelSize: 17
                        selectByMouse: true
                        background: Rectangle {
                            radius: 15
                            color: "#181b1f"
                            border.width: searchField.activeFocus ? 3 : 1
                            border.color: searchField.activeFocus ? root.orange : "#41464c"
                        }
                    }

                    SectionTitle {
                        width: parent.width
                        title: searchField.text.length > 0 ? "Results" : "Loaded titles"
                        actionText: root.filteredMediaItems(searchField.text).length + " FOUND"
                    }

                    Grid {
                        id: searchGrid
                        width: parent.width
                        columns: Math.max(1, Math.floor(width / 205))
                        columnSpacing: 15
                        rowSpacing: 18

                        Repeater {
                            model: root.filteredMediaItems(searchField.text).length

                            PosterCard {
                                required property int index
                                property var media: root.filteredMediaItems(searchField.text)[index]
                                width: (searchGrid.width
                                        - (searchGrid.columns - 1) * searchGrid.columnSpacing)
                                       / searchGrid.columns
                                title: root.itemTitle(media, "Untitled")
                                meta: root.itemMeta(media)
                                number: index < 9 ? "0" + (index + 1) : String(index + 1)
                                artSource: media && media.poster ? media.poster : ""
                                accent: root.cardAccent(index)
                                onActivated: root.openLibraryEntry(media)
                            }
                        }
                    }

                    Rectangle {
                        visible: root.filteredMediaItems(searchField.text).length === 0
                        width: parent.width
                        height: 180
                        radius: 24
                        color: root.panel
                        border.width: 1
                        border.color: "#3b4046"

                        Text {
                            anchors.centerIn: parent
                            text: "No loaded titles match that search."
                            color: root.textSecondary
                            font.pixelSize: 17
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: sideMenuScrim
        anchors.fill: parent
        visible: root.sideMenuOpen
        color: "#8206080a"
        z: 170

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeSideMenu(true)
        }
    }

    Rectangle {
        id: sideMenu
        x: root.sideMenuOpen ? 0 : -width - 18
        y: 0
        width: 304
        height: root.height
        enabled: root.sideMenuOpen
        z: 180
        color: "#f51a1d21"
        border.width: 1
        border.color: "#4a4f55"

        Behavior on x {
            NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 18
            color: "#18000000"
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 26
            spacing: 17

            Item {
                width: parent.width
                height: 124

                Image {
                    anchors.fill: parent
                    source: "../assets/tater-tube-logo-leaning-transparent.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#3b4046"
            }

            Text {
                text: "BROWSE"
                color: root.textSecondary
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1.6
            }

            FocusButton {
                id: sideHomeNav
                width: parent.width
                text: "Home"
                selected: root.currentPage === "home"
                onClicked: root.showPage("home")
            }

            FocusButton {
                id: sideLibraryNav
                width: parent.width
                text: "Library"
                selected: root.currentPage === "library"
                onClicked: root.showPage("library")
            }

            FocusButton {
                id: sideDiscoverNav
                visible: demoMode || !!serverClient.capabilities.newznab
                width: parent.width
                text: "Discover"
                selected: root.currentPage === "discover"
                onClicked: root.showPage("discover")
            }

            FocusButton {
                id: sideLiveNav
                width: parent.width
                text: "Live TV"
                selected: root.currentPage === "live"
                onClicked: root.showPage("live")
            }

            FocusButton {
                id: sideSearchNav
                width: parent.width
                text: "Search"
                selected: root.currentPage === "search"
                onClicked: root.showPage("search")
            }

            Text {
                topPadding: 10
                width: parent.width
                text: "Press Right to close"
                color: "#858b91"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: sideServerStatus
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: sideExitNav.top
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            anchors.bottomMargin: 12
            height: 46
            radius: 14
            color: "#202429"
            border.width: 1
            border.color: "#3c4147"

            Row {
                anchors.centerIn: parent
                spacing: 9

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9
                    height: 9
                    radius: 5
                    color: demoMode || serverClient.online ? "#73d68a" : "#71767c"
                }

                Text {
                    text: demoMode ? "DEMO LIBRARY"
                                   : (serverClient.online ? "SERVER ONLINE" : "SERVER OFFLINE")
                    color: "#d9dbdc"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                }
            }
        }

        FocusButton {
            id: sideExitNav
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            anchors.bottomMargin: 26
            text: "Exit to Steam"
            onClicked: Qt.quit()
        }
    }

    Rectangle {
        id: detailsOverlay
        anchors.fill: parent
        visible: root.detailsOpen
        color: "#dc08090b"
        z: 200

        MouseArea {
            anchors.fill: parent
            onClicked: {
                UiSounds.back()
                root.closeDetails()
            }
        }

        Rectangle {
            id: detailsPanel
            anchors.centerIn: parent
            width: Math.min(980, root.width - 100)
            height: Math.min(590, root.height - 100)
            radius: 30
            color: "#202328"
            border.width: 1
            border.color: "#51565c"
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 300
                color: "#17191d"

                Image {
                    id: detailsArtwork
                    anchors.fill: parent
                    source: root.selectedItem && root.selectedItem.poster
                            ? root.selectedItem.poster
                            : (root.selectedItem && root.selectedItem.now
                               && root.selectedItem.now.poster
                               ? root.selectedItem.now.poster : "")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Image {
                    anchors.centerIn: parent
                    width: 210
                    height: 210
                    source: "../assets/mascot/tater-front.png"
                    fillMode: Image.PreserveAspectFit
                    visible: !detailsArtwork.visible
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 344
                anchors.right: parent.right
                anchors.rightMargin: 42
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                Text {
                    text: root.selectedKind
                    color: root.orangeBright
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4
                }

                Text {
                    width: parent.width
                    text: root.selectedKind.indexOf("CHANNEL") === 0
                          ? root.channelTitle(root.selectedItem)
                          : root.itemTitle(root.selectedItem, "Tater Tube")
                    color: root.textPrimary
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.pixelSize: 34
                    font.weight: Font.Black
                }

                Text {
                    width: parent.width
                    text: root.selectedItem && root.selectedItem.description
                          ? root.selectedItem.description
                          : (root.selectedItem && root.selectedItem.next
                             ? "Up next: " + root.selectedItem.next.title
                             : "Selected from your private Tater Tube Server library.")
                    color: root.textSecondary
                    wrapMode: Text.WordWrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    font.pixelSize: 16
                    lineHeight: 1.2
                }

                Text {
                    visible: root.itemMeta(root.selectedItem).length > 0
                    text: root.itemMeta(root.selectedItem)
                    color: "#d0d2d3"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: parent.width
                    height: 64
                    radius: 15
                    color: "#28231f"
                    border.width: 1
                    border.color: "#65462f"

                    Text {
                        anchors.centerIn: parent
                        text: root.selectedKind.indexOf("CHANNEL") === 0
                              ? "Live playback includes your server-built channels, commercials, and spots."
                              : "Tater Tube will direct play first and optimize automatically when needed."
                        color: "#e4c4ab"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    spacing: 12

                    FocusButton {
                        id: detailsPlay
                        width: 210
                        text: root.selectedKind.indexOf("CHANNEL") === 0
                              ? "▶  Watch live" : "▶  Play"
                        primary: true
                        enabled: !!(root.selectedItem && root.selectedItem.streamUrl)
                        onClicked: root.startPlayback(root.selectedItem, root.selectedKind)
                    }
                }
            }
        }
    }

    AudioOutput {
        id: playerAudio
        device: playbackCapabilities.defaultAudioOutput
        volume: 0.85
        muted: false
    }

    MediaPlayer {
        id: mediaPlayer
        audioOutput: playerAudio
        videoOutput: playerVideo

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState) {
                root.selectPlaybackAudioTrack()
                root.playbackStatusMessage = ""
                playbackControlsTimer.restart()
            } else {
                root.playbackControlsVisible = true
                playbackControlsTimer.stop()
            }
        }

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia
                    || mediaStatus === MediaPlayer.BufferedMedia) {
                root.selectPlaybackAudioTrack()
                root.playbackStatusMessage = ""
                if (!root.playbackUsingFallback && root.playbackPendingResumeMs > 0) {
                    var resumeAt = root.playbackPendingResumeMs
                    root.playbackPendingResumeMs = 0
                    mediaPlayer.setPosition(Math.round(resumeAt))
                }
            } else if (mediaStatus === MediaPlayer.EndOfMedia) {
                root.savePlaybackState(true)
                root.playbackEnded = true
                root.playbackControlsVisible = true
                root.playbackStatusMessage = "Finished"
            }
        }

        onTracksChanged: root.selectPlaybackAudioTrack()

        onErrorOccurred: function(error, errorString) {
            if (!root.playbackOpen)
                return
            if (root.retryWithCompatibleStream(errorString))
                return
            root.playbackStatusMessage = ""
            root.playbackError = errorString && errorString.length > 0
                    ? errorString : "This video could not be played."
            root.playbackControlsVisible = true
            UiSounds.alert()
        }
    }

    Connections {
        target: playerVideo.videoSink

        function onVideoFrameChanged(frame) {
            if (root.playbackOpen
                    && mediaPlayer.playbackState === MediaPlayer.PlayingState)
                root.playbackHasVideoFrame = true
        }
    }

    Timer {
        id: playbackProgressTimer
        interval: 15000
        repeat: true
        running: root.playbackOpen && !root.playbackIsLive
                 && mediaPlayer.playbackState === MediaPlayer.PlayingState
        onTriggered: root.savePlaybackState(false)
    }

    Timer {
        id: playbackControlsTimer
        interval: 4500
        repeat: false
        onTriggered: {
            if (root.playbackOpen && root.playbackError.length === 0
                    && mediaPlayer.playbackState === MediaPlayer.PlayingState)
                root.playbackControlsVisible = false
        }
    }

    Rectangle {
        id: playbackOverlay
        anchors.fill: parent
        visible: root.playbackOpen
        color: "#050607"
        z: 300

        VideoOutput {
            id: playerVideo
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
        }

        MouseArea {
            anchors.fill: parent
            z: 1
            onClicked: {
                if (root.playbackControlsVisible
                        && mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                    root.playbackControlsVisible = false
                    playbackControlsTimer.stop()
                } else {
                    root.showPlaybackControls()
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 142
            visible: root.playbackControlsVisible || root.playbackError.length > 0
            z: 4
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#e6050607" }
                GradientStop { position: 1.0; color: "#00050607" }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 30
                anchors.top: parent.top
                anchors.topMargin: 24
                spacing: 18

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(200, parent.width - qualityPill.width - parent.spacing)
                    spacing: 4

                    Text {
                        width: parent.width
                        text: root.playbackTitle()
                        color: root.textPrimary
                        elide: Text.ElideRight
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }

                    Text {
                        text: root.playbackIsLive
                              ? "CHANNEL " + (root.playbackItem.number || "")
                              : root.mediaLabel(root.playbackItem)
                        color: root.orangeBright
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.3
                    }
                }

                Rectangle {
                    id: qualityPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: qualityLabel.implicitWidth + 24
                    height: 34
                    radius: 11
                    color: "#272b30"
                    border.width: 1
                    border.color: "#4a5057"

                    Text {
                        id: qualityLabel
                        anchors.centerIn: parent
                        text: root.playbackQuality
                        color: "#d7d9da"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: root.playbackError.length === 0
                     && (mediaPlayer.mediaStatus === MediaPlayer.StalledMedia
                         || (!root.playbackHasVideoFrame
                             && (mediaPlayer.mediaStatus === MediaPlayer.LoadingMedia
                                 || mediaPlayer.mediaStatus === MediaPlayer.BufferingMedia)))
            z: 5
            spacing: 14

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 132
                height: 132
                source: "../assets/mascot/tater-front.png"
                fillMode: Image.PreserveAspectFit
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.visible
                palette.highlight: root.orange
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.playbackStatusMessage.length > 0
                      ? root.playbackStatusMessage : "Loading…"
                color: root.textPrimary
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(600, parent.width - 80)
            height: 270
            radius: 28
            visible: root.playbackError.length > 0
            color: "#ed202328"
            border.width: 1
            border.color: "#6b4b38"
            z: 6

            Row {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 22

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150
                    height: 150
                    source: "../assets/mascot/tater-wave.png"
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 172
                    spacing: 12

                    Text {
                        text: "PLAYBACK NEEDS ATTENTION"
                        color: root.orangeBright
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }

                    Text {
                        width: parent.width
                        text: root.playbackError
                        color: root.textPrimary
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        font.pixelSize: 16
                    }

                    Row {
                        spacing: 10

                        FocusButton {
                            text: "Try again"
                            primary: true
                            onClicked: root.startPlayback(root.playbackItem,
                                                          root.playbackIsLive ? "CHANNEL" : "MEDIA")
                        }

                        FocusButton {
                            text: "Back"
                            soundRole: "back"
                            onClicked: root.closePlayback()
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 190
            visible: root.playbackControlsVisible || root.playbackError.length > 0
            z: 4
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00050607" }
                GradientStop { position: 1.0; color: "#ed050607" }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 34
                anchors.rightMargin: 34
                anchors.bottomMargin: 24
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 14

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72
                        text: root.playbackIsLive ? "LIVE" : root.formatPlaybackTime(root.playbackPositionMs())
                        color: root.playbackIsLive ? root.orangeBright : root.textPrimary
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    Slider {
                        id: playbackSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 166
                        from: 0
                        to: Math.max(1, root.playbackDurationMs())
                        value: root.playbackPositionMs()
                        enabled: !root.playbackIsLive && root.playbackDurationMs() > 0
                        onMoved: root.seekPlayback(value)

                        background: Rectangle {
                            x: playbackSlider.leftPadding
                            y: playbackSlider.topPadding + playbackSlider.availableHeight / 2 - height / 2
                            width: playbackSlider.availableWidth
                            height: 5
                            radius: 3
                            color: "#555a60"

                            Rectangle {
                                width: playbackSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: root.orange
                            }
                        }

                        handle: Rectangle {
                            x: playbackSlider.leftPadding + playbackSlider.visualPosition
                               * (playbackSlider.availableWidth - width)
                            y: playbackSlider.topPadding + playbackSlider.availableHeight / 2 - height / 2
                            width: 18
                            height: 18
                            radius: 9
                            color: playbackSlider.pressed ? root.orangeBright : root.orange
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 66
                        horizontalAlignment: Text.AlignRight
                        text: root.playbackIsLive ? "ON AIR" : root.formatPlaybackTime(root.playbackDurationMs())
                        color: root.textSecondary
                        font.pixelSize: 13
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    FocusButton {
                        width: 128
                        compact: true
                        text: "−10 sec"
                        enabled: !root.playbackIsLive
                        onClicked: root.seekPlaybackBy(-10000)
                    }

                    FocusButton {
                        width: 154
                        text: mediaPlayer.playbackState === MediaPlayer.PlayingState
                              ? "❚❚  Pause" : "▶  Play"
                        primary: true
                        onClicked: root.togglePlayback()
                    }

                    FocusButton {
                        width: 128
                        compact: true
                        text: "+10 sec"
                        enabled: !root.playbackIsLive
                        onClicked: root.seekPlaybackBy(10000)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 12
                        text: "VOLUME  " + Math.round(playerAudio.volume * 100) + "%"
                        color: root.textSecondary
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.playbackIsLive
                          ? "A  Play/Pause    B  Back    ↑↓  Volume"
                          : "A  Play/Pause    B  Back    ←→  Seek 10 sec    ↑↓  Volume"
                    color: "#8f9499"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Rectangle {
        id: pairingOverlay
        visible: !demoMode && !serverClient.paired
        anchors.fill: parent
        color: "#e608090b"
        z: 100
        onVisibleChanged: {
            if (visible) {
                root.sideMenuOpen = false
                root.sideMenuReturnFocus = null
                Qt.callLater(function() { serverField.forceActiveFocus() })
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 620
            height: 560
            radius: 28
            color: "#202328"
            border.width: 1
            border.color: "#484d53"

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 24
                width: 122
                height: 122
                source: "../assets/mascot/tater-wave.png"
                fillMode: Image.PreserveAspectFit
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 150
                anchors.leftMargin: 60
                anchors.rightMargin: 60
                spacing: 15

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome to Tater Tube Player"
                    color: root.textPrimary
                    font.pixelSize: 29
                    font.weight: Font.Bold
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Pair this screen with Tater Tube Server to bring in your library and channels."
                    color: root.textSecondary
                    wrapMode: Text.WordWrap
                    font.pixelSize: 15
                }

                TextField {
                    id: serverField
                    width: parent.width
                    height: 54
                    placeholderText: "Server address  •  192.168.1.50:8080"
                    color: root.textPrimary
                    placeholderTextColor: "#7f858b"
                    font.pixelSize: 16
                    selectByMouse: true
                    background: Rectangle {
                        radius: 14
                        color: "#16181c"
                        border.width: serverField.activeFocus ? 2 : 1
                        border.color: serverField.activeFocus ? root.orange : "#41464c"
                    }
                }

                TextField {
                    id: pinField
                    width: parent.width
                    height: 54
                    placeholderText: "Six-digit pairing code"
                    color: root.textPrimary
                    placeholderTextColor: "#7f858b"
                    font.pixelSize: 18
                    font.letterSpacing: 4
                    maximumLength: 6
                    inputMethodHints: Qt.ImhDigitsOnly
                    horizontalAlignment: Text.AlignHCenter
                    background: Rectangle {
                        radius: 14
                        color: "#16181c"
                        border.width: pinField.activeFocus ? 2 : 1
                        border.color: pinField.activeFocus ? root.orange : "#41464c"
                    }
                    onAccepted: {
                        UiSounds.select()
                        serverClient.pair(serverField.text, text)
                    }
                }

                Text {
                    visible: serverClient.errorMessage.length > 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: serverClient.errorMessage
                    color: "#ff967f"
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                }

                FocusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 220
                    text: serverClient.busy ? "Pairing…" : "Pair this screen"
                    primary: true
                    onClicked: {
                        if (!serverClient.busy)
                            serverClient.pair(serverField.text, pinField.text)
                    }
                }
            }
        }
    }
}
