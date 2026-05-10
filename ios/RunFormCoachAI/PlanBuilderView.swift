import SwiftUI

struct PlanBuilderView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var currentWeeklyKmText = "20"
    @State private var weeklyKmEditedByUser = false
    @State private var suppressWeeklyKmTracking = false
    @State private var target: TrainingTarget = .generalFitness
    @State private var marathonMajor: MarathonMajor = .berlin
    @State private var marathonPlanWeeks: Int = 16
    @State private var selectedRunDays: Set<Int> = [0, 2, 4]  // Mon Wed Fri default
    @State private var injuryFlag = false

    private var availableRunningDays: Int { selectedRunDays.count }

    private static func defaultRunDays(_ count: Int) -> Set<Int> {
        Set((0..<min(max(count, 1), 7)).map { $0 })
    }
    @State private var isGenerating = false
    @State private var plan: TrainingPlanResponse?
    @State private var errorMessage: String?
    @State private var showSavedPlans = false
    @State private var showManualPlanEditor = false
    @State private var showWeeklyPlanDetails = false
    @State private var showMarathonPlanDetails = false
    @FocusState private var kmFieldFocused: Bool

    private enum GenerationKind {
        case weekly
        case marathon
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        introCard
                        if appStore.manualNextWeekPlan != nil {
                            manualWeekPreviewCard
                        }
                        latestAnalysisCard
                        inputCard
                        generateButtons

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.callout)
                                .padding(.horizontal, 4)
                        }

                        if let plan { generatedPlanSections(plan) }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSavedPlans = true
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(AppTheme.mint)
                    }
                }
            }
            .onAppear {
                if plan == nil, let saved = appStore.nextWeekPlan {
                    plan = saved.plan
                    setWeeklyKmText(saved.weeklyKm)
                    weeklyKmEditedByUser = false
                    if let t = TrainingTarget(rawValue: saved.target) { target = t }
                } else if !weeklyKmEditedByUser {
                    setWeeklyKmText(appStore.profile.weeklyMileageKm)
                    selectedRunDays = Self.defaultRunDays(appStore.profile.runningDaysPerWeek)
                    if let t = TrainingTarget(rawValue: appStore.profile.target) { target = t }
                }
            }
            .onChange(of: appStore.profile.weeklyMileageKm) { mileage in
                if !weeklyKmEditedByUser {
                    setWeeklyKmText(mileage)
                }
            }
            .onChange(of: appStore.profile.runningDaysPerWeek) { days in
                selectedRunDays = Self.defaultRunDays(days)
            }
            .onChange(of: appStore.profile.target) { profileTarget in
                if let t = TrainingTarget(rawValue: profileTarget) { target = t }
            }
            .sheet(isPresented: $showSavedPlans) {
                SavedPlansView()
            }
            .sheet(isPresented: $showManualPlanEditor) {
                ManualNextWeekPlanEditorView()
            }
            .sheet(isPresented: $showWeeklyPlanDetails) {
                if let plan {
                    NavigationStack {
                        ZStack {
                            AppBackground()
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 14) {
                                    TrainingPlanResultView(
                                        plan: plan,
                                        planID: appStore.nextWeekPlan?.id,
                                        showMarathonBlock: false
                                    )
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 12)
                                .padding(.bottom, 24)
                            }
                        }
                        .navigationTitle("Weekly Plan Details")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showWeeklyPlanDetails = false }
                                    .foregroundStyle(AppTheme.mint)
                            }
                        }
                        .toolbarColorScheme(.dark, for: .navigationBar)
                    }
                }
            }
            .sheet(isPresented: $showMarathonPlanDetails) {
                if let marathonPlan = plan?.marathonPlan {
                    MarathonPlanDetailView(planBlock: marathonPlan) { selectedWeekKm in
                        setWeeklyKmText(selectedWeekKm)
                        weeklyKmEditedByUser = false
                    }
                }
            }
        }
    }

    private func generatedPlanSections(_ plan: TrainingPlanResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Generated plan", subtitle: nil, systemImage: "checkmark.circle.fill")

            DarkCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1) Weekly Planning")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Weekly target: \(plan.plannedWeeklyKm, specifier: "%.1f") km over \(plan.runningDays) running days.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                    Button {
                        showWeeklyPlanDetails = true
                    } label: {
                        HStack {
                            Label("View weekly plan details", systemImage: "link")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }

            if let marathonPlan = plan.marathonPlan {
                let boundaries = marathonPhaseLinks(from: marathonPlan.weeks)
                DarkCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2) Specific Marathon Training Plan")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(marathonPlan.race) • \(marathonPlan.planProfile) • \(marathonPlan.totalWeeks)-week block")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.mint)
                        Text("View details for all weeks and apply any week target km to weekly planning.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))

                        Button {
                            showMarathonPlanDetails = true
                        } label: {
                            HStack {
                                Label("View marathon plan details", systemImage: "link")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        if !boundaries.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Phase subsections")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.mint)
                                ForEach(boundaries) { boundary in
                                    Text("• \(boundary.label) W\(boundary.startWeek)-W\(boundary.endWeek)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }

    private func marathonPhaseLinks(from weeks: [MarathonPlanWeek]) -> [MarathonPhaseLink] {
        let sorted = weeks.sorted { $0.week < $1.week }
        guard let first = sorted.first else { return [] }

        var groups: [[MarathonPlanWeek]] = [[first]]
        for week in sorted.dropFirst() {
            if groups[groups.count - 1][0].phase == week.phase {
                groups[groups.count - 1].append(week)
            } else {
                groups.append([week])
            }
        }

        return groups.compactMap { group in
            guard let start = group.first, let end = group.last else { return nil }
            return MarathonPhaseLink(
                id: "\(start.phase)-\(start.week)-\(end.week)",
                label: start.phase,
                startWeek: start.week,
                endWeek: end.week,
                startTargetKm: start.targetKm,
                endTargetKm: end.targetKm,
                startLongRunKm: start.longRunKm,
                endLongRunKm: end.longRunKm,
                weeks: group
            )
        }
    }

    private func kmDeltaLabel(from current: Double, to target: Double) -> String {
        let delta = target - current
        let sign = delta >= 0 ? "+" : ""
        return String(format: "%@%.1f km", sign, delta)
    }

    private var introCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    IconBubble(systemImage: "calendar.badge.plus", gradient: AppTheme.purpleGradient, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Week Plan")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Set your goal, volume, and days. Get a smart weekly plan.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }

                Button {
                    dismissKeyboard()
                    showManualPlanEditor = true
                } label: {
                    HStack {
                        Label("Edit next week (Mon-Sun)", systemImage: "square.and.pencil")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                if let manual = appStore.manualNextWeekPlan {
                    Text("Saved week: \(manual.weekStartMonday, format: .dateTime.month().day()) - \(manual.weekEndSunday, format: .dateTime.month().day())")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
    }

    
    private var inputCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("Your inputs", subtitle: nil, systemImage: "slider.horizontal.3")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current weekly km")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("e.g. 20", text: $currentWeeklyKmText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($kmFieldFocused)
                        .onChange(of: currentWeeklyKmText) { _ in
                            if !suppressWeeklyKmTracking {
                                weeklyKmEditedByUser = true
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Picker("Target", selection: $target) {
                        ForEach(TrainingTarget.allCases) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.mint)
                }

                if target == .marathon {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("World Major")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Picker("Marathon major", selection: $marathonMajor) {
                            ForEach(MarathonMajor.allCases) { major in
                                Text(major.rawValue).tag(major)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.mint)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Block length")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Picker("Marathon plan weeks", selection: $marathonPlanWeeks) {
                            Text("12 weeks").tag(12)
                            Text("16 weeks").tag(16)
                        }
                        .pickerStyle(.segmented)
                        .tint(AppTheme.mint)
                    }

                    Label("Marathon block is only used when goal is Marathon.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Run days")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(selectedRunDays.count) day\(selectedRunDays.count == 1 ? "" : "s") selected")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.mint)
                    }
                    let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    HStack(spacing: 5) {
                        ForEach(dayLabels.indices, id: \.self) { i in
                            let selected = selectedRunDays.contains(i)
                            Button {
                                if selected {
                                    if selectedRunDays.count > 1 { selectedRunDays.remove(i) }
                                } else {
                                    selectedRunDays.insert(i)
                                }
                            } label: {
                                Text(dayLabels[i])
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(selected ? AppTheme.mint : .white.opacity(0.08))
                                    .foregroundStyle(selected ? Color.black : Color.white.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Toggle("Injury / pain flag", isOn: $injuryFlag)
                    .tint(AppTheme.mint)

                if injuryFlag {
                    Label("Progression will be reduced; hard sessions replaced with easy runs.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var latestAnalysisItem: AnalysisHistoryItem? { appStore.history.first }

    private var manualWeekPreviewCard: some View {
        let days = (appStore.manualNextWeekPlan?.days ?? []).sorted { $0.date < $1.date }
        return DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(
                    "Manual Week Preview",
                    subtitle: "Monday to Sunday",
                    systemImage: "calendar"
                )

                ForEach(days.prefix(7), id: \.id) { day in
                    HStack(alignment: .top, spacing: 8) {
                        Text(day.dayName.prefix(3).uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.mint)
                            .frame(width: 34, alignment: .leading)

                        Text(day.date, format: .dateTime.month().day())
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.58))
                            .frame(width: 52, alignment: .leading)

                        Text(day.planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : day.planText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var latestFormIssues: [String] {
        Array((latestAnalysisItem?.result.issues.map { $0.title } ?? []).prefix(5))
    }

    private var latestRecommendedExercises: [Exercise] {
        var seen = Set<String>()
        return (latestAnalysisItem?.result.issues.flatMap { $0.recommendedExercises } ?? [])
            .filter { exercise in
                guard !seen.contains(exercise.name) else { return false }
                seen.insert(exercise.name)
                return true
            }
    }

    private var latestAnalysisCard: some View {
        Group {
            if let latest = latestAnalysisItem {
                DarkCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(
                            "Connected coaching",
                            subtitle: "Using your latest form analysis to adjust the plan.",
                            systemImage: "link.circle.fill"
                        )
                        if latestFormIssues.isEmpty {
                            Text("No major form issue found in your latest analysis.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        } else {
                            ForEach(latestFormIssues, id: \.self) { issue in
                                Label(issue, systemImage: "figure.run.circle")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        }
                        Text("Latest analysis: \(latest.createdAt, format: .dateTime.month().day().hour().minute())")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
            } else {
                DarkCard {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(
                            "Connected coaching",
                            subtitle: "Generate an analysis first to personalise your plan.",
                            systemImage: "link.circle"
                        )
                        Text("Without an analysis, RunForm will create a plan from your weekly km, goal, days, and injury flag only.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
            }
        }
    }

    private var generateButtons: some View {
        HStack(spacing: 10) {
            Button {
                kmFieldFocused = false
                dismissKeyboard()
                Task { await generatePlan(kind: .weekly) }
            } label: {
                if isGenerating {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Weekly Plan", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(isGenerating)

            if target == .marathon {
                Button {
                    kmFieldFocused = false
                    dismissKeyboard()
                    Task { await generatePlan(kind: .marathon) }
                } label: {
                    Label("Marathon Plan", systemImage: "flag.pattern.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(isGenerating)
            }
        }
    }

    private func generatePlan(kind: GenerationKind) async {
        kmFieldFocused = false
        dismissKeyboard()

        if kind == .marathon && target != .marathon {
            errorMessage = "Select Marathon goal to generate a marathon block."
            return
        }

        guard let km = Double(currentWeeklyKmText.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = String(localized: "error.invalid_km")
            return
        }

        // Adapt volume/injury flag from last week's logged workout outcomes
        var adaptedKm = km
        var autoInjuryFlag = injuryFlag
        var previousWeekSummary: String? = nil

        if let logs = appStore.nextWeekPlan?.workoutLogs, !logs.isEmpty {
            let values = Array(logs.values)
            let painCount    = values.filter { $0 == .pain }.count
            let tooHardCount = values.filter { $0 == .tooHard }.count
            let skippedCount = values.filter { $0 == .skipped }.count
            let doneCount    = values.filter { $0 == .done }.count

            if painCount > 0    { autoInjuryFlag = true }
            if tooHardCount >= 2 { adaptedKm = (km * 0.90).rounded() }

            var parts: [String] = []
            if doneCount    > 0 { parts.append("\(doneCount) completed") }
            if skippedCount > 0 { parts.append("\(skippedCount) skipped") }
            if tooHardCount > 0 { parts.append("\(tooHardCount) too hard") }
            if painCount    > 0 { parts.append("\(painCount) caused pain") }
            var summary = "Last week: \(parts.joined(separator: ", "))."
            if tooHardCount >= 2 { summary += " Volume reduced 10% to \(Int(adaptedKm)) km." }
            if painCount    >  0 { summary += " Injury flag set automatically." }
            previousWeekSummary = summary
        }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let selectedDayNames = selectedRunDays.sorted().compactMap { i in
            i < dayLabels.count ? dayLabels[i] : nil
        }

        let input = TrainingPlanInput(
            currentWeeklyKm: adaptedKm,
            target: target.rawValue,
            availableRunningDays: availableRunningDays,
            selectedRunDays: selectedDayNames,
            injuryFlag: autoInjuryFlag,
            formIssues: appStore.latestCoachingIssues,
            recentAnalysisSummary: appStore.latestAnalysisSummary,
            recentAnalysisConfidence: appStore.latestAnalysisConfidence,
            previousWeekSummary: previousWeekSummary,
            language: Bundle.main.preferredLocalizations.first ?? "en",
            marathonMajor: target == .marathon ? marathonMajor.rawValue : nil,
            marathonPlanWeeks: target == .marathon ? marathonPlanWeeks : nil,
            includeMarathonBlock: kind == .marathon
        )

        do {
            let result = try await APIClient.shared.generateTrainingPlan(input: input)
            plan = result
            appStore.setNextWeekPlan(result, target: target.rawValue, weeklyKm: adaptedKm)
        } catch {
            errorMessage = String(localized: "error.plan_failed")
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func setWeeklyKmText(_ value: Double) {
        suppressWeeklyKmTracking = true
        currentWeeklyKmText = String(format: "%g", value)
        suppressWeeklyKmTracking = false
    }
}

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

// MARK: - Plan result views

struct TrainingPlanResultView: View {
    let plan: TrainingPlanResponse
    var planID: UUID? = nil
    var showMarathonBlock: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryCard
            if showMarathonBlock, let marathonPlan = plan.marathonPlan {
                marathonPlanCard(marathonPlan)
            }
            workoutList
            notesCard
        }
    }

    private func marathonPlanCard(_ marathonPlan: MarathonPlanBlock) -> some View {
        let boundaries = marathonPhaseBoundaries(marathonPlan.weeks)
        return DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Marathon Block")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(marathonPlan.race) • \(marathonPlan.totalWeeks) weeks")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.mint)
                Text(marathonPlan.courseProfile)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                Label(marathonPlan.elevationNote, systemImage: "mountain.2")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))

                if !boundaries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Phase boundaries")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.mint)
                        ForEach(boundaries, id: \.id) { boundary in
                            HStack(spacing: 8) {
                                Text(boundary.label)
                                    .font(.caption.bold())
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.actionGradient)
                                    .clipShape(Capsule())
                                Text("W\(boundary.startWeek)-W\(boundary.endWeek)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }

                ForEach(boundaries, id: \.id) { boundary in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(boundary.label) summary")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.mint)
                            Spacer()
                            Text("W\(boundary.startWeek)-W\(boundary.endWeek)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.70))
                        }
                        Text("Volume: \(boundary.startTargetKm, specifier: "%.1f") -> \(boundary.endTargetKm, specifier: "%.1f") km/week")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.72))
                        Text("Long run: \(boundary.startLongRunKm, specifier: "%.1f") -> \(boundary.endLongRunKm, specifier: "%.1f") km")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                        Text(boundary.sampleKeyWorkout)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .padding(8)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func marathonPhaseBoundaries(_ weeks: [MarathonPlanWeek]) -> [MarathonPhaseBoundary] {
        let sorted = weeks.sorted { $0.week < $1.week }
        guard let first = sorted.first else { return [] }

        var grouped: [[MarathonPlanWeek]] = [[first]]
        for week in sorted.dropFirst() {
            if grouped[grouped.count - 1][0].phase == week.phase {
                grouped[grouped.count - 1].append(week)
            } else {
                grouped.append([week])
            }
        }

        return grouped.compactMap { group in
            guard let start = group.first, let end = group.last else { return nil }
            return MarathonPhaseBoundary(
                id: "\(start.phase)-\(start.week)-\(end.week)",
                label: start.phase,
                startWeek: start.week,
                endWeek: end.week,
                startTargetKm: start.targetKm,
                endTargetKm: end.targetKm,
                startLongRunKm: start.longRunKm,
                endLongRunKm: end.longRunKm,
                sampleKeyWorkout: start.keyWorkout
            )
        }
    }

    private struct MarathonPhaseBoundary {
        let id: String
        let label: String
        let startWeek: Int
        let endWeek: Int
        let startTargetKm: Double
        let endTargetKm: Double
        let startLongRunKm: Double
        let endLongRunKm: Double
        let sampleKeyWorkout: String
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan Summary")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(plan.summary)
                    .foregroundStyle(.white.opacity(0.75))
                HStack {
                    Label("\(plan.plannedWeeklyKm, specifier: "%.1f") km", systemImage: "figure.run")
                    Spacer()
                    Label("\(plan.runningDays) days", systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                if plan.connectedAnalysisUsed {
                    Label("Adapted from your latest RunForm analysis", systemImage: "link.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.mint)
                }
            }
        }
    }

    private var workoutList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workouts")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
            ForEach(plan.workouts, id: \.id) { workout in
                WorkoutCard(workout: workout, planID: planID)
            }
        }
    }

    private var notesCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Coach Notes")
                    .font(.headline)
                    .foregroundStyle(.white)
                ForEach(plan.notes, id: \.self) { note in
                    Label(note, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

private struct MarathonPhaseLink: Identifiable {
    let id: String
    let label: String
    let startWeek: Int
    let endWeek: Int
    let startTargetKm: Double
    let endTargetKm: Double
    let startLongRunKm: Double
    let endLongRunKm: Double
    let weeks: [MarathonPlanWeek]
}

private struct MarathonPlanDetailView: View {
    let planBlock: MarathonPlanBlock
    let onUseWeekKm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    private var phaseGroups: [MarathonPhaseLink] {
        let sorted = planBlock.weeks.sorted { $0.week < $1.week }
        guard let first = sorted.first else { return [] }

        var groups: [[MarathonPlanWeek]] = [[first]]
        for week in sorted.dropFirst() {
            if groups[groups.count - 1][0].phase == week.phase {
                groups[groups.count - 1].append(week)
            } else {
                groups.append([week])
            }
        }

        return groups.compactMap { group in
            guard let start = group.first, let end = group.last else { return nil }
            return MarathonPhaseLink(
                id: "\(start.phase)-\(start.week)-\(end.week)",
                label: start.phase,
                startWeek: start.week,
                endWeek: end.week,
                startTargetKm: start.targetKm,
                endTargetKm: end.targetKm,
                startLongRunKm: start.longRunKm,
                endLongRunKm: end.longRunKm,
                weeks: group
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        DarkCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(planBlock.race) Marathon Block")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(planBlock.planProfile) • \(planBlock.totalWeeks) weeks")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.mint)
                                Text(planBlock.courseProfile)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                                Text(planBlock.elevationNote)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }

                        ForEach(phaseGroups) { group in
                            DarkCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(group.label) W\(group.startWeek)-W\(group.endWeek)")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Target: \(group.startTargetKm, specifier: "%.1f") -> \(group.endTargetKm, specifier: "%.1f") km/week")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.72))

                                    ForEach(group.weeks) { week in
                                        VStack(alignment: .leading, spacing: 6) {
                                            let isRaceWeek = isLastWeek(week)
                                            let displayTargetKm = isRaceWeek ? 47.7 : week.targetKm
                                            
                                            HStack {
                                                Text("Week \(week.week)")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.white)
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("\(displayTargetKm, specifier: "%.1f") km")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(AppTheme.mint)
                                                    if isRaceWeek {
                                                        Text("(Race week)")
                                                            .font(.caption2)
                                                            .foregroundStyle(AppTheme.orange)
                                                    }
                                                }
                                            }
                                            Text("Long run: \(week.longRunKm, specifier: "%.1f") km")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.66))
                                            Text(week.keyWorkout)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.78))

                                            if !week.workouts.isEmpty {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Weekly activities")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(AppTheme.mint)
                                                    ForEach(buildDisplayWorkouts(for: week), id: \.id) { workout in
                                                        HStack(alignment: .top, spacing: 6) {
                                                            Text(workout.day)
                                                                .font(.caption2.bold())
                                                                .foregroundStyle(.white)
                                                                .frame(width: 28, alignment: .leading)
                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text("\(workout.title) • \(workout.distanceKm ?? 0, specifier: "%.1f") km")
                                                                    .font(.caption2.bold())
                                                                    .foregroundStyle(.white.opacity(0.88))
                                                                Text(workout.details)
                                                                    .font(.caption2)
                                                                    .foregroundStyle(.white.opacity(0.68))
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(8)
                                        .background(.white.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Marathon Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.mint)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func buildDisplayWorkouts(for week: MarathonPlanWeek) -> [PlannedWorkout] {
        guard isLastWeek(week) else { return week.workouts }
        
        // For race week, modify Saturday and Sunday
        return week.workouts.map { workout in
            if workout.day.lowercased().contains("sun") {
                // Sunday is race day: 42.2k
                return PlannedWorkout(
                    day: workout.day,
                    title: "Marathon Race",
                    category: workout.category,
                    intensity: "race",
                    details: "Race day - 42.2k marathon",
                    purpose: workout.purpose,
                    distanceKm: 42.2,
                    durationMinutes: workout.durationMinutes,
                    coachingFocus: workout.coachingFocus
                )
            } else if workout.day.lowercased().contains("sat") {
                // Saturday is easy run: 5.5k
                return PlannedWorkout(
                    day: workout.day,
                    title: "Easy run",
                    category: "Easy",
                    intensity: "easy",
                    details: "Easy run before race",
                    purpose: "Recovery",
                    distanceKm: 5.5,
                    durationMinutes: 35,
                    coachingFocus: "Keep loose"
                )
            }
            return workout
        }
    }

    private func isLastWeek(_ week: MarathonPlanWeek) -> Bool {
        let allWeeks = planBlock.weeks.sorted { $0.week < $1.week }
        return week.week == allWeeks.last?.week
    }
}

struct WorkoutCard: View {
    @EnvironmentObject private var appStore: AppStore
    let workout: PlannedWorkout
    let planID: UUID?

    private var currentStatus: WorkoutStatus? {
        guard let planID else { return nil }
        return appStore.workoutStatus(planID: planID, workoutID: workout.id)
    }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.day)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.mint)
                        .frame(width: 38, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(workout.title))
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(LocalizedStringKey(workout.category))
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if let distanceKm = workout.distanceKm {
                        Text("\(distanceKm, specifier: "%.1f") km")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else if let durationMinutes = workout.durationMinutes {
                        Text("\(durationMinutes) min")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }

                Text(workout.intensity)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                Text(workout.details)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                if let focus = workout.coachingFocus {
                    Label(focus, systemImage: "figure.run.circle")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.mint)
                }
                Text("Why: \(workout.purpose)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))

                if let planID {
                    WorkoutStatusRow(
                        workoutID: workout.id,
                        planID: planID,
                        currentStatus: currentStatus
                    )
                }
            }
        }
    }
}

struct WorkoutStatusRow: View {
    @EnvironmentObject private var appStore: AppStore
    let workoutID: String
    let planID: UUID
    let currentStatus: WorkoutStatus?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WorkoutStatus.allCases) { status in
                Button {
                    // Tap again to deselect
                    let next: WorkoutStatus? = currentStatus == status ? nil : status
                    if let next {
                        appStore.logWorkout(planID: planID, workoutID: workoutID, status: next)
                    } else {
                        appStore.clearWorkoutLog(planID: planID, workoutID: workoutID)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                        Text(LocalizedStringKey(status.rawValue))
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(currentStatus == status ? .black : .white.opacity(0.65))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(currentStatus == status ? status.color : Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: currentStatus)
            }
        }
        .padding(.top, 4)
    }
}
