import SwiftUI

struct AppTheme {
    static let navy = Color(red: 0.03, green: 0.09, blue: 0.17)
    static let deepBlue = Color(red: 0.06, green: 0.15, blue: 0.29)
    static let mint = Color(red: 0.29, green: 0.95, blue: 0.76)
    static let cyan = Color(red: 0.14, green: 0.65, blue: 1.0)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [navy, deepBlue, Color(red: 0.12, green: 0.12, blue: 0.32)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var actionGradient: LinearGradient {
        LinearGradient(colors: [mint, cyan], startPoint: .leading, endPoint: .trailing)
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}

struct GradientButtonStyle: ButtonStyle {
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(disabled ? .secondary : .black)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(disabled ? AnyShapeStyle(.quaternary) : AnyShapeStyle(AppTheme.actionGradient))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct MetricPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.12))
            .clipShape(Capsule())
    }
}
