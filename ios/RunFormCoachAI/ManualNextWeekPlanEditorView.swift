import SwiftUI

struct ManualNextWeekPlanEditorView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var days: [ManualWeekDayPlan] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Next Week Plan")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                if let monday = days.first?.date, let sunday = days.last?.date {
                                    Text("Week range: \(monday, format: .dateTime.month().day()) - \(sunday, format: .dateTime.month().day())")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.68))
                                }
                                Text("Fill all 7 days manually. Week starts Monday and ends Sunday.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }

                        ForEach(days.indices, id: \.self) { index in
                            DarkCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(days[index].dayName)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text(days[index].date, format: .dateTime.month().day())
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.mint)
                                    }

                                    TextField("Enter plan for \(days[index].dayName)", text: binding(for: index), axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(2...4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Manual Week Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.75))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        appStore.saveManualNextWeekPlan(days: days)
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.mint)
                }
            }
            .onAppear {
                if let saved = appStore.manualNextWeekPlan {
                    days = saved.days.sorted { $0.date < $1.date }
                } else {
                    days = appStore.buildDefaultManualNextWeekPlan().days
                }
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { days[index].planText },
            set: { days[index].planText = $0 }
        )
    }
}
