import SwiftUI

struct AthleteRowView: View {
    let athlete: AthleteListItem

    private var initials: String {
        athlete.name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.actionGradient)
                    .frame(width: 50, height: 50)
                Text(initials)
                    .font(.headline.bold())
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(athlete.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(athlete.event)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.mint)
                Text(athlete.achievement)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.30))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
