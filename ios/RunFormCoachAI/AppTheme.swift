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
