import SwiftUI

enum TaterTheme {
    static let orange = Color(red: 0.95, green: 0.42, blue: 0.08)
    static let orangeBright = Color(red: 1.0, green: 0.55, blue: 0.16)
    static let background = Color.black
    static let glassTint = Color.black.opacity(0.34)
    static let secondaryText = Color.white.opacity(0.68)
    static let cardRadius: CGFloat = 28
    static let heroRadius: CGFloat = 36
}

private struct TaterActionLabel<Content: View>: View {
    let prominent: Bool
    let isFocused: Bool
    let content: Content

    var body: some View {
        content
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            .background(
                isFocused
                    ? Color.black.opacity(0.90)
                    : (prominent ? TaterTheme.orange.opacity(0.72) : Color.black.opacity(0.52)),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        isFocused ? TaterTheme.orangeBright : TaterTheme.orange.opacity(0.46),
                        lineWidth: isFocused ? 4 : 1.5
                    )
            }
            .shadow(
                color: isFocused ? TaterTheme.orange.opacity(0.38) : .clear,
                radius: isFocused ? 15 : 0
            )
    }
}

struct TaterActionButton<Label: View>: View {
    let prominent: Bool
    let action: () -> Void
    let onFocusChange: ((Bool) -> Void)?
    let requestedFocus: FocusState<Bool>.Binding?
    let label: Label

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    init(
        prominent: Bool = false,
        action: @escaping () -> Void,
        onFocusChange: ((Bool) -> Void)? = nil,
        requestedFocus: FocusState<Bool>.Binding? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.prominent = prominent
        self.action = action
        self.onFocusChange = onFocusChange
        self.requestedFocus = requestedFocus
        self.label = label()
    }

    var body: some View {
        let activeFocus = requestedFocus ?? $isFocused

        TaterActionLabel(
            prominent: prominent,
            isFocused: activeFocus.wrappedValue,
            content: label
        )
        .contentShape(Capsule())
        .focusable(isEnabled)
        .focused(activeFocus)
        .focusEffectDisabled()
        .scaleEffect(activeFocus.wrappedValue ? 1.045 : 1)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.16), value: activeFocus.wrappedValue)
        .onChange(of: activeFocus.wrappedValue) { _, focused in
            onFocusChange?(focused)
        }
        .onTapGesture {
            guard isEnabled else { return }
            action()
        }
        .accessibilityAddTraits(.isButton)
    }
}

struct TaterCardButton<Label: View>: View {
    let cornerRadius: CGFloat
    let usesDarkFocusSurface: Bool
    let action: () -> Void
    let onFocusChange: ((Bool) -> Void)?
    let label: Label

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    init(
        cornerRadius: CGFloat = 24,
        usesDarkFocusSurface: Bool = false,
        action: @escaping () -> Void,
        onFocusChange: ((Bool) -> Void)? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.cornerRadius = cornerRadius
        self.usesDarkFocusSurface = usesDarkFocusSurface
        self.action = action
        self.onFocusChange = onFocusChange
        self.label = label()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        label
            .contentShape(shape)
            .focusable(isEnabled)
            .focused($isFocused)
            .focusEffectDisabled()
            .background {
                if usesDarkFocusSurface && isFocused {
                    shape.fill(Color.black.opacity(0.90))
                }
            }
            .overlay {
                shape.stroke(
                    isFocused ? TaterTheme.orangeBright : Color.clear,
                    lineWidth: isFocused ? 4 : 0
                )
            }
            .shadow(
                color: isFocused ? TaterTheme.orange.opacity(0.34) : .clear,
                radius: isFocused ? 18 : 0
            )
            .scaleEffect(isFocused ? 1.025 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.16), value: isFocused)
            .onTapGesture {
                guard isEnabled else { return }
                action()
            }
            .onChange(of: isFocused) { _, focused in
                onFocusChange?(focused)
            }
            .accessibilityAddTraits(.isButton)
    }
}
