import SwiftUI

// MARK: - Cards

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

// MARK: - Small components

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
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let systemImage: String

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, systemImage: String) {
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

// MARK: - Button styles

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
