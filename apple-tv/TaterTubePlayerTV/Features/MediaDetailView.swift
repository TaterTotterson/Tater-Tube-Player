import SwiftUI

struct MediaDetailView: View {
    @EnvironmentObject private var store: PlayerStore
    @Namespace private var popupFocusScope
    @FocusState private var resumeHasFocus: Bool
    @FocusState private var playHasFocus: Bool
    @FocusState private var clearHasFocus: Bool

    let item: MediaItem

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            ZStack(alignment: .topLeading) {
                ArtworkView(
                    remoteValue: detailBackdrop,
                    demoName: item.wideDemoArtworkName,
                    showsPlaceholder: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                LinearGradient(
                    colors: [Color.black.opacity(0.97), Color.black.opacity(0.82), Color.black.opacity(0.16)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [Color.black.opacity(0.04), Color.black.opacity(0.10), Color.black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                detailContent

            }
            .frame(width: 1420, height: 720)
            .background(Color.black.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(TaterTheme.orange.opacity(0.78), lineWidth: 2)
            }
            .shadow(color: Color.black.opacity(0.78), radius: 48, y: 24)
            .shadow(color: TaterTheme.orange.opacity(0.18), radius: 28)
        }
        .focusScope(popupFocusScope)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                if hasProgress { resumeHasFocus = true } else { playHasFocus = true }
            }
        }
        .onExitCommand { store.selectedMedia = nil }
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(item.title)
                .font(.system(size: 55, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)

            if let metadata = metadataLine {
                Text(metadata)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }

            if let tagline = item.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .italic()
                    .lineLimit(1)
            }

            if let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 22, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(4)
                    .frame(maxWidth: 760, alignment: .leading)
            }

            HStack(spacing: 11) {
                ForEach(infoChips, id: \.self) { value in
                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.38), lineWidth: 1.5)
                        }
                }
            }

            Spacer(minLength: 20)

            if hasProgress {
                VStack(alignment: .leading, spacing: 11) {
                    Text("WATCH PROGRESS")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.86))

                    HStack(spacing: 20) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.22))
                                Capsule()
                                    .fill(TaterTheme.orange)
                                    .frame(width: geometry.size.width * item.visibleProgress)
                            }
                        }
                        .frame(width: 650, height: 8)

                        Text(progressLabel)
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                            .lineLimit(1)
                    }
                }
            }

            if store.isPreparingDiscovery {
                HStack(spacing: 14) {
                    ProgressView().tint(TaterTheme.orange)
                    Text("Preparing your Discover stream…")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                }
            }

            if hasProgress {
                HStack(spacing: 18) {
                    DetailActionButton(
                        prominent: true,
                        width: 300,
                        action: { Task { await store.play(item, resume: true) } },
                        requestedFocus: $resumeHasFocus
                    ) {
                        Label("RESUME", systemImage: "play.fill")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                    }
                    .disabled(!hasPlayableSource || store.isPreparingDiscovery)
                    .prefersDefaultFocus(true, in: popupFocusScope)

                    DetailActionButton(
                        width: 320,
                        action: { Task { await store.play(item, resume: false) } },
                        requestedFocus: $playHasFocus
                    ) {
                        Label(
                            store.isDemo ? "PLAY DEMO" : "START OVER",
                            systemImage: "arrow.counterclockwise"
                        )
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    }
                    .disabled(!hasPlayableSource || store.isPreparingDiscovery)

                    DetailActionButton(
                        width: 300,
                        action: { Task { await store.clearProgress(for: item) } },
                        requestedFocus: $clearHasFocus
                    ) {
                        Label("CLEAR PROGRESS", systemImage: "trash")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                    }
                    .disabled(store.isDemo || store.isPreparingDiscovery)
                }
                .focusSection()
            } else {
                unwatchedSpotlight
            }
        }
        .padding(.leading, 72)
        .padding(.top, 62)
        .padding(.bottom, 68)
        .padding(.trailing, 44)
        .frame(maxWidth: 1_320, maxHeight: .infinity, alignment: .topLeading)
    }

    private var unwatchedSpotlight: some View {
        HStack(spacing: 20) {
            Image(systemName: "clock.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(TaterTheme.orangeBright)
                .frame(width: 58, height: 58)
                .background(TaterTheme.orange.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(unwatchedRuntimeTitle)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.94))

                Text(unwatchedTimingDetail)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer(minLength: 20)

            DetailActionButton(
                prominent: true,
                width: 280,
                action: { Task { await store.play(item, resume: false) } },
                requestedFocus: $playHasFocus
            ) {
                Label(store.isDemo ? "PLAY DEMO" : "PLAY", systemImage: "play.fill")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
            }
            .disabled(!hasPlayableSource || store.isPreparingDiscovery)
            .prefersDefaultFocus(true, in: popupFocusScope)
        }
        .padding(.leading, 22)
        .padding(.trailing, 16)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
        }
        .focusSection()
    }

    private var hasProgress: Bool {
        item.resumeOffsetMS > 0 || (item.progressPercent ?? 0) > 0.5
    }

    private var metadataLine: String? {
        var values = [item.date]
        if let rating = item.communityRating, rating > 0 {
            values.append(String(format: "★ %.1f", rating))
        }
        return values
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "  •  ")
            .nilIfEmpty
    }

    private var infoChips: [String] {
        item.cinematicMetadataChips
    }

    private var progressLabel: String {
        let duration = item.resolvedDurationMS
        if duration > item.resumeOffsetMS, item.resumeOffsetMS > 0 {
            let remaining = duration - item.resumeOffsetMS
            if let finish = finishTime(after: remaining) {
                return "\(formatDuration(remaining)) remaining  •  Finish around \(finish)"
            }
            return "\(formatDuration(remaining)) remaining"
        }
        if let progress = item.progressPercent {
            return "\(Int(progress.rounded()))% watched"
        }
        return "Ready to resume"
    }

    private var unwatchedRuntimeTitle: String {
        let duration = item.resolvedDurationMS
        guard duration > 0 else { return "READY TO PLAY" }
        return "\(formatDuration(duration).uppercased()) RUNTIME"
    }

    private var unwatchedTimingDetail: String {
        guard let finish = finishTime(after: item.resolvedDurationMS) else {
            return "Starts from the beginning"
        }
        return "Start now  •  Finish around \(finish)"
    }

    private func finishTime(after milliseconds: Int64) -> String? {
        guard milliseconds > 0 else { return nil }
        return Date()
            .addingTimeInterval(Double(milliseconds) / 1_000)
            .formatted(date: .omitted, time: .shortened)
    }

    private func formatDuration(_ milliseconds: Int64) -> String {
        let minutes = max(0, Int(milliseconds / 60_000))
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(remainder)m"
    }

    private var detailBackdrop: String? {
        item.backdrop ?? item.episodeStill ?? item.poster ?? item.seriesPoster ?? item.seasonPoster
    }

    private var hasPlayableSource: Bool {
        store.isDemo || item.streamURL?.isEmpty == false || item.nzbURL?.isEmpty == false
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private struct DetailActionButton<Label: View>: View {
    let prominent: Bool
    let width: CGFloat
    let action: () -> Void
    let requestedFocus: FocusState<Bool>.Binding
    let label: Label

    @Environment(\.isEnabled) private var isEnabled

    init(
        prominent: Bool = false,
        width: CGFloat,
        action: @escaping () -> Void,
        requestedFocus: FocusState<Bool>.Binding,
        @ViewBuilder label: () -> Label
    ) {
        self.prominent = prominent
        self.width = width
        self.action = action
        self.requestedFocus = requestedFocus
        self.label = label()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)

        label
            .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.42))
            .frame(width: width, height: 74)
            .background {
                shape.fill(
                    requestedFocus.wrappedValue
                        ? TaterTheme.orangeBright
                        : (prominent ? TaterTheme.orange.opacity(0.68) : Color.black.opacity(0.58))
                )
            }
            .overlay {
                shape.stroke(
                    requestedFocus.wrappedValue
                        ? Color.white.opacity(0.92)
                        : Color.white.opacity(prominent ? 0.42 : 0.62),
                    lineWidth: requestedFocus.wrappedValue ? 3 : 1.5
                )
            }
            .shadow(
                color: requestedFocus.wrappedValue ? TaterTheme.orange.opacity(0.58) : .clear,
                radius: 19
            )
            .contentShape(shape)
            .focusable(isEnabled)
            .focused(requestedFocus)
            .focusEffectDisabled()
            .scaleEffect(requestedFocus.wrappedValue ? 1.025 : 1)
            .animation(.easeOut(duration: 0.14), value: requestedFocus.wrappedValue)
            .onTapGesture {
                guard isEnabled else { return }
                action()
            }
            .accessibilityAddTraits(.isButton)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
