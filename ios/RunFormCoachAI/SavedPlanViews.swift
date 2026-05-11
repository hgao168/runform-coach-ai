import SwiftUI

// MARK: - Saved Plans sheet

struct SavedPlansView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if appStore.savedPlans.isEmpty {
                    VStack(spacing: 16) {
                        IconBubble(systemImage: "bookmark", gradient: AppTheme.purpleGradient, size: 72)
                        Text("No saved plans yet")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Generate a plan and tap \"Save Plan\" to keep it here.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.horizontal, 34)
                    }
                } else {
                    List {
                        ForEach(appStore.savedPlans) { saved in
                            NavigationLink {
                                SavedPlanDetailView(saved: saved)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(saved.target)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("\(saved.plan.plannedWeeklyKm, specifier: "%.1f") km · \(saved.plan.runningDays) days")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.55))
                                    Text(saved.createdAt, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { appStore.savedPlans[$0].id }.forEach { appStore.deleteSavedPlan(id: $0) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Saved Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                Button("Done") { dismiss() }
                    .foregroundStyle(AppTheme.mint)
            }
        }
    }
}

struct SavedPlanDetailView: View {
    let saved: SavedPlan

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    TrainingPlanResultView(plan: saved.plan, planID: saved.id)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(saved.target)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
