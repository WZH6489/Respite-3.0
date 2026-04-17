import SwiftUI
import UIKit

/// Unified calm breathing: **5 × (2s inhale, 3s exhale)** ≈ **25s** total.
struct TikTokBreathGateView: View {
    @EnvironmentObject private var interventions: InterventionManager
    let gateReason: BreathingGateReason
    @Binding var isPresented: Bool
    var onRegulationComplete: (() -> Void)? = nil
    var onRegulationLeaveFlow: (() -> Void)? = nil

    private static let inhaleSeconds: Double = 2
    private static let exhaleSeconds: Double = 3
    private static let totalBreaths = 5

    @State private var runTask: Task<Void, Never>?
    @State private var hasStarted = false
    @State private var allBreathsComplete = false
    @State private var currentBreath: Int = 0
    @State private var isInhalePhase = true
    @State private var phaseProgress: CGFloat = 0
    @State private var didCallRegulationComplete = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                VStack(spacing: 20) {
                    header

                    breathingOrb

                    phaseLabel

                    progressDots
                }
                .padding(.horizontal, 28)

                Spacer()

                bottomBar
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            didCallRegulationComplete = false
        }
        .onChange(of: isPresented) { _, shown in
            if shown {
                runTask?.cancel()
                runTask = nil
                hasStarted = false
                allBreathsComplete = false
                currentBreath = 0
                isInhalePhase = true
                phaseProgress = 0
                didCallRegulationComplete = false
            }
        }
        .onDisappear {
            runTask?.cancel()
            runTask = nil
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(headerTitle)
                .font(.title.bold())
                .foregroundStyle(.white)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var headerTitle: String {
        switch gateReason {
        case .externalLaunch: return "Calm breathing"
        case .regulationShield: return "Breathing pause"
        case .idleReturn: return "Welcome back"
        case .postGraceRandom: return "Quick reset"
        case .shortcutAutomation: return "Calm breathing"
        }
    }

    private var headerSubtitle: String {
        switch gateReason {
        case .externalLaunch:
            return "Five slow breaths before you open TikTok — about 25 seconds. Longer exhales help ease stress."
        case .regulationShield:
            return "Five slow breaths to finish your Screen Time unlock — about 25 seconds."
        case .idleReturn:
            return "You’ve been away a while. Five slow breaths before you continue in Respite."
        case .postGraceRandom:
            return "Your grace period ended. Take five slow breaths before you keep scrolling."
        case .shortcutAutomation:
            return "From Shortcuts: five slow breaths — about 25 seconds — then your automation continues."
        }
    }

    private var continueButtonTitle: String {
        switch gateReason {
        case .externalLaunch, .regulationShield:
            return "Continue to TikTok"
        case .idleReturn, .postGraceRandom:
            return "Continue"
        case .shortcutAutomation:
            return RespiteShortcutCoordinator.shared.pendingOpenTikTokWhenDone ? "Continue to TikTok" : "Continue"
        }
    }

    private var breathingOrb: some View {
        let scale: CGFloat = {
            if !hasStarted { return 0.92 }
            if allBreathsComplete { return 1.0 }
            return isInhalePhase ? (0.88 + 0.2 * phaseProgress) : (1.08 - 0.2 * phaseProgress)
        }()

        return ZStack {
            ForEach(0 ..< 3, id: \.self) { i in
                Circle()
                    .strokeBorder(Color.cyan.opacity(0.12 - Double(i) * 0.03), lineWidth: 1)
                    .frame(width: CGFloat(140 + i * 28), height: CGFloat(140 + i * 28))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.55), Color.cyan.opacity(0.15)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 90
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 0.35), value: scale)
        }
        .frame(height: 200)
    }

    private var phaseLabel: some View {
        Group {
            if allBreathsComplete {
                Text("You’re all set")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            } else if !hasStarted {
                Text("Tap below when you’re ready")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                VStack(spacing: 6) {
                    Text(isInhalePhase ? "Breathe in" : "Breathe out")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.cyan)
                    Text("Breath \(currentBreath) of \(Self.totalBreaths)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .frame(minHeight: 64)
    }

    private var progressDots: some View {
        HStack(spacing: 10) {
            ForEach(1 ... Self.totalBreaths, id: \.self) { i in
                Circle()
                    .fill(dotColor(for: i))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.top, 8)
    }

    private func dotColor(for index: Int) -> Color {
        if allBreathsComplete { return .cyan }
        if index < currentBreath { return .cyan.opacity(0.9) }
        if index == currentBreath, hasStarted { return .cyan.opacity(0.5) }
        return .white.opacity(0.2)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if !hasStarted {
                Button {
                    startBreathingSequence()
                } label: {
                    Text("Start breathing")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.cyan))
                }
            }

            Button {
                handleContinueTapped()
            } label: {
                Text(continueButtonTitle)
                    .font(.headline)
                    .foregroundStyle(allBreathsComplete ? .white : .white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(allBreathsComplete ? Color.orange : Color.white.opacity(0.08))
                    )
            }
            .disabled(!allBreathsComplete)

            if !allBreathsComplete {
                Text(hasStarted ? "Finish all five breaths to continue." : "Begin when you’re ready.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .padding(.top, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func handleContinueTapped() {
        let logContext: String = {
            switch gateReason {
            case .externalLaunch: return "Breathing gate — external / shortcut"
            case .regulationShield: return "Breathing gate — Screen Time shield"
            case .idleReturn: return "Breathing gate — return after idle"
            case .postGraceRandom: return "Breathing gate — after grace (random)"
            case .shortcutAutomation: return "Breathing gate — Shortcuts automation"
            }
        }()
        interventions.logBreathingGateCompletion(context: logContext)

        switch gateReason {
        case .externalLaunch:
            interventions.armPreTikTokBreathAutomationDeepLinkQuietPeriod()
            RespiteStatsStore.shared.recordTikTokIntentPass()
            isPresented = false
            openTikTokAfterDismissal()
        case .regulationShield:
            // Shortcuts may fire regulate://breathwork on top of the App Intent gate; that shows this view while
            // `RunTikTokBreathingGateIntent` is still awaiting. Completing here must resume the intent or Shortcuts stays on “Opening breathwork”.
            if RespiteShortcutCoordinator.shared.hasPendingShortcutIntent {
                let openTikTokWhenDone = RespiteShortcutCoordinator.shared.pendingOpenTikTokWhenDone
                interventions.armPreTikTokBreathAutomationDeepLinkQuietPeriod()
                RegulationSettingsStore().armTikTokHandoffSuppressWindow()
                if openTikTokWhenDone {
                    RespiteStatsStore.shared.recordTikTokIntentPass()
                }
                RespiteShortcutCoordinator.shared.completeBreathingGate()
                interventions.presentedBreathingGate = nil
                onRegulationLeaveFlow?()
                isPresented = false
                if openTikTokWhenDone {
                    openTikTokAfterDismissal()
                }
                return
            }
            onRegulationLeaveFlow?()
            isPresented = false
            openTikTokAfterDismissal()
        case .idleReturn, .postGraceRandom:
            isPresented = false
        case .shortcutAutomation:
            let openTikTokWhenDone = RespiteShortcutCoordinator.shared.pendingOpenTikTokWhenDone
            interventions.armPreTikTokBreathAutomationDeepLinkQuietPeriod()
            // Arm before the intent resumes so the next “When TikTok opens” run sees suppress (two-step Open URL, or any race with Shortcuts).
            RegulationSettingsStore().armTikTokHandoffSuppressWindow()
            if openTikTokWhenDone {
                RespiteStatsStore.shared.recordTikTokIntentPass()
            }
            isPresented = false
            RespiteShortcutCoordinator.shared.completeBreathingGate()
            if openTikTokWhenDone {
                openTikTokAfterDismissal()
            }
        }
    }

    private func startBreathingSequence() {
        hasStarted = true
        runTask?.cancel()
        runTask = Task { @MainActor in
            for breath in 1 ... Self.totalBreaths {
                guard !Task.isCancelled else { return }
                currentBreath = breath
                await runPhase(inhale: true, duration: Self.inhaleSeconds)
                guard !Task.isCancelled else { return }
                await runPhase(inhale: false, duration: Self.exhaleSeconds)
            }
            guard !Task.isCancelled else { return }
            allBreathsComplete = true
            currentBreath = Self.totalBreaths
            if gateReason == .regulationShield, let onComplete = onRegulationComplete, !didCallRegulationComplete {
                didCallRegulationComplete = true
                onComplete()
            }
        }
    }

    private func runPhase(inhale: Bool, duration: Double) async {
        isInhalePhase = inhale
        let steps = 20
        let stepDuration = duration / Double(steps)
        for step in 0 ... steps {
            guard !Task.isCancelled else { return }
            phaseProgress = CGFloat(step) / CGFloat(steps)
            let ns = UInt64(max(0, stepDuration * 1_000_000_000))
            try? await Task.sleep(nanoseconds: ns)
        }
        phaseProgress = 1
    }

    private func openTikTokAfterDismissal() {
        RegulationSettingsStore().armTikTokHandoffSuppressWindow()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if let url = URL(string: "tiktok://") {
                UIApplication.shared.open(url)
            }
        }
    }
}
