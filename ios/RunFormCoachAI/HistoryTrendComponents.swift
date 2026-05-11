import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if values.count >= 2 {
                let minVal = values.min()!
                let maxVal = values.max()!
                let range = max(maxVal - minVal, 0.001)
                let step = w / CGFloat(values.count - 1)

                let pts: [CGPoint] = values.enumerated().map { i, v in
                    CGPoint(
                        x: CGFloat(i) * step,
                        y: h - CGFloat((v - minVal) / range) * (h - 6) - 3
                    )
                }

                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        p.addLine(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(color.opacity(0.18))

                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(pts.last!)
                }
            } else {
                Rectangle()
                    .fill(color.opacity(0.25))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

struct TrendCard: View {
    let title: String
    let values: [Double]
    let color: Color

    private var latest: Double { values.last ?? 0 }
    private var delta: Double { values.count >= 2 ? latest - values[values.count - 2] : 0 }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)

                if values.isEmpty {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(Int(latest * 100))%")
                            .font(.title2.bold())
                            .foregroundStyle(color)
                        Spacer()
                        if abs(delta) > 0.005 {
                            Label(
                                "\(delta > 0 ? "+" : "")\(Int(delta * 100))%",
                                systemImage: delta > 0 ? "arrow.up.right" : "arrow.down.right"
                            )
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(delta > 0 ? AppTheme.mint : .red.opacity(0.80))
                        }
                    }
                    Sparkline(values: values, color: color)
                        .frame(height: 36)
                }
            }
        }
    }
}

struct ConsistencyCard: View {
    let sessionCount: Int

    private var label: String {
        switch sessionCount {
        case 0: return String(localized: "No sessions yet")
        case 1: return String(localized: "Good start!")
        case 2...3: return String(localized: "Building habit")
        case 4...6: return String(localized: "Staying consistent")
        default: return String(localized: "Great consistency!")
        }
    }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Consistency")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))

                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(sessionCount)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.orange)
                    Text("days / 30d")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                        .padding(.bottom, 2)
                }

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .frame(height: 36, alignment: .topLeading)
            }
        }
    }
}
