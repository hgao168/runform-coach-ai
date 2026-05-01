import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        profileHero
                        formCard
                        whyCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
        }
    }

    private var profileHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle().fill(AppTheme.actionGradient).frame(width: 58, height: 58)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(appStore.profile.nickname.isEmpty ? "Test Runner" : appStore.profile.nickname)
                        .font(.title2.bold())
                    Text("\(appStore.profile.level.rawValue) • \(Int(appStore.profile.weeklyMileageKm)) km/week")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tester setup")
                .font(.headline)

            TextField("Nickname", text: $appStore.profile.nickname)
                .textFieldStyle(.roundedBorder)

            Picker("Running level", selection: $appStore.profile.level) {
                ForEach(RunnerLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weekly mileage")
                    Spacer()
                    Text("\(Int(appStore.profile.weeklyMileageKm)) km")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $appStore.profile.weeklyMileageKm, in: 0...120, step: 1)
                    .tint(AppTheme.cyan)
            }

            TextField("Goal, e.g. 10K, half marathon, fitness", text: $appStore.profile.target)
                .textFieldStyle(.roundedBorder)

            TextField("Any injury note? Optional", text: $appStore.profile.injuryNote, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why this matters", systemImage: "lightbulb.fill")
                .font(.headline)
            Text("Phase 1 stores this locally and uses it to understand tester feedback. Phase 2 can use it to personalize running plans and strength recommendations.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}
