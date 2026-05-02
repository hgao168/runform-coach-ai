import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appStore: AppStore

    // Local draft — only committed to the store when Save is tapped
    @State private var draft = TesterProfile()
    @State private var saved = false
    @State private var isDirty = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        profileHero
                        formCard
                        saveButton
                        infoCard
                    }
                    .padding()
                }
            }
            .navigationTitle("User Profile")
            .onAppear { draft = appStore.profile; saved = false; isDirty = false }
        }
    }

    // MARK: - Hero

    private var profileHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.actionGradient).frame(width: 64, height: 64)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.black)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.nickname.isEmpty ? "Runner" : draft.nickname)
                    .font(.title2.bold())
                Text("\(draft.level.rawValue) • \(Int(draft.weeklyMileageKm)) km/week")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if saved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.cyan)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.3), value: saved)
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Your name", text: $draft.nickname)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft.nickname) { markDirty() }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Running level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Running level", selection: $draft.level) {
                    ForEach(RunnerLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.level) { markDirty() }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weekly distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(draft.weeklyMileageKm)) km")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $draft.weeklyMileageKm, in: 0...120, step: 1)
                    .tint(AppTheme.cyan)
                    .onChange(of: draft.weeklyMileageKm) { markDirty() }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Running goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. 10K, half marathon, general fitness", text: $draft.target)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft.target) { markDirty() }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Injury or pain note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Optional — e.g. left knee, tight calves", text: $draft.injuryNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                    .onChange(of: draft.injuryNote) { markDirty() }
            }
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button {
            appStore.profile = draft
            saved = true
            isDirty = false
        } label: {
            Label(saved && !isDirty ? "Profile Saved" : "Save Profile",
                  systemImage: saved && !isDirty ? "checkmark.circle.fill" : "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isDirty ? AppTheme.cyan : .secondary)
        .disabled(!isDirty)
        .animation(.easeInOut(duration: 0.2), value: isDirty)
    }

    // MARK: - Info

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How your profile is used", systemImage: "lightbulb.fill")
                .font(.headline)
            Text("Your details are stored locally on this device. RunForm uses your level, weekly distance, and goal to personalise training plans and movement recommendations.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    // MARK: - Helpers

    private func markDirty() {
        if !isDirty { isDirty = true }
        if saved { saved = false }
    }
}
