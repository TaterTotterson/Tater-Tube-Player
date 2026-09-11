import SwiftUI

struct TaterGlassSurface: ViewModifier {
    var cornerRadius: CGFloat = TaterTheme.cardRadius
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(tvOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(TaterTheme.glassTint)
                        .interactive(interactive),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .background(.ultraThinMaterial, in: shape)
                .background(Color.black.opacity(0.42), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
    }
}

extension View {
    func taterGlass(
        cornerRadius: CGFloat = TaterTheme.cardRadius,
        interactive: Bool = false
    ) -> some View {
        modifier(TaterGlassSurface(cornerRadius: cornerRadius, interactive: interactive))
    }
}
