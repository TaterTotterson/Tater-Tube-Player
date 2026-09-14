import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isMenuPresented = ProcessInfo.processInfo.arguments.contains("--menu")
    @State private var selectedTab = ProcessInfo.processInfo.arguments.contains("--picks")
        ? 4
        : (ProcessInfo.processInfo.arguments.contains("--discover")
            ? 3
            : (ProcessInfo.processInfo.arguments.contains("--live")
                ? 2
                : (ProcessInfo.processInfo.arguments.contains("--library") ? 1 : 0)))

    var body: some View {
        ZStack(alignment: .leading) {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(isMenuPresented || store.selectedMedia != nil)
                .allowsHitTesting(!isMenuPresented && store.selectedMedia == nil)
                .accessibilityHidden(isMenuPresented || store.selectedMedia != nil)

            if isMenuPresented {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { closeMenu() }

                TaterSideMenu(
                    selectedTab: $selectedTab,
                    isPresented: $isMenuPresented
                )
                .environmentObject(store)
                .padding(.leading, 30)
                .padding(.vertical, 28)
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(1)
            }

            if let item = store.selectedMedia {
                MediaDetailView(item: item)
                    .environmentObject(store)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isMenuPresented)
        .animation(.spring(response: 0.28, dampingFraction: 0.90), value: store.selectedMedia?.id)
        .onPlayPauseCommand {
            if store.selectedMedia == nil {
                isMenuPresented.toggle()
            }
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
        case 1:
            LibraryView(selectedTab: $selectedTab)
        case 2:
            if store.home?.capabilities.tubeTV == true {
                LiveTVView(selectedTab: $selectedTab)
            } else {
                HomeView(selectedTab: $selectedTab)
            }
        case 3:
            if store.home?.capabilities.newznab == true {
                DiscoveryView(selectedTab: $selectedTab)
            } else {
                HomeView(selectedTab: $selectedTab)
            }
        case 4:
            if store.home?.capabilities.taterLink == true {
                TaterPicksView(selectedTab: $selectedTab)
            } else {
                HomeView(selectedTab: $selectedTab)
            }
        case 5:
            SettingsView(selectedTab: $selectedTab)
        default:
            HomeView(selectedTab: $selectedTab)
        }
    }

    private func closeMenu() {
        isMenuPresented = false
    }

    private var storeErrorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

private struct TaterSideMenu: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int
    @Binding var isPresented: Bool
    @State private var focusedTab: Int?
    @FocusState private var menuHasFocus: Bool

    private var destinations: [TaterSideMenuDestination] {
        var items = [
            TaterSideMenuDestination(tag: 0, title: "Home", symbol: "house.fill"),
            TaterSideMenuDestination(tag: 1, title: "Library", symbol: "rectangle.stack.fill")
        ]
        if store.home?.capabilities.tubeTV == true {
            items.append(TaterSideMenuDestination(tag: 2, title: "Live TV", symbol: "tv.fill"))
        }
        if store.home?.capabilities.newznab == true {
            items.append(TaterSideMenuDestination(tag: 3, title: "Discover", symbol: "sparkles.tv.fill"))
        }
        if store.home?.capabilities.taterLink == true {
            items.append(TaterSideMenuDestination(tag: 4, title: "Tater Picks", symbol: "wand.and.stars"))
        }
        items.append(TaterSideMenuDestination(tag: 5, title: "Settings", symbol: "gearshape.fill"))
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BundledImageView(name: "tater-tube-logo-leaning-transparent")
                .scaledToFit()
                .frame(width: 350, height: 132, alignment: .leading)
                .padding(.horizontal, 34)
                .padding(.top, 24)
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                ForEach(destinations) { destination in
                    menuRow(destination)
                }
            }
            .padding(.horizontal, 25)

            Spacer(minLength: 24)

            serverStatus
                .padding(.horizontal, 36)
                .padding(.bottom, 35)
        }
        .frame(width: 475)
        .frame(maxHeight: .infinity)
        .taterGlass(cornerRadius: 38)
        .contentShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        .focusable()
        .focusEffectDisabled()
        .focused($menuHasFocus)
        .onAppear {
            focusedTab = destinations.contains(where: { $0.tag == selectedTab })
                ? selectedTab
                : destinations.first?.tag
            Task { @MainActor in
                menuHasFocus = true
            }
        }
        .onMoveCommand { direction in
            moveFocus(direction)
        }
        .onTapGesture {
            activateFocusedDestination()
        }
        .onExitCommand {
            isPresented = false
        }
    }

    private func menuRow(_ destination: TaterSideMenuDestination) -> some View {
        let highlighted = focusedTab == destination.tag
        return HStack(spacing: 22) {
            Image(systemName: destination.symbol)
                .font(.system(size: 27, weight: .semibold))
                .frame(width: 38)

            Text(destination.title)
                .font(.system(size: 29, weight: .bold, design: .rounded))

            Spacer()
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 25)
        .frame(height: 66)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    highlighted
                        ? Color.black.opacity(0.90)
                        : (selectedTab == destination.tag
                            ? TaterTheme.orange.opacity(0.16)
                            : Color.clear)
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    highlighted
                        ? TaterTheme.orangeBright
                        : (selectedTab == destination.tag
                            ? TaterTheme.orange.opacity(0.46)
                            : Color.clear),
                    lineWidth: highlighted ? 4 : 1.5
                )
        }
        .shadow(
            color: highlighted ? TaterTheme.orange.opacity(0.38) : .clear,
            radius: highlighted ? 15 : 0
        )
        .scaleEffect(highlighted ? 1.025 : 1)
        .animation(.easeOut(duration: 0.16), value: highlighted)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(highlighted ? [.isSelected] : [])
    }

    private func moveFocus(_ direction: MoveCommandDirection) {
        guard !destinations.isEmpty else { return }
        let currentIndex = destinations.firstIndex(where: { $0.tag == focusedTab }) ?? 0
        switch direction {
        case .up:
            focusedTab = destinations[max(0, currentIndex - 1)].tag
        case .down:
            focusedTab = destinations[min(destinations.count - 1, currentIndex + 1)].tag
        case .left, .right:
            break
        @unknown default:
            break
        }
    }

    private func activateFocusedDestination() {
        guard let focusedTab,
              destinations.contains(where: { $0.tag == focusedTab })
        else { return }
        selectedTab = focusedTab
        isPresented = false
    }

    private var serverStatus: some View {
        VStack(alignment: .leading, spacing: 13) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)

            HStack(spacing: 12) {
                Circle()
                    .fill(store.isDemo ? Color.yellow : Color.green)
                    .frame(width: 12, height: 12)
                    .shadow(
                        color: (store.isDemo ? Color.yellow : Color.green).opacity(0.65),
                        radius: 8
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isDemo ? "DEMO MODE" : "SERVER ONLINE")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white)

                    if !store.isDemo {
                        Text(store.home?.serverName ?? "Tater Tube Server")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(TaterTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.top, 5)
        }
    }
}

private struct TaterSideMenuDestination: Identifiable {
    let tag: Int
    let title: String
    let symbol: String

    var id: Int { tag }
}
