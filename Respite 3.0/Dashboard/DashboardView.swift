import SwiftUI
import FamilyControls
import Combine
import Foundation
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject private var interventions: InterventionManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @State private var now = Date()
    @StateObject private var sunTimes = SunTimesService()
    @StateObject private var dailyWeather = DailyWeatherService()
    @State private var animatedGreeting = ""
    @State private var greetingTypingTask: Task<Void, Never>?
    @State private var showBirthdayConfetti = false
    @State private var focusHistoryFilter: FocusHistoryFilter = .all
    @State private var insightsSnapshot = RecoveryInsightsStore.currentSnapshot()
    @State private var showWeeklyInsights = false
    @State private var weeklyInsightsMode: WeeklyInsightsMode = .recovery
    @State private var showAllAchievements = false
    @AppStorage("study.runtime.phase") private var runtimePhaseRaw = "focus"
    @AppStorage("study.runtime.isRunning") private var runtimeIsRunning = false
    @AppStorage("study.runtime.remainingPaused") private var runtimeRemainingPaused = 1500
    @AppStorage("study.runtime.endTimestamp") private var runtimeEndTimestamp = 0.0
    @AppStorage("study.runtime.focusMinutes") private var runtimeFocusMinutes = 25
    @AppStorage("study.runtime.sessionStartTimestamp") private var runtimeSessionStartTimestamp = 0.0
    @AppStorage("dev.ui.useTimePreview") private var useTimePreview = false
    @AppStorage("dev.ui.previewAuto") private var previewAuto = false
    @AppStorage("dev.ui.timePreviewHour") private var timePreviewHour = 12.0
    @AppStorage("dev.ui.frostedGlass") private var devFrostedGlass = true
    @AppStorage("dev.ui.disableCardTransparency") private var disableCardTransparency = false
    @AppStorage("dev.ui.colorIntensity") private var colorIntensity = 0.85
    @AppStorage("profile.displayName", store: UserDefaults(suiteName: RegulationAppGroup.id)) private var storedProfileName = "there"

    private let settings = RegulationSettingsStore()
    private let heartbeat = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerBlock
                    heroCard
                    statsGrid
                    streakCard
                    recoveryInsightsCard
                    focusQualityCard
                    antiRelapseCard
                    focusSessionsCard
                    achievementsCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .respiteTrackBottomBarScroll()
            .background(background)
            .overlay {
                if showBirthdayConfetti {
                    BirthdayConfettiView()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            now = Date()
            sunTimes.refresh()
            dailyWeather.refresh()
            refreshInsights()
            startGreetingTypingIfNeeded()
            triggerBirthdayCelebrationIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = Date()
                sunTimes.refresh()
                dailyWeather.refresh()
                refreshInsights()
                triggerBirthdayCelebrationIfNeeded()
                if animatedGreeting.isEmpty {
                    startGreetingTypingIfNeeded()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .respiteLaunchDidFinish)) { _ in
            startGreetingTypingIfNeeded()
        }
        .onDisappear {
            greetingTypingTask?.cancel()
        }
        .onReceive(heartbeat) { _ in
            now = Date()
            if Calendar.current.component(.second, from: now) % 15 == 0 {
                refreshInsights()
            }
        }
        .fullScreenCover(isPresented: $showWeeklyInsights) {
            WeeklyInsightsView(mode: weeklyInsightsMode)
        }
        .fullScreenCover(isPresented: $showAllAchievements) {
            AchievementsView()
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            // We intentionally render `animatedGreeting` as-is rather than
            // falling back to the full text while empty. The launch overlay
            // hides this view for the first ~1.7s, after which typing starts
            // from a blank string and builds up character-by-character — any
            // fallback here would cause a jump from "Good afternoon, Will"
            // back to "G" the moment the overlay finishes fading.
            Text(animatedGreeting)
                .font(.system(size: 34, weight: .semibold, design: .default))
                .foregroundStyle(dashTextPrimary)
                .frame(minHeight: 42, alignment: .leading)
            Text(daySubtitle)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(dashTextSecondary)
            if isBirthdayToday {
                Text("Birthday wishes")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextPrimary.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.08))
                    )
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sunRhythmCard
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 24)
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statTile(
                title: "Today",
                value: savedMinutesString,
                caption: "saved"
            )

            statTile(
                title: "This pace, 1 year",
                value: yearSavedString,
                caption: "saved"
            )
        }
    }

    private func statTile(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(dashTextSecondary)

            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundStyle(dashTextPrimary)

            Text(caption)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(dashTextMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 18)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Momentum streak")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(dashTextSecondary)
                    Text("\(currentStreakDays) day\(currentStreakDays == 1 ? "" : "s")")
                        .font(.system(size: 28, weight: .semibold, design: .default))
                        .foregroundStyle(dashTextPrimary)
                    Text("Goal: \(streakGoalMinutes) min saved/day")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(dashTextMuted)
                }

                Spacer()

                Image(systemName: hasMetStreakGoalToday ? "flame.fill" : "flame")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(hasMetStreakGoalToday ? .red : dashTextMuted)
            }

            HStack {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.14))
                        Capsule()
                            .fill(RespiteTheme.duskBlue.opacity(0.88))
                            .frame(width: proxy.size.width * streakGoalProgress)
                    }
                }
                .frame(height: 8)

                Text(streakProgressPercentText)
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextMuted)
            }

            if streakGoalProgress >= 1 {
                Text("Goal achieved")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(RespiteTheme.pine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 18)
    }

    private var recoveryInsightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recovery score")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(dashTextSecondary)
                Spacer()
                Text(insightsSnapshot.scoreLabel)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.10)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(insightsSnapshot.score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(dashTextPrimary)
                Text("/ 100")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextMuted)
            }

            HStack(spacing: 14) {
                metricPill(title: "7d avg", value: "\(insightsSnapshot.weeklyAverageMinutes)m")
                metricPill(title: "Trend", value: signedMinutes(insightsSnapshot.weeklyTrendMinutes))
                metricPill(title: "Consistency", value: percent(insightsSnapshot.consistencyRate))
            }

            Button("View weekly insights") {
                InteractionFeedback.tap()
                weeklyInsightsMode = .recovery
                showWeeklyInsights = true
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(RespiteTheme.duskBlue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 18)
    }

    private var focusQualityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Focus quality")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(dashTextSecondary)
                Spacer()
                Text(focusQualityLabel)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.10)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(focusQualityScore)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(dashTextPrimary)
                Text("/ 100")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextMuted)
            }

            HStack(spacing: 14) {
                metricPill(title: "7d avg", value: "\(focusQualityScore)")
                metricPill(title: "Manual ends", value: "\(focusManualEndRateText)")
                metricPill(title: "Sessions", value: "\(recentFocusSessions.count)")
            }

            Button("View weekly insights") {
                InteractionFeedback.tap()
                weeklyInsightsMode = .focusQuality
                showWeeklyInsights = true
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(RespiteTheme.duskBlue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 18)
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(dashTextSecondary)
                Spacer()
            }

            if achievementSnapshot.unlocked.isEmpty {
                Text("No badges unlocked yet. Keep completing focus sessions and reflections.")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(dashTextMuted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(achievementSnapshot.unlocked) { badge in
                            Label(badge.title, systemImage: badge.icon)
                                .font(.system(size: 11, weight: .semibold, design: .default))
                                .foregroundStyle(dashTextPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.08))
                                )
                        }
                    }
                }
            }

            Button("Show all achievements") {
                InteractionFeedback.tap()
                showAllAchievements = true
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(RespiteTheme.duskBlue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 18)
    }

    private var antiRelapseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Anti-relapse windows")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(dashTextSecondary)
                Spacer()
                Text(RecoveryInsightsStore.antiRelapseEnabled() ? "Active" : "Off")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundStyle(RecoveryInsightsStore.antiRelapseEnabled() ? RespiteTheme.pine : dashTextMuted)
            }

            if insightsSnapshot.riskWindows.isEmpty {
                Text("No high-risk windows detected yet. Keep logging focus sessions to personalize this.")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(dashTextMuted)
            } else {
                HStack(spacing: 8) {
                    ForEach(insightsSnapshot.riskWindows) { window in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(window.title)
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(dashTextPrimary)
                            Text("\(window.incidents) manual exits")
                                .font(.system(size: 11, weight: .medium, design: .default))
                                .foregroundStyle(dashTextMuted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.08))
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 18)
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundStyle(dashTextMuted)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(dashTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.08))
        )
    }

    private var focusSessionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus session history")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(dashTextPrimary)

            Picker("History filter", selection: $focusHistoryFilter) {
                ForEach(FocusHistoryFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if filteredFocusSessions.isEmpty {
                Text("No focus sessions ended yet.")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(dashTextMuted)
            } else {
                ForEach(filteredFocusSessions.prefix(6)) { session in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.sessionType)
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundStyle(dashTextPrimary)
                            Text(session.goal.isEmpty ? "No specific goal set" : session.goal)
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundStyle(dashTextSecondary)
                            Text(focusSessionStamp(session.endedAt))
                                .font(.system(size: 11, weight: .medium, design: .default))
                                .foregroundStyle(dashTextMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(session.completedMinutes)m")
                                .font(.system(size: 14, weight: .bold, design: .default))
                                .foregroundStyle(dashTextPrimary)
                            Text(session.endedManually ? "Ended manually" : "Completed")
                                .font(.system(size: 11, weight: .semibold, design: .default))
                                .foregroundStyle(session.endedManually ? dashTextMuted : RespiteTheme.pine)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var blockedAppsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Blocked app setup")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(dashTextPrimary)

            blockRow(label: "Daily limit", value: "\(dailyLimitAppsCount) apps")
            blockRow(label: "Intent gate", value: "\(intentGateAppsCount) apps")

            if blockedAppsCount == 0 {
                Text("No blocked apps selected yet. Add them in Settings.")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(dashTextMuted)
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func blockRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(dashTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(dashTextPrimary)
        }
    }


    private var background: some View {
        RespiteDynamicBackground()
    }

    private var sunRhythmCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SUNRISE")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(dashTextMuted)
                Text(formattedSunTime(sunTimes.sunrise, fallbackHour: 6, fallbackMinute: 30))
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextPrimary)
            }

            Spacer()

            VStack(spacing: 5) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(dashTextSecondary)
                Text(phaseLabel)
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.10)))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("SUNSET")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(dashTextMuted)
                Text(formattedSunTime(sunTimes.sunset, fallbackHour: 21, fallbackMinute: 0))
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(dashTextPrimary)
            }
        }
    }

    private var dayGreeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var fullGreetingText: String {
        "\(dayGreeting), \(displayName)"
    }

    private func startGreetingTypingIfNeeded() {
        if DashboardGreetingTypingState.didAnimateThisLaunch {
            greetingTypingTask?.cancel()
            animatedGreeting = fullGreetingText
            return
        }

        // Don't start typing while the branded launch overlay is still
        // covering the screen; a `.respiteLaunchDidFinish` notification
        // re-invokes this method the moment the overlay has fully faded.
        guard RespiteLaunchState.didFinish else {
            animatedGreeting = ""
            return
        }

        DashboardGreetingTypingState.didAnimateThisLaunch = true
        greetingTypingTask?.cancel()
        animatedGreeting = ""
        let targetChars = Array(fullGreetingText)

        greetingTypingTask = Task {
            for char in targetChars {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 24_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    animatedGreeting.append(char)
                }
            }
        }
    }

    private var displayName: String {
        let trimmed = storedProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "there" : trimmed
    }

    private var daySubtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return "\(formatter.string(from: now)) · \(dailyWeather.locationLabel) · \(dailyWeather.weatherLabel)"
    }

    private var savedMinutesString: String {
        formatMinutes(DailyProgressStore.minutesSavedToday())
    }

    private var yearSavedString: String {
        formatHoursMinutes(DailyProgressStore.projectedYearMinutes())
    }

    private var blockedAppsCount: Int {
        let dailyApps = settings.loadSelection()?.applicationTokens ?? []
        let intentApps = settings.loadTikTokSelection()?.applicationTokens ?? []
        return dailyApps.union(intentApps).count
    }

    private var streakGoalMinutes: Int {
        settings.streakGoalMinutes
    }

    private var focusQualityScore: Int {
        FocusInsightsStore.averageQuality(days: 7)
    }

    private var focusQualityLabel: String {
        switch focusQualityScore {
        case 85...100: return "Strong"
        case 70...84: return "Stable"
        case 50...69: return "Building"
        default: return "Needs support"
        }
    }

    private var focusManualEndRateText: String {
        guard !recentFocusSessions.isEmpty else { return "0%" }
        let manual = recentFocusSessions.filter(\.endedManually).count
        let rate = Double(manual) / Double(recentFocusSessions.count)
        return String(format: "%.0f%%", rate * 100)
    }

    private var currentStreakDays: Int {
        DailyProgressStore.currentStreak(goalMinutes: streakGoalMinutes)
    }

    private var hasMetStreakGoalToday: Bool {
        totalMinutesTowardGoalToday >= Double(max(1, streakGoalMinutes))
    }

    private var streakGoalProgress: Double {
        min(1.0, totalMinutesTowardGoalToday / Double(max(1, streakGoalMinutes)))
    }

    private var streakProgressPercentText: String {
        String(format: "%.1f%%", streakGoalProgress * 100.0)
    }

    private var totalMinutesTowardGoalToday: Double {
        Double(DailyProgressStore.minutesSavedToday()) + activeFocusInFlightMinutes
    }

    private var activeFocusInFlightMinutes: Double {
        guard runtimePhaseRaw == "focus" else { return 0 }
        guard runtimeSessionStartTimestamp > 0 else { return 0 }

        let plannedSeconds = max(0, runtimeFocusMinutes * 60)
        guard plannedSeconds > 0 else { return 0 }

        let remainingSeconds: Int
        if runtimeIsRunning && runtimeEndTimestamp > 0 {
            remainingSeconds = max(0, Int(runtimeEndTimestamp - Date().timeIntervalSince1970))
        } else {
            remainingSeconds = max(0, runtimeRemainingPaused)
        }

        let elapsed = max(0, plannedSeconds - remainingSeconds)
        return Double(elapsed) / 60.0
    }

    private var isBirthdayToday: Bool {
        guard let birthday = UserProfileStore.birthday() else { return false }
        let birth = Calendar.current.dateComponents([.month, .day], from: birthday)
        let today = Calendar.current.dateComponents([.month, .day], from: now)
        return birth.month == today.month && birth.day == today.day
    }

    private func triggerBirthdayCelebrationIfNeeded() {
        guard isBirthdayToday else {
            showBirthdayConfetti = false
            return
        }
        let currentYear = Calendar.current.component(.year, from: now)
        if UserProfileStore.lastBirthdayCelebratedYear() == currentYear {
            showBirthdayConfetti = false
            return
        }
        UserProfileStore.setLastBirthdayCelebratedYear(currentYear)
        showBirthdayConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeOut(duration: 0.6)) {
                showBirthdayConfetti = false
            }
        }
    }

    private func dayIndex(seed: Int) -> Int {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
        return day + seed
    }

    private var dailyLimitAppsCount: Int {
        (settings.loadSelection()?.applicationTokens.count) ?? 0
    }

    private var intentGateAppsCount: Int {
        (settings.loadTikTokSelection()?.applicationTokens.count) ?? 0
    }

    private var blockedAppsCaption: String {
        if blockedAppsCount == 0 { return "No apps selected yet" }
        return "Daily \(dailyLimitAppsCount) · Gate \(intentGateAppsCount)"
    }

    private var achievementSnapshot: AchievementSnapshot {
        AchievementsStore.snapshot(streakGoalMinutes: streakGoalMinutes)
    }

    private var recentFocusSessions: [StudyProgressStore.FocusSessionSummary] {
        StudyProgressStore.recentSessions(limit: 20)
    }

    private var filteredFocusSessions: [StudyProgressStore.FocusSessionSummary] {
        switch focusHistoryFilter {
        case .all:
            return recentFocusSessions
        case .completed:
            return recentFocusSessions.filter { !$0.endedManually }
        case .manual:
            return recentFocusSessions.filter { $0.endedManually }
        }
    }

    private func focusSessionStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date)
    }

    private func refreshInsights() {
        insightsSnapshot = RecoveryInsightsStore.currentSnapshot(now: now)
    }

    private func signedMinutes(_ value: Int) -> String {
        if value == 0 { return "0m" }
        return value > 0 ? "+\(value)m" : "\(value)m"
    }

    private func percent(_ value: Double) -> String {
        "\(Int((min(1.0, max(0.0, value)) * 100.0).rounded()))%"
    }

    private func formatMinutes(_ value: Int) -> String {
        if value < 60 { return "\(value)m" }
        let hours = value / 60
        let minutes = value % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    private func formatHoursMinutes(_ value: Int) -> String {
        let totalHours = max(0, value) / 60
        let days = totalHours / 24
        let hours = totalHours % 24
        return "\(days)d \(hours)h"
    }

    private var phaseLabel: String {
        let boundaries = sunPhaseBoundaries(for: now)
        let hour = decimalHour(now)
        if hour >= boundaries.sunrise, hour < boundaries.dayStart {
            return "Morning Rhythm"
        } else if hour < boundaries.eveningStart {
            return "Day Focus"
        } else if hour < boundaries.nightStart {
            return "Evening Winddown"
        } else {
            return "Night Reset"
        }
    }

    private func formattedSunTime(_ date: Date?, fallbackHour: Int, fallbackMinute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date ?? fallbackDate(hour: fallbackHour, minute: fallbackMinute, reference: now))
    }

    private func fallbackDate(hour: Int, minute: Int, reference: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components) ?? reference
    }

    private func decimalHour(_ date: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        return Double(hour) + (Double(minute) / 60.0)
    }

    private var clampedColorIntensity: Double {
        min(1.40, max(0.35, colorIntensity))
    }

    private func visualDate(from source: Date) -> Date {
        guard useTimePreview else { return source }
        if previewAuto {
            return autoPreviewDate(reference: source)
        }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: source)
        components.hour = Int(timePreviewHour) % 24
        components.minute = Int((timePreviewHour.truncatingRemainder(dividingBy: 1.0)) * 60.0)
        components.second = 0
        return Calendar.current.date(from: components) ?? source
    }

    private func autoPreviewDate(reference: Date) -> Date {
        guard let sunrise = sunTimes.sunrise, let sunset = sunTimes.sunset else {
            return reference
        }
        let sunriseHour = decimalHour(sunrise)
        let sunsetHour = decimalHour(sunset)
        let nowHour = decimalHour(reference)

        let autoHour: Double
        if nowHour < sunriseHour {
            autoHour = max(0, sunriseHour - 0.75)
        } else if nowHour > sunsetHour {
            autoHour = min(23.99, sunsetHour + 0.75)
        } else {
            autoHour = (sunriseHour + sunsetHour) / 2.0
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = Int(autoHour)
        components.minute = Int((autoHour.truncatingRemainder(dividingBy: 1.0)) * 60.0)
        components.second = 0
        return Calendar.current.date(from: components) ?? reference
    }

    private func decimalHourOrFallback(_ date: Date?, fallbackHour: Int, fallbackMinute: Int) -> Double {
        let value = date ?? fallbackDate(hour: fallbackHour, minute: fallbackMinute, reference: now)
        return decimalHour(value)
    }

    private func sunPhaseBoundaries(for date: Date) -> (sunrise: Double, dayStart: Double, eveningStart: Double, nightStart: Double) {
        let sunriseHour = decimalHourOrFallback(sunTimes.sunrise, fallbackHour: 6, fallbackMinute: 30)
        let sunsetHour = decimalHourOrFallback(sunTimes.sunset, fallbackHour: 21, fallbackMinute: 0)
        let safeSunset = max(sunsetHour, sunriseHour + 6.0)
        let dayStart = min(sunriseHour + 4.0, safeSunset - 3.0)
        let eveningStart = max(dayStart + 0.8, safeSunset - 2.0)
        let nightStart = safeSunset + 2.0
        return (sunriseHour, dayStart, eveningStart, nightStart)
    }

}

private enum FocusHistoryFilter: CaseIterable {
    case all
    case completed
    case manual

    var title: String {
        switch self {
        case .all: return "All"
        case .completed: return "Completed"
        case .manual: return "Manual Ended"
        }
    }
}

private enum DashboardGreetingTypingState {
    static var didAnimateThisLaunch = false
}

private extension DashboardView {
    var dashTextPrimary: Color { .primary }
    var dashTextSecondary: Color { .secondary }
    var dashTextMuted: Color { .secondary.opacity(0.9) }
}

private extension DashboardView {
    private struct PhaseGradient {
        let top: Color
        let middle: Color
        let bottom: Color
        let highlight: Color
        let accent: Color
    }

    private struct RGB {
        let r: Double
        let g: Double
        let b: Double
    }

    private func dayPhase(for date: Date, intensity: Double) -> PhaseGradient {
        let boundaries = sunPhaseBoundaries(for: date)
        let decimalHour = decimalHour(date)
        let wrappedHour = decimalHour < boundaries.sunrise ? decimalHour + 24.0 : decimalHour

        let stops: [(hour: Double, base: RGB)] = [
            (boundaries.sunrise, RGB(r: 0.56, g: 0.71, b: 0.38)),
            (boundaries.dayStart, RGB(r: 0.50, g: 0.76, b: 0.51)),
            (boundaries.eveningStart, RGB(r: 0.39, g: 0.61, b: 0.47)),
            (boundaries.nightStart, RGB(r: 0.38, g: 0.61, b: 0.67)),
            (boundaries.sunrise + 24.0, RGB(r: 0.56, g: 0.71, b: 0.38))
        ]

        guard let upperIndex = stops.firstIndex(where: { wrappedHour <= $0.hour }), upperIndex > 0 else {
            return makePhase(from: stops[0].base, hour: wrappedHour, intensity: intensity)
        }

        let lower = stops[upperIndex - 1]
        let upper = stops[upperIndex]
        let span = max(0.001, upper.hour - lower.hour)
        let blend = min(1.0, max(0.0, (wrappedHour - lower.hour) / span))

        let base = RGB(
            r: lower.base.r + ((upper.base.r - lower.base.r) * blend),
            g: lower.base.g + ((upper.base.g - lower.base.g) * blend),
            b: lower.base.b + ((upper.base.b - lower.base.b) * blend)
        )
        return makePhase(from: base, hour: wrappedHour, intensity: intensity)
    }

    private func makePhase(from base: RGB, hour: Double, intensity: Double) -> PhaseGradient {
        // Warmer accents near sunrise/sunset to simulate ceremony,
        // cooler during night hours.
        let sunsetFactor = smoothstep(edge0: 5.5, edge1: 8.0, x: hour) + smoothstep(edge0: 16.5, edge1: 20.0, x: hour)
        let warm = min(1.0, sunsetFactor)

        let top = color(from: shifted(base, r: -0.13, g: -0.13, b: -0.15), intensity: intensity)
        let middle = color(from: shifted(base, r: -0.02, g: -0.02, b: -0.04), intensity: intensity)
        let bottom = color(from: shifted(base, r: 0.03, g: 0.03, b: 0.01), intensity: intensity)

        let highlight = Color(
            red: adjustedChannel(0.56 + (0.34 * warm), intensity: intensity),
            green: adjustedChannel(0.80 - (0.16 * warm), intensity: intensity),
            blue: adjustedChannel(0.84 - (0.42 * warm), intensity: intensity)
        )
        let accent = Color(
            red: adjustedChannel(0.50 + (0.40 * warm), intensity: intensity),
            green: adjustedChannel(0.68 - (0.20 * warm), intensity: intensity),
            blue: adjustedChannel(0.74 - (0.48 * warm), intensity: intensity)
        )

        return PhaseGradient(top: top, middle: middle, bottom: bottom, highlight: highlight, accent: accent)
    }

    private func shifted(_ rgb: RGB, r: Double, g: Double, b: Double) -> RGB {
        RGB(
            r: min(1.0, max(0.0, rgb.r + r)),
            g: min(1.0, max(0.0, rgb.g + g)),
            b: min(1.0, max(0.0, rgb.b + b))
        )
    }

    private func color(from rgb: RGB, intensity: Double) -> Color {
        Color(
            red: adjustedChannel(rgb.r, intensity: intensity),
            green: adjustedChannel(rgb.g, intensity: intensity),
            blue: adjustedChannel(rgb.b, intensity: intensity)
        )
    }

    private func adjustedChannel(_ value: Double, intensity: Double) -> Double {
        let centered = value - 0.5
        return min(1.0, max(0.0, 0.5 + (centered * intensity)))
    }

    private func smoothstep(edge0: Double, edge1: Double, x: Double) -> Double {
        let t = min(1.0, max(0.0, (x - edge0) / max(0.001, edge1 - edge0)))
        return t * t * (3.0 - (2.0 * t))
    }
}

private struct DashboardTextureOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 10
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let n = noise(x: x, y: y)
                    let opacity = 0.03 + (0.03 * n)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                        with: .color(.white.opacity(opacity))
                    )
                    y += step
                }
                x += step
            }
        }
        .blendMode(.overlay)
        .opacity(0.42)
        .allowsHitTesting(false)
    }

    private func noise(x: CGFloat, y: CGFloat) -> Double {
        let value = sin((Double(x) * 12.9898) + (Double(y) * 78.233)) * 43758.5453
        return value - floor(value)
    }
}

private struct DashboardSmokeLayer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 24)) { context in
            GeometryReader { proxy in
                let t = context.date.timeIntervalSinceReferenceDate
                let driftA = sin(t / 110.0)
                let driftB = cos(t / 130.0)
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    Circle()
                        .fill(Color(red: 0.62, green: 0.33, blue: 0.18).opacity(0.23))
                        .frame(width: width * 1.0, height: height * 0.66)
                        .blur(radius: 52)
                        .offset(x: width * 0.26 * driftA, y: -height * 0.34)

                    Circle()
                        .fill(Color(red: 0.24, green: 0.30, blue: 0.40).opacity(0.20))
                        .frame(width: width * 0.88, height: height * 0.56)
                        .blur(radius: 48)
                        .offset(x: -width * 0.22 * driftB, y: height * 0.28)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BirthdayConfettiView: View {
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.04)) { context in
            GeometryReader { proxy in
                let elapsed = context.date.timeIntervalSince(startDate)
                ZStack {
                    ForEach(0..<92, id: \.self) { index in
                        let seed = Double(index) * 0.618
                        let delay = Double(index % 18) * 0.045
                        let life = max(0.0, elapsed - delay)
                        let travel = min(1.15, life / 2.6)
                        let spread = sin(seed * 2.4) * 0.42
                        let wobble = sin((life * 7.0) + seed) * 0.018
                        let x = 0.5 + spread + wobble
                        let y = (travel * travel) * 1.12 - 0.08
                        let size = 5 + CGFloat(index % 4)
                        let opacity = max(0.0, min(1.0, 1.0 - (travel * 0.55)))
                        confettiPiece(index: index, size: size)
                            .rotationEffect(.degrees((life * 210) + (seed * 180)))
                            .position(
                                x: proxy.size.width * CGFloat(max(0.03, min(0.97, x))),
                                y: proxy.size.height * CGFloat(y)
                            )
                            .opacity(opacity)
                    }
                }
            }
        }
        .transition(.opacity)
        .ignoresSafeArea()
        .onAppear {
            startDate = Date()
        }
    }

    private func confettiColor(for index: Int) -> Color {
        let colors: [Color] = [.yellow, .orange, .pink, .mint, .cyan, .blue, .purple, .white]
        return colors[index % colors.count]
    }

    @ViewBuilder
    private func confettiPiece(index: Int, size: CGFloat) -> some View {
        let color = confettiColor(for: index)
        if index % 3 == 0 {
            Capsule()
                .fill(color)
                .frame(width: size * 0.78, height: size * 1.9)
        } else if index % 3 == 1 {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: size * 0.95, height: size * 1.65)
        } else {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
    }
}

private struct DashboardGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let frosted: Bool
    let opaque: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let tintOpacity: Double = opaque ? 0.92 : (frosted ? 0.24 : 0.10)
        let tintColor: Color = colorScheme == .dark ? Color.white : Color.black
        let strokeColor: Color = (colorScheme == .dark ? Color.white : Color.black).opacity(opaque ? 0.16 : 0.22)
        if #available(iOS 26.0, *) {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(opaque ? Color.black.opacity(colorScheme == .dark ? 0.60 : 0.34) : .clear)
                        .glassEffect(.regular.tint(tintColor.opacity(colorScheme == .dark ? tintOpacity : 0.15)).interactive(false), in: .rect(cornerRadius: cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(strokeColor, lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            (colorScheme == .dark ? Color.white : Color.black).opacity(0.24),
                                            (colorScheme == .dark ? Color.white : Color.black).opacity(0.01)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.03), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                        .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
                }
        } else {
            content
                .background {
                    if opaque {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(colorScheme == .dark ? 0.60 : 0.34))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.16), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.20), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
                    }
                }
        }
    }
}

private extension View {
    func dashboardGlassCard(cornerRadius: CGFloat, frosted: Bool, opaque: Bool) -> some View {
        modifier(DashboardGlassCardModifier(cornerRadius: cornerRadius, frosted: frosted, opaque: opaque))
    }
}
