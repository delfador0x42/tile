import SwiftUI

struct WindowPositionIcon: View {
    let alignment: Alignment
    let fillWidth: CGFloat
    let fillHeight: CGFloat

    private let iconWidth: CGFloat = 28
    private let iconHeight: CGFloat = 20
    private let cornerRadius: CGFloat = 4
    private let innerCornerRadius: CGFloat = 2
    private let padding: CGFloat = 2

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.quaternary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )

            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.tertiary, lineWidth: 1)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: innerCornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: innerCornerRadius)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .frame(
                        width: fillWidth * (geo.size.width - padding * 2),
                        height: fillHeight * (geo.size.height - padding * 2)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                    .padding(padding)
            }
        }
        .frame(width: iconWidth, height: iconHeight)
    }
}

struct LeftHalfIcon: View {
    var body: some View {
        WindowPositionIcon(alignment: .leading, fillWidth: 0.5, fillHeight: 1.0)
    }
}

struct RightHalfIcon: View {
    var body: some View {
        WindowPositionIcon(alignment: .trailing, fillWidth: 0.5, fillHeight: 1.0)
    }
}

struct TopHalfIcon: View {
    var body: some View {
        WindowPositionIcon(alignment: .top, fillWidth: 1.0, fillHeight: 0.5)
    }
}

struct BottomHalfIcon: View {
    var body: some View {
        WindowPositionIcon(alignment: .bottom, fillWidth: 1.0, fillHeight: 0.5)
    }
}
