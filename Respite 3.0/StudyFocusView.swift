import SwiftUI
import Foundation

struct StudyFocusView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    private enum Phase {
        case focus
        case breakTime

        var title: String {
            switch self {
            case .focus: return "Focus"
            case .breakTime: return "Break"
            }
        }

        var accent: Color {
            switch self {
            case .focus: return RespiteTheme.pine
            case .breakTime: return RespiteTheme.sageDeep
            }
        }
    }

    @State private var focusMinutes: Int = 25
    @State private var breakMinutes: Int = 5
    @State private var phase: Phase = .focus
    @State private var isRunning: Bool = false
    @State private var remainingSeconds: Int = 25 * 60
    @State private var tickerTask: Task<Void, Never>?
    @State private var completedFocusMinutesToday: Int = StudyProgressStore.focusMinutesToday()
    @State private var showFullscreenFocusMode: Bool = false
    @State private var showStartCheckIn = false
    @State private var showEndConfirmation = false
    @State private var focusSessionType: FocusSessionType = .study
    @State private var focusSessionGoal: String = ""
    @State private var sessionStartDate: Date?
    @State private var selectedProtocol: FocusProtocolPreset = .steady
    @State private var reviewSession: StudyProgressStore.FocusSessionSummary?
    @State private var showPostSessionReview = false
    @State private var reviewWorkedText = ""
    @State private var reviewDistractionText = ""
    @State private var reviewCommitmentText = ""
    @State private var encouragementPresetIndex: Int = 0
    @State private var customEncouragementInput: String = ""
    @State private var showCustomPresetSheet = false
    @State private var customPresetFocus = 25
    @State private var customPresetBreak = 5
    @State private var sessionTargetCycles: Int = 4
    @State private var completedCyclesInSession: Int = 0
    @State private var smartPlannerGlow = false

    @AppStorage("study.runtime.phase") private var runtimePhaseRaw = "focus"
    @AppStorage("study.runtime.isRunning") private var runtimeIsRunning = false
    @AppStorage("study.runtime.remainingPaused") private var runtimeRemainingPaused = 1500
    @AppStorage("study.runtime.endTimestamp") private var runtimeEndTimestamp = 0.0
    @AppStorage("study.runtime.focusMinutes") private var runtimeFocusMinutes = 25
    @AppStorage("study.runtime.breakMinutes") private var runtimeBreakMinutes = 5
    @AppStorage("study.runtime.sessionType") private var runtimeSessionTypeRaw = FocusSessionType.study.rawValue
    @AppStorage("study.runtime.sessionGoal") private var runtimeSessionGoal = ""
    @AppStorage("study.runtime.sessionStartTimestamp") private var runtimeSessionStartTimestamp = 0.0
    @AppStorage("study.runtime.sessionTargetCycles") private var runtimeSessionTargetCycles = 4
    @AppStorage("study.runtime.completedCycles") private var runtimeCompletedCycles = 0
    @AppStorage("reflection.focusPromptSuggestion") private var reflectionFocusPromptSuggestion = ""
    @AppStorage("study.customEncouragement") private var customEncouragement = ""

    private var textPrimary: Color { .primary }
    private var textSecondary: Color { .secondary }
    private var textMuted: Color { .secondary.opacity(0.9) }
    private let settings = RegulationSettingsStore()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        header
                        topFocusedTimeCard
                        controlsCard
                        insightsCard

                        if proxy.size.width > proxy.size.height {
                            HStack(spacing: 12) {
                                clockCard
                                encouragementCard
                            }
                        } else {
                            clockCard
                            encouragementCard
                        }

                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .respiteTrackBottomBarScroll()
                .background(RespiteDynamicBackground())
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onDisappear {
            tickerTask?.cancel()
        }
        .onAppear {
            restoreRuntimeState()
            encouragementPresetIndex = dayIndex(seed: 17) % max(1, focusPresets.count)
            customEncouragementInput = customEncouragement
            if !smartPlannerGlow {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    smartPlannerGlow = true
                }
            }
            syncLiveActivity()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                restoreRuntimeState()
                syncLiveActivity()
            } else if phase == .background {
                persistRuntimeState()
            }
        }
        .fullScreenCover(isPresented: $showFullscreenFocusMode) {
            fullscreenFocusModeView
        }
        .sheet(isPresented: $showStartCheckIn) {
            startCheckInSheet
        }
        .sheet(isPresented: $showEndConfirmation) {
            endSessionConfirmationSheet
        }
        .sheet(isPresented: $showPostSessionReview) {
            postSessionReviewSheet
        }
        .sheet(isPresented: $showCustomPresetSheet) {
            customPresetSheet
        }
    }

    private var header: some View {
        Text("Focus Sessions")
            .font(.system(size: 34, weight: .semibold, design: .default))
            .foregroundStyle(textPrimary)
    }

    private var topFocusedTimeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's focused time")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(textMuted)
                Text("\(completedFocusMinutesToday) min saved for meaningful work")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(textPrimary)
            }
            Spacer()
            Image(systemName: "leaf.fill")
                .foregroundStyle(RespiteTheme.sageLight)
                .font(.system(size: 18, weight: .semibold))
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var fullscreenFocusModeView: some View {
        GeometryReader { proxy in
            ZStack {
                RespiteDynamicBackground().ignoresSafeArea()

                VStack(spacing: 18) {
                    HStack {
                        Spacer()
                        Button {
                            showFullscreenFocusMode = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.white.opacity(0.16)))
                        }
                    }

                    if proxy.size.width > proxy.size.height {
                        HStack(spacing: 24) {
                            VStack(spacing: 12) {
                                StudyClockDial(progress: progress, accent: phase.accent, tickCount: 60, showShadow: true)
                                    .frame(width: min(260, proxy.size.height * 0.6), height: min(260, proxy.size.height * 0.6))
                                Text(timeString(remainingSeconds))
                                    .font(.system(size: 58, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(alignment: .leading, spacing: 14) {
                                Text(phase == .focus ? focusLine : breakLine)
                                    .font(.system(size: 31, weight: .semibold, design: .default))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(phase == .focus
                                     ? "One task. One block. Leave distractions out of reach."
                                     : "Small break now, stronger focus next block.")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                                    .fixedSize(horizontal: false, vertical: true)

                                fullscreenSessionTimeline
                                fullscreenGoalProgress

                                Button(isRunning ? "Pause" : "Resume") {
                                    InteractionFeedback.tap()
                                    isRunning ? pauseTimer() : startTimerIfNeeded()
                                }
                                .buttonStyle(FullScreenActionButton(fill: phase.accent))

                                Button("End") {
                                    InteractionFeedback.warning()
                                    showEndConfirmation = true
                                }
                                .buttonStyle(FullScreenActionButton(fill: .white.opacity(0.16)))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(spacing: 12) {
                            StudyClockDial(progress: progress, accent: phase.accent, tickCount: 60, showShadow: true)
                                .frame(width: 220, height: 220)
                            Text(timeString(remainingSeconds))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(phase == .focus ? focusLine : breakLine)
                                .font(.system(size: 24, weight: .semibold, design: .default))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            fullscreenSessionTimeline
                            fullscreenGoalProgress
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if proxy.size.width <= proxy.size.height {
                        HStack(spacing: 10) {
                            Button(isRunning ? "Pause" : "Resume") {
                                InteractionFeedback.tap()
                                isRunning ? pauseTimer() : startTimerIfNeeded()
                            }
                            .buttonStyle(FullScreenActionButton(fill: phase.accent))

                            Button("End") {
                                InteractionFeedback.warning()
                                showEndConfirmation = true
                            }
                            .buttonStyle(FullScreenActionButton(fill: .white.opacity(0.16)))
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
        }
        .statusBarHidden(false)
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pomodoro settings")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            VStack(spacing: 12) {
                durationSlider(title: "Focus", value: $focusMinutes, range: 10...90, step: 5, tint: RespiteTheme.duskBlue)
                durationSlider(title: "Break", value: $breakMinutes, range: 5...30, step: 5, tint: RespiteTheme.pine)
            }

            HStack {
                Text("Session blocks")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Spacer()
                Button("−") {
                    guard !isRunning else { return }
                    sessionTargetCycles = max(1, sessionTargetCycles - 1)
                    persistRuntimeState()
                    InteractionFeedback.tap()
                }
                .buttonStyle(SecondaryActionButton())
                Text("\(sessionTargetCycles)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .frame(minWidth: 28)
                Button("+") {
                    guard !isRunning else { return }
                    sessionTargetCycles = min(12, sessionTargetCycles + 1)
                    persistRuntimeState()
                    InteractionFeedback.tap()
                }
                .buttonStyle(SecondaryActionButton())
            }

            HStack(spacing: 8) {
                Button(isRunning ? "Pause" : "Start") {
                    InteractionFeedback.tap()
                    if isRunning {
                        pauseTimer()
                    } else {
                        showStartCheckIn = true
                    }
                }
                .buttonStyle(PrimaryActionButton(color: phase.accent))

                Button("End") {
                    InteractionFeedback.warning()
                    showEndConfirmation = true
                }
                .buttonStyle(SecondaryActionButton())
            }

            HStack(spacing: 8) {
                quickPresetButton("25/5", focus: 25, breakTime: 5, cycles: 4)
                quickPresetButton("50/10", focus: 50, breakTime: 10, cycles: 2)
                quickPresetButton("90/15", focus: 90, breakTime: 15, cycles: 1)
                Button("Custom") {
                    InteractionFeedback.tap()
                    customPresetFocus = focusMinutes
                    customPresetBreak = breakMinutes
                    showCustomPresetSheet = true
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(RespiteTheme.duskBlue.opacity(0.12))
                )
            }


        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus insights")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text("Quality \(FocusInsightsStore.averageQuality(days: 7))/100")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(RespiteTheme.duskBlue.opacity(0.18)))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Smart planner")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Text("\(plannerRecommendation.focusMinutes)m focus • \(plannerRecommendation.breakMinutes)m break")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Text("Includes session blocks")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
                Button("Apply recommendation") {
                    InteractionFeedback.tap()
                    applyPlannerRecommendation()
                }
                .buttonStyle(SecondaryActionButton())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.14), lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.57, blue: 0.92).opacity(0.55),
                                Color(red: 0.10, green: 0.72, blue: 0.62).opacity(0.50)
                            ],
                            startPoint: smartPlannerGlow ? .topLeading : .leading,
                            endPoint: smartPlannerGlow ? .bottomTrailing : .trailing
                        ),
                        lineWidth: 1.15
                    )
                    .blur(radius: 5.5)
                    .opacity(0.55)
                    .padding(-2)
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(FocusProtocolPreset.allCases, id: \.self) { preset in
                        Button(preset.title) {
                            InteractionFeedback.tap()
                            selectedProtocol = preset
                            applyProtocolPreset(preset)
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedProtocol == preset ? .white : textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedProtocol == preset ? RespiteTheme.pine : RespiteTheme.duskBlue.opacity(0.10))
                        )
                    }
                }
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func quickPresetButton(_ label: String, focus: Int, breakTime: Int, cycles: Int) -> some View {
        Button(label) {
            InteractionFeedback.tap()
            guard !isRunning else { return }
            focusMinutes = focus
            breakMinutes = breakTime
            sessionTargetCycles = max(1, cycles)
            completedCyclesInSession = 0
            runtimeCompletedCycles = 0
            remainingSeconds = (phase == .focus ? focus : breakTime) * 60
            persistRuntimeState()
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(RespiteTheme.duskBlue.opacity(0.12))
        )
    }

    private func durationSlider(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text("\(value.wrappedValue) min")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
            }

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: {
                        let snapped = Int(($0 / Double(step)).rounded()) * step
                        value.wrappedValue = min(range.upperBound, max(range.lowerBound, snapped))
                        resetIfIdle()
                    }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step),
                onEditingChanged: { editing in
                    if !editing { InteractionFeedback.tap() }
                }
            )
            .tint(tint)
        }
    }

    private var clockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(phase.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(phase.accent)
                Spacer()
                Text(isRunning ? "Running" : "Ready")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
            }

            HStack(spacing: 18) {
                StudyClockDial(progress: progress, accent: phase.accent, tickCount: 36, showShadow: false)
                    .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 4) {
                    Text(timeString(remainingSeconds))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            sessionProgressSection

            Button {
                InteractionFeedback.tap()
                showFullscreenFocusMode = true
            } label: {
                Label("Fullscreen focus mode", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButton())
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var encouragementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Encouragement", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text(phase.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(phase.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(phase.accent.opacity(0.14)))
            }

            Text(phase == .focus ? focusLine : breakLine)
                .font(.system(size: 20, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Reshuffle") {
                    InteractionFeedback.tap()
                    reshuffleEncouragement()
                }
                .buttonStyle(SecondaryActionButton())

                Button("Save") {
                    InteractionFeedback.tap()
                    let trimmed = customEncouragementInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        customEncouragement = trimmed
                    }
                }
                .buttonStyle(SecondaryActionButton())
            }

            TextField("Add your own encouragement", text: $customEncouragementInput)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.16), lineWidth: 1)
                        )
                )

        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), phase.accent.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .respiteGlassCard(cornerRadius: 20)
        .onAppear {
            customEncouragementInput = customEncouragement
        }
    }

    private var startCheckInSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Start focus session")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(textPrimary)

                Text("Choose your session type and set a clear goal.")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(textSecondary)

                Picker("Session type", selection: $focusSessionType) {
                    ForEach(FocusSessionType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Goal (example: finish chapter 4 notes)", text: $focusSessionGoal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.16), lineWidth: 1)
                            )
                    )

                HStack(spacing: 8) {
                    goalTemplateChip("Deep reading")
                    goalTemplateChip("Problem set")
                    goalTemplateChip("Review notes")
                    goalTemplateChip("Writing")
                }

                HStack(spacing: 10) {
                    Button("Cancel") {
                        InteractionFeedback.tap()
                        showStartCheckIn = false
                    }
                    .buttonStyle(SecondaryActionButton())

                    Button("Start") {
                        InteractionFeedback.success()
                        showStartCheckIn = false
                        completedCyclesInSession = 0
                        runtimeCompletedCycles = 0
                        phase = .focus
                        remainingSeconds = focusMinutes * 60
                        runtimePhaseRaw = "focus"
                        sessionStartDate = .now
                        runtimeSessionStartTimestamp = sessionStartDate?.timeIntervalSince1970 ?? 0
                        startTimerIfNeeded()
                    }
                    .buttonStyle(PrimaryActionButton(color: phase.accent))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RespiteDynamicBackground().ignoresSafeArea())
        }
        .presentationDetents([.medium])
    }

    private var endSessionConfirmationSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("End focus session?")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(textPrimary)
                Text("If you end now, this session will be saved with its current progress.")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(textSecondary)

                HStack(spacing: 10) {
                    Button("Keep session") {
                        InteractionFeedback.tap()
                        showEndConfirmation = false
                    }
                    .buttonStyle(SecondaryActionButton())

                    Button("End session") {
                        InteractionFeedback.warning()
                        showEndConfirmation = false
                        endSession()
                        showFullscreenFocusMode = false
                    }
                    .buttonStyle(PrimaryActionButton(color: .red.opacity(0.8)))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RespiteDynamicBackground().ignoresSafeArea())
        }
        .presentationDetents([.fraction(0.34)])
    }


    private var customPresetSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom preset")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(textPrimary)

                stepperRow(title: "Focus", value: $customPresetFocus, range: 10...120, step: 5)
                stepperRow(title: "Break", value: $customPresetBreak, range: 5...45, step: 5)

                HStack(spacing: 10) {
                    Button("Cancel") {
                        InteractionFeedback.tap()
                        showCustomPresetSheet = false
                    }
                    .buttonStyle(SecondaryActionButton())

                    Button("Apply") {
                        InteractionFeedback.success()
                        focusMinutes = customPresetFocus
                        breakMinutes = customPresetBreak
                        sessionTargetCycles = recommendedCycleCount(forFocusMinutes: customPresetFocus)
                        completedCyclesInSession = 0
                        runtimeCompletedCycles = 0
                        remainingSeconds = (phase == .focus ? focusMinutes : breakMinutes) * 60
                        persistRuntimeState()
                        showCustomPresetSheet = false
                    }
                    .buttonStyle(PrimaryActionButton(color: RespiteTheme.pine))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RespiteDynamicBackground().ignoresSafeArea())
        }
        .presentationDetents([.fraction(0.35)])
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
            Spacer()
            Button("−") {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                InteractionFeedback.tap()
            }
            .buttonStyle(SecondaryActionButton())
            Text("\(value.wrappedValue)m")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .frame(minWidth: 52)
            Button("+") {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                InteractionFeedback.tap()
            }
            .buttonStyle(SecondaryActionButton())
        }
    }

    private var postSessionReviewSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Post-session review")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(textPrimary)

                if let reviewSession {
                    Text("Quality score: \(FocusInsightsStore.qualityScore(for: reviewSession))/100")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary)
                }

                reviewTextField("What worked well?", text: $reviewWorkedText)
                reviewTextField("What distracted you?", text: $reviewDistractionText)
                reviewTextField("What is your next commitment?", text: $reviewCommitmentText)

                HStack(spacing: 10) {
                    Button("Skip") {
                        InteractionFeedback.tap()
                        clearReviewState()
                    }
                    .buttonStyle(SecondaryActionButton())

                    Button("Save review") {
                        InteractionFeedback.success()
                        saveReviewIfPossible()
                        clearReviewState()
                    }
                    .buttonStyle(PrimaryActionButton(color: RespiteTheme.pine))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RespiteDynamicBackground().ignoresSafeArea())
        }
        .presentationDetents([.medium])
    }

    private func reviewTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary)
            TextField(title, text: text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.16), lineWidth: 1)
                        )
                )
        }
    }

    private var phaseDurationSeconds: Int {
        (phase == .focus ? focusMinutes : breakMinutes) * 60
    }

    private var progress: Double {
        guard phaseDurationSeconds > 0 else { return 0 }
        return min(1.0, max(0.0, Double(phaseDurationSeconds - remainingSeconds) / Double(phaseDurationSeconds)))
    }

    private var sessionProgressValue: Double {
        let target = Double(max(1, sessionTargetCycles))
        let inFlight = phase == .focus ? progress : 0
        return min(1.0, max(0.0, (Double(completedCyclesInSession) + inFlight) / target))
    }

    private var currentBlockLabel: String {
        if phase == .focus {
            let block = min(sessionTargetCycles, completedCyclesInSession + 1)
            return "Block \(block) of \(sessionTargetCycles)"
        }
        return "Break after block \(completedCyclesInSession)"
    }

    private var sessionProgressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Session progress")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text(currentBlockLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.12))
                    Capsule()
                        .fill(phase.accent.opacity(0.85))
                        .frame(width: proxy.size.width * sessionProgressValue)
                }
            }
            .frame(height: 8)

            Text("Completed \(completedCyclesInSession) / \(sessionTargetCycles) focus blocks")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)
        }
    }

    private func recommendedCycleCount(forFocusMinutes focus: Int) -> Int {
        let targetFocusMinutesPerSession = 100
        let cycles = Int((Double(targetFocusMinutesPerSession) / Double(max(1, focus))).rounded())
        return min(12, max(1, cycles))
    }

    private var focusPresets: [String] {
        [
            "A quiet hour now protects your future attention.",
            "Choose one task and give it your full signal.",
            "The work gets lighter when your focus gets deeper.",
            "Keep the signal clear and the noise low."
        ]
    }

    private var breakPresets: [String] {
        [
            "Recovery is part of discipline.",
            "A short pause keeps your next block sharp.",
            "Reset your body, then return clear.",
            "Take the pause now so your next block is cleaner."
        ]
    }

    private var focusLine: String {
        let custom = customEncouragement.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            return custom
        }
        let index = min(max(0, encouragementPresetIndex), focusPresets.count - 1)
        return focusPresets[index]
    }

    private var breakLine: String {
        let index = min(max(0, encouragementPresetIndex), breakPresets.count - 1)
        return breakPresets[index]
    }

    private func dayIndex(seed: Int) -> Int {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return day + seed
    }

    private func reshuffleEncouragement() {
        guard focusPresets.count > 1 else { return }
        var next = Int.random(in: 0..<focusPresets.count)
        while next == encouragementPresetIndex {
            next = Int.random(in: 0..<focusPresets.count)
        }
        encouragementPresetIndex = next
    }

    private func startTimerIfNeeded() {
        if remainingSeconds <= 0 {
            remainingSeconds = phaseDurationSeconds
        }
        if sessionStartDate == nil && phase == .focus {
            sessionStartDate = .now
            runtimeSessionStartTimestamp = sessionStartDate?.timeIntervalSince1970 ?? 0
        }
        isRunning = true
        runtimeIsRunning = true
        runtimeEndTimestamp = Date().addingTimeInterval(TimeInterval(remainingSeconds)).timeIntervalSince1970
        persistRuntimeState()
        runTicker()
        syncLiveActivity()
    }

    private func runTicker() {
        tickerTask?.cancel()
        tickerTask = Task {
            while !Task.isCancelled && isRunning {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard isRunning else { return }
                    remainingSeconds = max(0, Int(runtimeEndTimestamp - Date().timeIntervalSince1970))
                    if remainingSeconds == 0 {
                        handlePhaseCompletion()
                        return
                    }
                    persistRuntimeState()
                    syncLiveActivity()
                }
            }
        }
    }

    private func pauseTimer() {
        refreshRemainingFromClock()
        isRunning = false
        runtimeIsRunning = false
        runtimeRemainingPaused = remainingSeconds
        runtimeEndTimestamp = 0
        persistRuntimeState()
        tickerTask?.cancel()
        syncLiveActivity()
    }

    private func endSession() {
        let wasRunning = isRunning
        refreshRemainingFromClock()
        if let summary = currentSessionSummary(manuallyEnded: true) {
            StudyProgressStore.recordSession(summary)
            reviewSession = summary
            showPostSessionReview = true
        }
        pauseTimer()
        phase = .focus
        remainingSeconds = focusMinutes * 60
        sessionStartDate = nil
        runtimeSessionStartTimestamp = 0
        runtimePhaseRaw = "focus"
        completedCyclesInSession = 0
        runtimeCompletedCycles = 0
        runtimeRemainingPaused = remainingSeconds
        if wasRunning {
            completedFocusMinutesToday = StudyProgressStore.focusMinutesToday()
        }
        StudyLiveActivityManager.end()
    }

    private func handlePhaseCompletion() {
        if phase == .focus {
            if let summary = currentSessionSummary(manuallyEnded: false) {
                StudyProgressStore.recordSession(summary)
                reviewSession = summary
                showPostSessionReview = true
                reflectionFocusPromptSuggestion = "Focus session complete (\(summary.completedMinutes)m). What helped you stay on track, and what should you repeat next block?"
            }
            completedFocusMinutesToday += focusMinutes
            StudyProgressStore.addFocusMinutes(focusMinutes)
            DailyProgressStore.recordMinutesSaved(focusMinutes)
            completedCyclesInSession += 1
            runtimeCompletedCycles = completedCyclesInSession

            if completedCyclesInSession >= max(1, sessionTargetCycles) {
                isRunning = false
                runtimeIsRunning = false
                tickerTask?.cancel()
                phase = .focus
                remainingSeconds = focusMinutes * 60
                runtimePhaseRaw = "focus"
                runtimeEndTimestamp = 0
                runtimeRemainingPaused = remainingSeconds
                sessionStartDate = nil
                runtimeSessionStartTimestamp = 0
                completedCyclesInSession = 0
                runtimeCompletedCycles = 0
                persistRuntimeState()
                StudyLiveActivityManager.end()
                return
            }

            phase = .breakTime
            remainingSeconds = breakMinutes * 60
            runtimePhaseRaw = "break"
            runtimeSessionStartTimestamp = 0
            sessionStartDate = nil
        } else {
            phase = .focus
            remainingSeconds = focusMinutes * 60
            runtimePhaseRaw = "focus"
            sessionStartDate = .now
            runtimeSessionStartTimestamp = sessionStartDate?.timeIntervalSince1970 ?? 0
        }
        runtimeEndTimestamp = Date().addingTimeInterval(TimeInterval(remainingSeconds)).timeIntervalSince1970
        runtimeRemainingPaused = remainingSeconds
        persistRuntimeState()
        runTicker()
        syncLiveActivity()
    }

    private func saveReviewIfPossible() {
        guard let reviewSession else { return }
        FocusInsightsStore.saveReview(
            for: reviewSession.id,
            whatWorked: reviewWorkedText,
            distraction: reviewDistractionText,
            nextCommitment: reviewCommitmentText
        )
    }

    private func clearReviewState() {
        reviewSession = nil
        reviewWorkedText = ""
        reviewDistractionText = ""
        reviewCommitmentText = ""
        showPostSessionReview = false
    }

    private var plannerRecommendation: FocusPlannerRecommendation {
        FocusInsightsStore.plannerRecommendation()
    }

    private func applyPlannerRecommendation() {
        guard !isRunning else { return }
        focusMinutes = plannerRecommendation.focusMinutes
        breakMinutes = plannerRecommendation.breakMinutes
        sessionTargetCycles = recommendedCycleCount(forFocusMinutes: plannerRecommendation.focusMinutes)
        completedCyclesInSession = 0
        runtimeCompletedCycles = 0
        remainingSeconds = (phase == .focus ? focusMinutes : breakMinutes) * 60
        if let mapped = FocusProtocolPreset(rawValue: plannerRecommendation.protocolKey) {
            selectedProtocol = mapped
        }
        persistRuntimeState()
    }

    private func applyProtocolPreset(_ preset: FocusProtocolPreset) {
        guard !isRunning else { return }
        focusMinutes = preset.focusMinutes
        breakMinutes = preset.breakMinutes
        remainingSeconds = (phase == .focus ? focusMinutes : breakMinutes) * 60
        persistRuntimeState()
    }

    private func syncLiveActivity() {
        StudyLiveActivityManager.startOrUpdate(
            phaseTitle: phase.title,
            isRunning: isRunning,
            remainingSeconds: remainingSeconds,
            quote: phase == .focus ? focusLine : breakLine,
            progress: progress
        )
    }

    private func resetIfIdle() {
        guard !isRunning else { return }
        remainingSeconds = (phase == .focus ? focusMinutes : breakMinutes) * 60
        runtimeRemainingPaused = remainingSeconds
        persistRuntimeState()
    }

    private func refreshRemainingFromClock() {
        guard runtimeIsRunning, runtimeEndTimestamp > 0 else { return }
        remainingSeconds = max(0, Int(runtimeEndTimestamp - Date().timeIntervalSince1970))
    }

    private func persistRuntimeState() {
        runtimePhaseRaw = (phase == .focus ? "focus" : "break")
        runtimeFocusMinutes = focusMinutes
        runtimeBreakMinutes = breakMinutes
        runtimeSessionTypeRaw = focusSessionType.rawValue
        runtimeSessionGoal = focusSessionGoal
        runtimeSessionTargetCycles = max(1, sessionTargetCycles)
        runtimeCompletedCycles = max(0, completedCyclesInSession)
        runtimeRemainingPaused = remainingSeconds
    }

    private func restoreRuntimeState() {
        focusMinutes = runtimeFocusMinutes
        breakMinutes = runtimeBreakMinutes
        sessionTargetCycles = max(1, runtimeSessionTargetCycles)
        completedCyclesInSession = max(0, runtimeCompletedCycles)
        phase = (runtimePhaseRaw == "break") ? .breakTime : .focus
        focusSessionType = FocusSessionType(rawValue: runtimeSessionTypeRaw) ?? .study
        focusSessionGoal = runtimeSessionGoal
        completedFocusMinutesToday = StudyProgressStore.focusMinutesToday()
        sessionStartDate = runtimeSessionStartTimestamp > 0 ? Date(timeIntervalSince1970: runtimeSessionStartTimestamp) : nil

        if runtimeIsRunning, runtimeEndTimestamp > 0 {
            isRunning = true
            remainingSeconds = max(0, Int(runtimeEndTimestamp - Date().timeIntervalSince1970))
            if remainingSeconds == 0 {
                handlePhaseCompletion()
            } else {
                runTicker()
            }
        } else {
            isRunning = false
            remainingSeconds = max(0, runtimeRemainingPaused)
        }
    }

    private func currentSessionSummary(manuallyEnded: Bool) -> StudyProgressStore.FocusSessionSummary? {
        guard phase == .focus else { return nil }
        let planned = focusMinutes
        let completed = max(0, (planned * 60 - remainingSeconds) / 60)
        guard completed > 0 else { return nil }
        let startedAt = sessionStartDate ?? Date().addingTimeInterval(TimeInterval(-completed * 60))
        return StudyProgressStore.FocusSessionSummary(
            id: UUID(),
            startedAt: startedAt,
            endedAt: .now,
            plannedMinutes: planned,
            completedMinutes: completed,
            sessionType: focusSessionType.title,
            goal: focusSessionGoal.trimmingCharacters(in: .whitespacesAndNewlines),
            endedManually: manuallyEnded
        )
    }

    private func timeString(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var dailyGoalMinutes: Int {
        max(1, settings.streakGoalMinutes)
    }

    private var dailyGoalProgress: Double {
        min(1, totalMinutesTowardGoalToday / Double(dailyGoalMinutes))
    }

    private var totalMinutesTowardGoalToday: Double {
        Double(completedFocusMinutesToday) + inFlightFocusMinutes
    }

    private var inFlightFocusMinutes: Double {
        guard phase == .focus else { return 0 }
        let elapsedSeconds = max(0, (focusMinutes * 60) - remainingSeconds)
        return Double(elapsedSeconds) / 60.0
    }

    private var goalStatusText: String {
        dailyGoalProgress >= 1 ? "Goal achieved" : String(format: "%.1f%%", dailyGoalProgress * 100.0)
    }

    private var runwayStatusText: String {
        let remaining = max(0, dailyGoalMinutes - Int(totalMinutesTowardGoalToday.rounded(.down)))
        if remaining == 0 { return "Daily focus goal already achieved." }
        let blocks = Int(ceil(Double(remaining) / Double(max(1, focusMinutes))))
        return "\(remaining)m left to goal • about \(blocks) block\(blocks == 1 ? "" : "s")"
    }

    private func goalTemplateChip(_ title: String) -> some View {
        Button(title) {
            InteractionFeedback.tap()
            focusSessionGoal = title
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(RespiteTheme.duskBlue.opacity(0.10))
        )
    }

    private struct SessionTimelineSegment: Identifiable {
        let id = UUID()
        let isFocus: Bool
        let minutes: Int
        let label: String
    }

    private var fullscreenSessionSegments: [SessionTimelineSegment] {
        let cycles = max(1, sessionTargetCycles)
        var segments: [SessionTimelineSegment] = []
        for cycle in 0..<cycles {
            segments.append(SessionTimelineSegment(isFocus: true, minutes: focusMinutes, label: "F\(focusMinutes)"))
            if cycle < cycles - 1 {
                segments.append(SessionTimelineSegment(isFocus: false, minutes: breakMinutes, label: "B\(breakMinutes)"))
            }
        }
        return segments
    }

    private var activeSessionSegmentIndex: Int {
        if phase == .focus {
            return min(max(0, completedCyclesInSession * 2), max(0, fullscreenSessionSegments.count - 1))
        }
        return min(max(0, completedCyclesInSession * 2 - 1), max(0, fullscreenSessionSegments.count - 1))
    }

    private var fullscreenSessionTimeline: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Session timeline")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
                Spacer()
                Text(currentBlockLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
            }

            GeometryReader { proxy in
                let segments = fullscreenSessionSegments
                let spacing: CGFloat = 3
                let totalSpacing = spacing * CGFloat(max(0, segments.count - 1))
                let availableWidth = max(0, proxy.size.width - totalSpacing)
                let totalMinutes = CGFloat(max(1, segments.reduce(0) { $0 + max(1, $1.minutes) }))

                HStack(spacing: spacing) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        let minuteWeight = CGFloat(max(1, segment.minutes))
                        let width = max(10, availableWidth * (minuteWeight / totalMinutes))

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(segment.isFocus ? RespiteTheme.duskBlue.opacity(0.72) : RespiteTheme.pine.opacity(0.58))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(.white.opacity(index == activeSessionSegmentIndex ? 0.86 : 0.20), lineWidth: index == activeSessionSegmentIndex ? 1.15 : 0.8)
                            )
                            .overlay(
                                Text(segment.label)
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.90))
                                    .opacity(width > 24 ? 1 : 0)
                            )
                            .frame(width: width, height: 14)
                            .opacity(index < activeSessionSegmentIndex ? 0.92 : (index == activeSessionSegmentIndex ? 1.0 : 0.40))
                    }
                }
                .frame(width: proxy.size.width, alignment: .leading)
            }
            .frame(height: 14)

            Text("Focus \(focusMinutes)m / Break \(breakMinutes)m")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
    }

    private var fullscreenGoalProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Daily goal progress")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
                Spacer()
                Text(goalStatusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                    Capsule()
                        .fill(phase.accent.opacity(0.85))
                        .frame(width: proxy.size.width * dailyGoalProgress)
                }
            }
            .frame(height: 10)
        }
    }
}

private enum FocusProtocolPreset: String, CaseIterable {
    case steady
    case deep
    case recovery

    var title: String {
        switch self {
        case .steady: return "Steady"
        case .deep: return "Deep"
        case .recovery: return "Recovery"
        }
    }

    var focusMinutes: Int {
        switch self {
        case .steady: return 30
        case .deep: return 50
        case .recovery: return 20
        }
    }

    var breakMinutes: Int {
        switch self {
        case .steady: return 8
        case .deep: return 10
        case .recovery: return 5
        }
    }

    var description: String {
        switch self {
        case .steady: return "Balanced protocol for everyday consistency."
        case .deep: return "Longer blocks for high-cognitive work."
        case .recovery: return "Lower-friction restart when momentum dips."
        }
    }
}

private enum FocusSessionType: String, CaseIterable {
    case homework
    case study
    case reading
    case project
    case other

    var title: String {
        switch self {
        case .homework: return "Homework"
        case .study: return "Study"
        case .reading: return "Reading"
        case .project: return "Project"
        case .other: return "Other"
        }
    }
}

private struct StudyClockDial: View {
    let progress: Double
    let accent: Color
    let tickCount: Int
    let showShadow: Bool

    init(progress: Double, accent: Color, tickCount: Int = 60, showShadow: Bool = true) {
        self.progress = progress
        self.accent = accent
        self.tickCount = tickCount
        self.showShadow = showShadow
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )

            Circle()
                .fill(Color.black.opacity(0.55))
                .padding(10)

            let safeTickCount = max(12, tickCount)
            let majorEvery = max(1, safeTickCount / 12)
            ForEach(0..<safeTickCount, id: \.self) { tick in
                Rectangle()
                    .fill(Color.white.opacity(tick % majorEvery == 0 ? 0.80 : 0.30))
                    .frame(width: 1.8, height: tick % majorEvery == 0 ? 8 : 4)
                    .offset(y: -52)
                    .rotationEffect(.degrees(Double(tick) * (360.0 / Double(safeTickCount))))
            }

            Rectangle()
                .fill(accent)
                .frame(width: 2.6, height: 38)
                .offset(y: -17)
                .rotationEffect(.degrees(360 * progress))

            Circle()
                .fill(accent)
                .frame(width: 9, height: 9)
        }
        .shadow(color: .black.opacity(showShadow ? 0.22 : 0.0), radius: showShadow ? 10 : 0, x: 0, y: showShadow ? 6 : 0)
    }
}

private struct PrimaryActionButton: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct SecondaryActionButton: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .default))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.08 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.20), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct FullScreenActionButton: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill.opacity(0.34))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

enum StudyProgressStore {
    private static let dayStampKey = "study.progress.dayStamp"
    private static let focusMinutesKey = "study.progress.focusMinutes"
    private static let sessionHistoryKey = "study.progress.sessionHistory"

    struct FocusSessionSummary: Codable, Hashable, Identifiable {
        let id: UUID
        let startedAt: Date
        let endedAt: Date
        let plannedMinutes: Int
        let completedMinutes: Int
        let sessionType: String
        let goal: String
        let endedManually: Bool
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    static func focusMinutesToday() -> Int {
        resetIfNeeded()
        return defaults.integer(forKey: focusMinutesKey)
    }

    static func addFocusMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        resetIfNeeded()
        defaults.set(defaults.integer(forKey: focusMinutesKey) + minutes, forKey: focusMinutesKey)
    }

    static func recordSession(_ summary: FocusSessionSummary) {
        var sessions = recentSessions(limit: 200)
        sessions.append(summary)
        sessions.sort { $0.endedAt > $1.endedAt }
        let capped = Array(sessions.prefix(200))
        if let encoded = try? JSONEncoder().encode(capped) {
            defaults.set(encoded, forKey: sessionHistoryKey)
        }
    }

    static func recentSessions(limit: Int = 12) -> [FocusSessionSummary] {
        guard
            let data = defaults.data(forKey: sessionHistoryKey),
            let decoded = try? JSONDecoder().decode([FocusSessionSummary].self, from: data)
        else { return [] }
        return Array(decoded.prefix(max(1, limit)))
    }

    private static func resetIfNeeded(referenceDate: Date = .now) {
        let today = Calendar.current.startOfDay(for: referenceDate)
        let savedDay = defaults.object(forKey: dayStampKey) as? Date
        let savedDayStart = savedDay.map { Calendar.current.startOfDay(for: $0) }
        guard savedDayStart != today else { return }
        defaults.set(today, forKey: dayStampKey)
        defaults.set(0, forKey: focusMinutesKey)
    }
}
