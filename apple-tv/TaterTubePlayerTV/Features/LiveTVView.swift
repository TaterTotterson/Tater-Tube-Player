import SwiftUI

struct LiveTVView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var clock = Date()

    private var guide: TubeTVGuide? {
        if let guide = store.liveGuide { return guide }
        guard let channels = store.home?.liveChannels, !channels.isEmpty else { return nil }
        return TubeTVGuide(channels: channels)
    }

    var body: some View {
        ZStack {
            GuideGlowBackground()

            if let guide, !guide.channels.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 22, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(guide.channels) { channel in
                                LiveGuideRow(
                                    channel: channel,
                                    guide: guide,
                                    elapsed: guide.elapsedSeconds(at: clock)
                                )
                            }
                        } header: {
                            LiveGuideHeader()
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal, 70)
                    .padding(.top, 34)
                    .padding(.bottom, 120)
                }
                .refreshable { await store.refreshLiveGuide() }
            } else if store.isLiveGuideRefreshing {
                VStack(spacing: 24) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(TaterTheme.orange)
                    Text("Tuning your Tater Tube guide…")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 36)
                .taterGlass(cornerRadius: 30)
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "tv.badge.wifi")
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(TaterTheme.orange)
                    Text("No channels are on the guide yet")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                    Text(store.liveGuideError ?? "Build or enable Tube TV channels on your Tater Tube Server.")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { Task { await store.refreshLiveGuide(showActivity: true) } }
                        .buttonStyle(.borderedProminent)
                        .tint(TaterTheme.orange)
                }
                .padding(52)
                .frame(maxWidth: 780)
                .taterGlass(cornerRadius: 34)
            }
        }
        .task {
            if !store.isDemo {
                await store.refreshLiveGuide(showActivity: guide == nil)
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                clock = Date()
            }
        }
        .task {
            guard !store.isDemo else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await store.refreshLiveGuide()
            }
        }
    }
}

private struct LiveGuideHeader: View {
    var body: some View {
        HStack(spacing: 18) {
            Label("CHANNEL", systemImage: "dot.radiowaves.left.and.right")
                .frame(width: 246, alignment: .leading)
            Text("ON NOW").frame(maxWidth: .infinity, alignment: .leading)
            Text("UP NEXT").frame(maxWidth: .infinity, alignment: .leading)
            Text("LATER").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 19, weight: .bold, design: .rounded))
        .tracking(1.8)
        .foregroundStyle(.white.opacity(0.76))
        .padding(.horizontal, 26)
        .frame(height: 66)
        .taterGlass(cornerRadius: 24)
    }
}

private struct LiveGuideRow: View {
    @EnvironmentObject private var store: PlayerStore

    let channel: LiveChannel
    let guide: TubeTVGuide
    let elapsed: Double

    private var programs: [LiveProgram] { channel.displayedPrograms(elapsed: elapsed) }

    var body: some View {
        HStack(spacing: 18) {
            GuideFocusButton {
                Task { await store.play(channel) }
            } label: {
                ChannelSelectorCard(channel: channel)
            }
            .frame(width: 246)

            ForEach(0..<3, id: \.self) { index in
                if programs.indices.contains(index) {
                    let program = programs[index]
                    GuideFocusButton {
                        guard isCurrent(program, index: index) else { return }
                        Task { await store.play(channel) }
                    } label: {
                        LiveProgramCard(
                            program: program,
                            artworkURL: store.guideArtworkURL(for: program),
                            guide: guide,
                            elapsed: elapsed,
                            isCurrent: isCurrent(program, index: index),
                            position: index
                        )
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    GuidePlaceholderCard(position: index)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 226)
        .clipped()
    }

    private func isCurrent(_ program: LiveProgram, index: Int) -> Bool {
        if program.end > program.start {
            return program.start <= elapsed && elapsed < program.end
        }
        return index == 0
    }
}

private struct GuideFocusButton<Label: View>: View {
    let action: () -> Void
    let label: Label

    @FocusState private var isFocused: Bool

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) { label }
            .buttonStyle(.plain)
            .focused($isFocused)
            .focusEffectDisabled()
            .scaleEffect(isFocused ? 1.025 : 1)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isFocused ? TaterTheme.orangeBright : .clear, lineWidth: 5)
            }
            .shadow(color: isFocused ? TaterTheme.orange.opacity(0.34) : .clear, radius: 20)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

private struct ChannelSelectorCard: View {
    let channel: LiveChannel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.78), TaterTheme.orange.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let logo = channel.logoURL, !logo.isEmpty {
                ArtworkView(remoteValue: logo, demoName: nil, contentMode: .fit)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 28)
            } else {
                VStack(spacing: 9) {
                    Text("TATER")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(TaterTheme.orange)
                    Text(channel.logoTitle ?? channel.title)
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(20)
            }

            VStack {
                Spacer()
                HStack {
                    Text(channel.number.isEmpty ? "LIVE" : "CH \(channel.number)")
                    Spacer()
                    Image(systemName: "play.fill")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.58))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 226)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .taterGlass(cornerRadius: 24, interactive: true)
    }
}

private struct LiveProgramCard: View {
    let program: LiveProgram
    let artworkURL: String?
    let guide: TubeTVGuide
    let elapsed: Double
    let isCurrent: Bool
    let position: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(
                remoteValue: artworkURL,
                demoName: program.demoArtworkName,
                contentMode: .fill
            )
            .frame(maxWidth: .infinity)
            .frame(height: 226)
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.12), Color.black.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(timeLabel)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(isCurrent ? TaterTheme.orangeBright : .white.opacity(0.72))
                Text(program.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(metaLabel)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)

                if isCurrent {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Color.white.opacity(0.22)
                            TaterTheme.orange
                                .frame(width: geometry.size.width * program.progress(at: elapsed))
                        }
                    }
                    .frame(height: 7)
                    .clipShape(Capsule())
                    .padding(.top, 3)
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 226)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .taterGlass(cornerRadius: 24, interactive: true)
    }

    private var timeLabel: String {
        if isCurrent { return "ON NOW" }
        if let date = guide.startDate(for: program) {
            return date.formatted(date: .omitted, time: .shortened).uppercased()
        }
        return position == 1 ? "UP NEXT" : "LATER"
    }

    private var metaLabel: String {
        let minutes = max(1, Int(ceil(max(program.duration, program.end - program.start) / 60)))
        if program.isCommercialBreak {
            if let end = guide.startDate(for: LiveProgram(title: "End", start: program.end)) {
                return "BACK AT \(end.formatted(date: .omitted, time: .shortened).uppercased())  •  \(minutes) MIN BREAK"
            }
            return "\(minutes) MIN BREAK"
        }
        return "\((program.mediaType ?? program.kind ?? "PROGRAM").uppercased())  •  \(minutes) MIN"
    }
}

private struct GuidePlaceholderCard: View {
    let position: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(position == 1 ? "UP NEXT" : "LATER")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.42))
            Text("Schedule updating")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .frame(height: 226)
        .taterGlass(cornerRadius: 24)
    }
}

private struct GuideGlowBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [TaterTheme.orange.opacity(0.18), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 980
            )
        }
        .ignoresSafeArea()
    }
}
