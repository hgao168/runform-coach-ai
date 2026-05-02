import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileHero
                        formCard
                        whyCard
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var profileHero: some View {
        GlassCard {
            HStack(spacing: 15) {
                IconBubble(systemImage: "person.crop.circle.fill", gradient: AppTheme.actionGradient, size: 62)
                VStack(alignment: .leading, spacing: 5) {
                    Text(appStore.profile.nickname.isEmpty ? "Test Runner" : appStore.profile.nickname)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("\(appStore.profile.level.rawValue) • \(Int(appStore.profile.weeklyMileageKm)) km/week")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
            }
        }
    }

    private var formCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle("Runner setup", subtitle: "Used to personalize TestFlight feedback", systemImage: "slider.horizontal.3")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nickname")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    TextField("Nickname", text: $appStore.profile.nickname)
                        .textInputAutocapitalization(.words)
                        .padding(13)
                        .background(.black.opacity(0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Running level")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    Picker("Running level", selection: $appStore.profile.level) {
                        ForEach(RunnerLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label("Weekly mileage", systemImage: "speedometer")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Text("\(Int(appStore.profile.weeklyMileageKm)) km")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.mint)
                    }
                    Slider(value: $appStore.profile.weeklyMileageKm, in: 0...120, step: 1)
                        .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    TextField("5K, 10K, half marathon, fitness", text: $appStore.profile.target)
                        .padding(13)
                        .background(.black.opacity(0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Injury note")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    TextField("Optional", text: $appStore.profile.injuryNote, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(13)
                        .background(.black.opacity(0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var whyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle("Why this matters", subtitle: "Better coaching needs context", systemImage: "lightbulb.fill")
                Text("RunForm stores this locally and uses it to understand tester feedback. Future versions can use it to personalize running plans and strength recommendations.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
    }
}
