import SwiftUI

struct AppTheme {
    static let midnight = Color(red: 0.02, green: 0.04, blue: 0.09)
    static let navy = Color(red: 0.03, green: 0.09, blue: 0.17)
    static let deepBlue = Color(red: 0.05, green: 0.13, blue: 0.26)
    static let ink = Color(red: 0.08, green: 0.10, blue: 0.16)
    static let card = Color.white.opacity(0.095)
    static let cardStrong = Color.white.opacity(0.14)
    static let mint = Color(red: 0.25, green: 0.96, blue: 0.76)
    static let cyan = Color(red: 0.10, green: 0.67, blue: 1.0)
    static let violet = Color(red: 0.47, green: 0.40, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.22)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [midnight, navy, deepBlue, Color(red: 0.11, green: 0.10, blue: 0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var actionGradient: LinearGradient {
        LinearGradient(colors: [mint, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var purpleGradient: LinearGradient {
        LinearGradient(colors: [violet, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var warmGradient: LinearGradient {
        LinearGradient(colors: [orange, mint], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.heroGradient.ignoresSafeArea()
            Circle()
                .fill(AppTheme.cyan.opacity(0.18))
                .blur(radius: 55)
                .frame(width: 220, height: 220)
                .offset(x: 130, y: -250)
            Circle()
                .fill(AppTheme.violet.opacity(0.16))
                .blur(radius: 70)
                .frame(width: 260, height: 260)
                .offset(x: -150, y: 260)
        }
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
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 12)
    }
}

struct DarkCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.11), lineWidth: 1)
            )
    }
}

struct IconBubble: View {
    let systemImage: String
    var gradient: LinearGradient = AppTheme.actionGradient
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(gradient)
                .frame(width: size, height: size)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundStyle(.black.opacity(0.88))
        }
        .shadow(color: AppTheme.cyan.opacity(0.24), radius: 16, x: 0, y: 8)
    }
}

struct GradientButtonStyle: ButtonStyle {
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(disabled ? Color.secondary : Color.black)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(disabled ? AnyShapeStyle(.white.opacity(0.10)) : AnyShapeStyle(AppTheme.actionGradient))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(disabled ? 0.08 : 0.0), lineWidth: 1)
            )
            .shadow(color: disabled ? .clear : AppTheme.cyan.opacity(0.25), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct MetricPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    init(_ title: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconBubble(systemImage: systemImage, gradient: AppTheme.purpleGradient, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            Spacer()
        }
    }
}

struct StatusBadge: View {
    let text: String
    var color: Color = AppTheme.mint

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.black.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color)
            .clipShape(Capsule())
    }
}
