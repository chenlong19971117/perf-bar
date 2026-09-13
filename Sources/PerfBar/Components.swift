import SwiftUI

struct HelpRequest: Equatable {
    let text: String
    let frame: CGRect
}

private struct HoverHelpKey: EnvironmentKey {
    static let defaultValue: (HelpRequest?) -> Void = { _ in }
}

extension EnvironmentValues {
    var hoverHelp: (HelpRequest?) -> Void {
        get { self[HoverHelpKey.self] }
        set { self[HoverHelpKey.self] = newValue }
    }
}

struct BubbleHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct HoverHelpModifier: ViewModifier {
    let text: String
    @Environment(\.hoverHelp) private var hoverHelp
    @State private var frame: CGRect = .zero
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    let rect = proxy.frame(in: .named("panel"))
                    Color.clear
                        .onAppear { frame = rect }
                        .onChange(of: rect) { _, newValue in
                            frame = newValue
                            if hovering {
                                hoverHelp(HelpRequest(text: text, frame: newValue))
                            }
                        }
                }
            )
            .onHover { value in
                hovering = value
                hoverHelp(value ? HelpRequest(text: text, frame: frame) : nil)
            }
    }
}

extension View {
    func hoverHelp(_ text: String) -> some View {
        modifier(HoverHelpModifier(text: text))
    }
}

struct HelpBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
    }
}

func loadColor(_ fraction: Double) -> Color {
    if fraction >= 0.85 { return .red }
    if fraction >= 0.6 { return .orange }
    return .green
}

struct SectionHeader: View {
    let icon: String
    let title: String
    var trailing: String?
    var help: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let help {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .hoverHelp(help)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(valueColor)
                .monospacedDigit()
        }
    }
}

struct MetricBlock: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MeterBar: View {
    let fraction: Double
    var color: Color
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * clamped)
            }
        }
        .frame(height: height)
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color
    var height: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            let points = normalizedPoints(in: geometry.size)
            if points.count > 1 {
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geometry.size.height))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.15))

                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
        .frame(height: height)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let clamped = min(max(value, 0), 1)
            return CGPoint(x: CGFloat(index) * step, y: size.height * (1 - CGFloat(clamped)))
        }
    }
}

struct CoreGrid: View {
    let cores: [Double]

    private let columns = [GridItem(.adaptive(minimum: 7, maximum: 24), spacing: 3)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Array(cores.enumerated()), id: \.offset) { _, usage in
                let clamped = min(max(usage, 0), 1)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(loadColor(clamped))
                        .frame(height: max(2, 24 * clamped))
                }
                .frame(height: 24)
            }
        }
    }
}
