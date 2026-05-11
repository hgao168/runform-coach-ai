import SwiftUI

struct PlanBuilderView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var currentWeeklyKmText = "20"
    @State private var weeklyKmEditedByUser = false
    @State private var suppressWeeklyKmTracking = false
    @State private var weeklyKmSourceLabel = "Profile baseline"
    @State private var weeklyKmSourceDetail = "Using your saved profile weekly mileage."
    @State private var stravaSummary: StravaSummaryResponse?
    @State private var isLoadingStravaBaseline = false
    @State private var target: TrainingTarget = .generalFitness
    @State private var trainingLevel: TrainingLevel = .intermediate
    @State private var marathonMajor: MarathonMajor = .berlin
    @State private var marathonPlanWeeks: Int = 16
    @State private var selectedRunDays: Set<Int> = [0, 2, 4]  // Mon Wed Fri default
    @State private var injuryFlag = false
    @State private var planDurationWeeks: Int? = nil

    private var availableRunningDays: Int { selectedRunDays.count }

    private static func defaultRunDays(_ count: Int) -> Set<Int> {
        Set((0..<min(max(count, 1), 7)).map { $0 })
    }
    @State private var generatingKind: GenerationKind?
    @State private var plan: TrainingPlanResponse?
    @State private var errorMessage: String?
    @State private var showSavedPlans = false
    @State private var showManualPlanEditor = false
    @State private var showWeeklyPlanDetails = false
    @State private var showMarathonPlanDetails = false
    @State private var showRacePlanDetails = false
    @FocusState private var kmFieldFocused: Bool

    private enum GenerationKind {
        case weekly
        case marathon
        case race
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
                    weeklyKmSourceLabel = "Saved plan"
                    weeklyKmSourceDetail = "Using the weekly mileage from your last saved plan."
                    if let t = TrainingTarget(rawValue: saved.target) { target = t }
                } else if !weeklyKmEditedByUser {
                    setWeeklyKmText(appStore.profile.weeklyMileageKm)
                    selectedRunDays = Self.defaultRunDays(appStore.profile.runningDaysPerWeek)
                    if let t = TrainingTarget(rawValue: appStore.profile.target) { target = t }
                    weeklyKmSourceLabel = "Profile baseline"
                    weeklyKmSourceDetail = "Using your saved profile weekly mileage."
                }
            }
            .task {
                await refreshWeeklyKmBaseline()
            }
            .onChange(of: appStore.profile.weeklyMileageKm) { mileage in
                if !weeklyKmEditedByUser {
                    setWeeklyKmText(mileage)
                    weeklyKmSourceLabel = "Profile baseline"
                    weeklyKmSourceDetail = "Using your saved profile weekly mileage."
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
            .sheet(isPresented: $showRacePlanDetails) {
                if let racePlan = plan?.racePlan {
                    RacePlanDetailView(planBlock: racePlan) { selectedWeekKm in
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

            if let racePlan = plan.racePlan {
                let boundaries = racePlanPhaseLinks(from: racePlan.weeks)
                DarkCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2) Specific \(racePlan.target) Training Plan")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(racePlan.level) â€¢ \(racePlan.totalWeeks)-week block")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.mint)
                        Text("View details for all weeks and apply any week target km to weekly planning.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))

                        Button {
                            showRacePlanDetails = true
                        } label: {
                            HStack {
                                Label("View \(racePlan.target) plan details", systemImage: "link")
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
                                    Text("â€¢ \(boundary.label) W\(boundary.startWeek)-W\(boundary.endWeek)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }

            if let marathonPlan = plan.marathonPlan {
                let boundaries = marathonPhaseLinks(from: marathonPlan.weeks)
                DarkCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2) Specific Marathon Training Plan")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(marathonPlan.race) â€¢ \(marathonPlan.planProfile) â€¢ \(marathonPlan.totalWeeks)-week block")
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
                                    Text("â€¢ \(boundary.label) W\(boundary.startWeek)-W\(boundary.endWeek)")
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

    private func racePlanPhaseLinks(from weeks: [RacePlanWeek]) -> [MarathonPhaseLink] {
        let sorted = weeks.sorted { $0.week < $1.week }
        guard let first = sorted.first else { return [] }
        var groups: [[RacePlanWeek]] = [[first]]
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
                weeks: []
            )
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
                                weeklyKmSourceLabel = "Manual input"
                                weeklyKmSourceDetail = "You adjusted the weekly mileage by hand."
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        StatusBadge(text: weeklyKmSourceLabel)
                        if isLoadingStravaBaseline {
                            ProgressView()
                                .tint(AppTheme.mint)
                        }
                    }
                    Text(weeklyKmSourceDetail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.56))
                    if let stravaSummary {
                        Text("Strava average: \(String(format: "%.1f", stravaSummary.averageWeeklyKm)) km/week â€¢ \(stravaSummary.loadTrend)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.mint.opacity(0.88))
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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Training Level")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Picker("Training level", selection: $trainingLevel) {
                        ForEach(TrainingLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Plan Duration")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    let durationOptions = _getDurationOptionsForTarget(target, level: trainingLevel)
                    Picker("Plan duration", selection: $planDurationWeeks) {
                        Text("Auto").tag(Int?.none)
                        ForEach(durationOptions, id: \.self) { weeks in
                            Text("\(weeks) weeks").tag(Int?(weeks))
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

                    Label("Marathon block uses your Plan Duration selection above.", systemImage: "info.circle")
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
                        let hasStrava = stravaSummary != nil
                        SectionTitle(
                            "Connected coaching",
                            subtitle: hasStrava
                                ? "Using your latest form analysis and Strava runs to adjust plan."
                                : "Using your latest form analysis to adjust the plan.",
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
                        if let strava = stravaSummary {
                            Divider().background(.white.opacity(0.12))
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Strava data (last 4 weeks)", systemImage: "figure.outdoor.cycle")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.mint)
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Avg/week")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text(String(format: "%.1f km", strava.averageWeeklyKm))
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Runs")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text("\(strava.runCount)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Longest")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text(String(format: "%.1f km", strava.longestRunKm))
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Trend")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text(strava.loadTrend)
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
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
                        let hasStrava = stravaSummary != nil
                        SectionTitle(
                            "Connected coaching",
                            subtitle: hasStrava
                                ? "Using your Strava runs to adjust plan."
                                : "Generate an analysis or connect to Strava to personalise your plan.",
                            systemImage: hasStrava ? "link.circle.fill" : "link.circle"
                        )
                        if let strava = stravaSummary {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Strava data is active for plan generation", systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.mint)
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Avg/week")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text(String(format: "%.1f km", strava.averageWeeklyKm))
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Runs")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text("\(strava.runCount)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Longest")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text(String(format: "%.1f km", strava.longestRunKm))
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Trend")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text(strava.loadTrend)
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        } else {
                            Text("Without an analysis, RunForm will create a plan from your weekly km, goal, days, and injury flag only.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                }
            }
        }
    }

    private var raceBlockButtonLabel: String {
        switch target {
        case .fiveK: return "5K Plan"
        case .tenK: return "10K Plan"
        case .halfMarathon: return "Half Marathon Plan"
        case .marathon: return "Marathon Plan"
        default: return "Race Plan"
        }
    }

    private var generateButtons: some View {
        HStack(spacing: 10) {
            Button {
                kmFieldFocused = false
                dismissKeyboard()
                Task { await generatePlan(kind: .weekly) }
            } label: {
                if generatingKind == .weekly {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Weekly Plan", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(generatingKind != nil)

            if target == .marathon {
                Button {
                    kmFieldFocused = false
                    dismissKeyboard()
                    Task { await generatePlan(kind: .marathon) }
                } label: {
                    if generatingKind == .marathon {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Marathon Plan", systemImage: "flag.pattern.checkered")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(generatingKind != nil)
            } else if target == .fiveK || target == .tenK || target == .halfMarathon {
                Button {
                    kmFieldFocused = false
                    dismissKeyboard()
                    Task { await generatePlan(kind: .race) }
                } label: {
                    if generatingKind == .race {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label(raceBlockButtonLabel, systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(generatingKind != nil)
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

        generatingKind = kind
        errorMessage = nil
        defer { generatingKind = nil }

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
            marathonPlanWeeks: nil,
            includeMarathonBlock: kind == .marathon,
            stravaRunCount: stravaSummary?.runCount,
            stravaLongestRunKm: stravaSummary?.longestRunKm,
            stravaAvgPaceSPerKm: stravaSummary?.avgPaceSPerKm,
            stravaLoadTrend: stravaSummary?.loadTrend,
            trainingLevel: trainingLevel.rawValue,
            planDurationWeeks: planDurationWeeks,
            includeRaceBlock: kind == .race
        )

        do {
            let result = try await APIClient.shared.generateTrainingPlan(input: input)
            plan = result
            appStore.setNextWeekPlan(result, target: target.rawValue, weeklyKm: adaptedKm)
        } catch {
            errorMessage = String(localized: "error.plan_failed")
        }
    }

    @MainActor
    private func refreshWeeklyKmBaseline() async {
        guard !weeklyKmEditedByUser else { return }

        isLoadingStravaBaseline = true
        defer { isLoadingStravaBaseline = false }

        do {
            let summary = try await APIClient.shared.fetchStravaSummary(iosUserID: appStore.appUserID, weeks: 4)
            stravaSummary = summary

            if summary.averageWeeklyKm > 0 {
                setWeeklyKmText(summary.averageWeeklyKm)
                weeklyKmEditedByUser = false
                weeklyKmSourceLabel = "Strava baseline"
                weeklyKmSourceDetail = "Using synced Strava weekly mileage from the last 4 weeks."
                return
            }
        } catch {
            stravaSummary = nil
        }

        if !weeklyKmEditedByUser {
            setWeeklyKmText(appStore.profile.weeklyMileageKm)
            weeklyKmSourceLabel = "Profile baseline"
            weeklyKmSourceDetail = "Using your saved profile weekly mileage."
        }
    }

    private func _getDurationOptionsForTarget(_ target: TrainingTarget, level: TrainingLevel) -> [Int] {
        // Based on backlog durations: General Fitness (4-8 weeks / ongoing / ongoing),
        // 5K (8/10/12), 10K (10/12/12), Half (12/14/16), Marathon (12/16/user-choice)
        switch target {
        case .generalFitness:
            return [4, 6, 8]
        case .fiveK:
            if level == .beginner { return [8] }
            if level == .intermediate { return [10] }
            return [12]
        case .tenK:
            if level == .beginner { return [10] }
            if level == .intermediate { return [12] }
            return [12]
        case .halfMarathon:
            if level == .beginner { return [12] }
            if level == .intermediate { return [14] }
            return [16]
        case .marathon:
            return [12, 16]
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
