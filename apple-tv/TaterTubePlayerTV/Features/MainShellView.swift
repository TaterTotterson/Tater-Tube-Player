import SwiftUI

enum TaterDestination {
    static let home = 0
    static let live = 1
    static let movies = 2
    static let series = 3
    static let discover = 4
    static let picks = 5
    static let settings = 6
}

struct MainShellView: View {
    @EnvironmentObject private var store: PlayerStore
    @FocusState private var focusedTopDestination: Int?
    @FocusState private var topNavigationLandingHasFocus: Bool
    @State private var isTopNavigationActive = false
    @State private var isRestoringContentFocus = false
    @State private var contentFocusRequest = 0
    @State private var selectedTab = ProcessInfo.processInfo.arguments.contains("--series")
        ? TaterDestination.series
        : (ProcessInfo.processInfo.arguments.contains("--picks")
            ? TaterDestination.picks
            : (ProcessInfo.processInfo.arguments.contains("--discover")
            ? TaterDestination.discover
            : (ProcessInfo.processInfo.arguments.contains("--live")
                ? TaterDestination.live
                : (ProcessInfo.processInfo.arguments.contains("--library")
                    ? TaterDestination.movies
                    : TaterDestination.home))))

    var body: some View {
        ZStack(alignment: .top) {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 44)
                .disabled(store.selectedMedia != nil || isTopNavigationActive)
                .allowsHitTesting(store.selectedMedia == nil)
                .accessibilityHidden(store.selectedMedia != nil)

            TaterTopNavigation(
                selectedTab: $selectedTab,
                focusedDestination: $focusedTopDestination,
                isActive: isTopNavigationActive,
                onSelectDestination: selectTopDestination,
                onLeaveNavigation: leaveTopNavigation,
                onBackToHome: returnTopNavigationToHome
            )
                .environmentObject(store)
                .disabled(store.selectedMedia != nil)
                .zIndex(2)

            TopNavigationFocusLanding(
                isEnabled: focusedTopDestination == nil
                    && store.selectedMedia == nil
                    && !isTopNavigationActive
                    && !isRestoringContentFocus,
                hasFocus: $topNavigationLandingHasFocus,
                onFocus: focusCurrentTopDestination
            )
            .padding(.top, 44)
            .zIndex(3)

            if let item = store.selectedMedia {
                MediaDetailView(item: item)
                    .environmentObject(store)
                    .transition(.opacity.combined(with: .scale(scale: 0.975)))
                    .zIndex(4)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(TaterTheme.background.ignoresSafeArea())
        .animation(.spring(response: 0.28, dampingFraction: 0.90), value: store.selectedMedia?.id)
        .onChange(of: store.selectedMedia?.id) { previousID, currentID in
            guard previousID != nil, currentID == nil else { return }
            restoreContentFocusAfterDetails()
        }
        .tint(TaterTheme.orange)
        .fullScreenCover(isPresented: $store.isPlaybackPresented) {
            NativePlayerScreen()
                .environmentObject(store)
                .background(Color.black.ignoresSafeArea())
        }
        .alert("Tater Tube Player", isPresented: storeErrorIsPresented) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Something went wrong.")
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case TaterDestination.live:
            if store.home?.capabilities.tubeTV == true {
                LiveTVView(onReturnToTopNavigation: focusCurrentTopDestination)
            } else {
                HomeView(
                    selectedTab: $selectedTab,
                    onReturnToTopNavigation: focusCurrentTopDestination,
                    contentFocusRequest: contentFocusRequest
                )
            }
        case TaterDestination.movies:
            TopLevelLibraryView(
                location: .allMovies,
                selectedTab: $selectedTab,
                onReturnToTopNavigation: focusCurrentTopDestination,
                contentFocusRequest: contentFocusRequest
            )
        case TaterDestination.series:
            TopLevelLibraryView(
                location: .allShows,
                selectedTab: $selectedTab,
                onReturnToTopNavigation: focusCurrentTopDestination,
                contentFocusRequest: contentFocusRequest
            )
        case TaterDestination.discover:
            if store.home?.capabilities.newznab == true {
                DiscoveryView(
                    selectedTab: $selectedTab,
                    onReturnToTopNavigation: focusCurrentTopDestination,
                    contentFocusRequest: contentFocusRequest
                )
            } else {
                HomeView(
                    selectedTab: $selectedTab,
                    onReturnToTopNavigation: focusCurrentTopDestination,
                    contentFocusRequest: contentFocusRequest
                )
            }
        case TaterDestination.picks:
            if store.home?.capabilities.taterLink == true {
                TaterPicksView(
                    selectedTab: $selectedTab,
                    onReturnToTopNavigation: focusCurrentTopDestination,
                    contentFocusRequest: contentFocusRequest
                )
            } else {
                HomeView(
                    selectedTab: $selectedTab,
                    onReturnToTopNavigation: focusCurrentTopDestination,
                    contentFocusRequest: contentFocusRequest
                )
            }
        case TaterDestination.settings:
            SettingsView(selectedTab: $selectedTab, onReturnToTopNavigation: focusCurrentTopDestination)
        default:
            HomeView(
                selectedTab: $selectedTab,
                onReturnToTopNavigation: focusCurrentTopDestination,
                contentFocusRequest: contentFocusRequest
            )
        }
    }

    private func focusCurrentTopDestination() {
        isTopNavigationActive = true
        topNavigationLandingHasFocus = false
        focusedTopDestination = selectedTab
    }

    private func selectTopDestination(_ destination: Int) {
        guard destination != selectedTab else { return }

        isTopNavigationActive = true
        selectedTab = destination
        focusedTopDestination = destination
    }

    private func leaveTopNavigation() {
        isTopNavigationActive = false
        focusedTopDestination = nil
        contentFocusRequest &+= 1
    }

    private func returnTopNavigationToHome() {
        isTopNavigationActive = true
        selectedTab = TaterDestination.home
        focusedTopDestination = TaterDestination.home
    }

    private func restoreContentFocusAfterDetails() {
        isRestoringContentFocus = true
        isTopNavigationActive = false
        focusedTopDestination = nil
        topNavigationLandingHasFocus = false

        Task { @MainActor in
            // Give the detail overlay one update cycle to leave the focus tree,
            // then let the selected shelf reclaim focus before the top-menu
            // landing target becomes available again.
            await Task.yield()
            contentFocusRequest &+= 1
            try? await Task.sleep(for: .milliseconds(350))
            isRestoringContentFocus = false
        }
    }

    private var storeErrorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

private struct TaterTopNavigation: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int
    let focusedDestination: FocusState<Int?>.Binding
    let isActive: Bool
    let onSelectDestination: (Int) -> Void
    let onLeaveNavigation: () -> Void
    let onBackToHome: () -> Void

    private var destinations: [TopNavigationDestination] {
        var values = [TopNavigationDestination(tag: TaterDestination.home, title: "HOME")]
        if store.home?.capabilities.tubeTV == true {
            values.append(TopNavigationDestination(tag: TaterDestination.live, title: "TUBE TV"))
        }
        values.append(TopNavigationDestination(tag: TaterDestination.movies, title: "MOVIES"))
        values.append(TopNavigationDestination(tag: TaterDestination.series, title: "SERIES"))
        if store.home?.capabilities.newznab == true {
            values.append(TopNavigationDestination(tag: TaterDestination.discover, title: "DISCOVER"))
        }
        if store.home?.capabilities.taterLink == true {
            values.append(TopNavigationDestination(tag: TaterDestination.picks, title: "TATER PICKS"))
        }
        return values
    }

    var body: some View {
        HStack(spacing: 28) {
            Spacer(minLength: 250)

            ForEach(destinations) { destination in
                TopNavigationButton(
                    tag: destination.tag,
                    title: destination.title,
                    selected: selectedTab == destination.tag,
                    focusedDestination: focusedDestination,
                    action: { onSelectDestination(destination.tag) }
                )
                .modifier(
                    TopNavigationBackModifier(
                        enabled: destination.tag != TaterDestination.home,
                        action: onBackToHome
                    )
                )
            }

            Spacer(minLength: 38)

            TopNavigationButton(
                tag: TaterDestination.settings,
                systemImage: "gearshape.fill",
                selected: selectedTab == TaterDestination.settings,
                focusedDestination: focusedDestination,
                action: { onSelectDestination(TaterDestination.settings) }
            )
            .modifier(TopNavigationBackModifier(enabled: true, action: onBackToHome))
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 54)
        .frame(height: 44)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.97), Color.black.opacity(0.88), Color.black.opacity(0.50)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
        .onChange(of: focusedDestination.wrappedValue) { _, current in
            guard isActive, let current, current != selectedTab else { return }
            onSelectDestination(current)
        }
        .onMoveCommand { direction in
            if direction == .down {
                onLeaveNavigation()
            }
        }
    }
}

private struct TopNavigationBackModifier: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.onExitCommand(perform: action)
        } else {
            content
        }
    }
}

private struct TopNavigationButton: View {
    let tag: Int
    let title: String?
    let systemImage: String?
    let selected: Bool
    let focusedDestination: FocusState<Int?>.Binding
    let action: () -> Void

    init(
        tag: Int,
        title: String? = nil,
        systemImage: String? = nil,
        selected: Bool,
        focusedDestination: FocusState<Int?>.Binding,
        action: @escaping () -> Void
    ) {
        self.tag = tag
        self.title = title
        self.systemImage = systemImage
        self.selected = selected
        self.focusedDestination = focusedDestination
        self.action = action
    }

    private var isFocused: Bool { focusedDestination.wrappedValue == tag }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                if selected {
                    Circle()
                        .fill(TaterTheme.orangeBright)
                        .frame(width: 6, height: 6)
                }

                if let title {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .tracking(1.05)
                }

                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 21, weight: .semibold))
                }
            }
            .foregroundStyle(
                isFocused
                    ? TaterTheme.orangeBright
                    : (selected ? Color.white : Color.white.opacity(0.72))
            )

            Capsule()
                .fill(selected || isFocused ? TaterTheme.orange : Color.clear)
                .frame(height: 2)
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .focusable()
        .focused(focusedDestination, equals: tag)
        .focusEffectDisabled()
        .scaleEffect(isFocused ? 1.06 : 1)
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .onTapGesture(perform: action)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct TopNavigationFocusLanding: View {
    let isEnabled: Bool
    let hasFocus: FocusState<Bool>.Binding
    let onFocus: () -> Void

    var body: some View {
        Color.white.opacity(0.001)
            .frame(maxWidth: .infinity)
            .frame(height: 10)
            .contentShape(Rectangle())
            .focusable(isEnabled)
            .focused(hasFocus)
            .focusEffectDisabled()
            .onChange(of: hasFocus.wrappedValue) { _, focused in
                if focused { onFocus() }
            }
            .accessibilityHidden(true)
    }
}

private struct TopNavigationDestination: Identifiable {
    let tag: Int
    let title: String
    var id: Int { tag }
}
