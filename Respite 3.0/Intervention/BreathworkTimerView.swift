import SwiftUI
import UIKit

struct BreathworkTimerView: View {
    @Binding var isPresented: Bool
    var isRegulationSession: Bool = false
    var onRegulationComplete: (() -> Void)? = nil

    @State private var breathPhase: BreathPhase = .ready
    @State private var countdown: Int = 0
    @State private var cyclesCompleted: Int = 0
    @State private var ringScale: CGFloat = 0.68
    @State private var ringOpacity: Double = 0.42
    @State private var timer: Timer? = nil
    @State private var elapsedInPhase: Int = 0
    @State private var didCallRegulationComplete = false
    @State private var showTikTokNudge = false
    @State private var contentVisible = false
    @State private var rotatingAura = false

    private let totalCycles = 3

    enum BreathPhase {
        case ready, inhale, hold, exhale, done

        var label: String {
            switch self {
            case .ready: return "Ready to begin"
            case .inhale: return "Breathe in"
            case .hold: return "Hold"
            case .exhale: return "Breathe out"
            case .done: return "Well done"
            }
        }

        var duration: Int {
            switch self {
            case .inhale: return 4
            case .hold: return 7
            case .exhale: return 8
            default: return 0
            }
        }

        var color: Color {
            switch self {
            case .ready: return RespiteTheme.mistBlue
            case .inhale: return RespiteTheme.sageDeep
            case .hold: return RespiteTheme.berryAccent
            case .exhale: return RespiteTheme.duskBlue
            case .done: return RespiteTheme.pine
            }
        }

        var targetScale: CGFloat {
            switch self {
            case .inhale: return 1.0
            case .hold: return 1.0
            case .exhale: return 0.68
            default: return 0.68
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack(spacing: 26) {
                    headerCard
                    cycleIndicator
                    breathingCircle
                    phaseLabel
                    instructionText
                    actionButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.86), value: contentVisible)
            }
            .navigationTitle("Breathwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        stopTimer()
                        isPresented = false
                    }
                    .foregroundStyle(RespiteTheme.duskBlue)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showTikTokNudge {
                    tikTokNudgeBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .onAppear {
                contentVisible = true
                rotatingAura = true
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 8) {
            Text("Settle your breath")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(RespiteTheme.textPrimary)
            Text("4-7-8 rhythm · gentle and steady")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(cardBackground)
    }

    private var tikTokNudgeBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Return to your app")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RespiteTheme.textPrimary)
            Text("TikTok should open for you now during your grace window.")
                .font(.footnote)
                .foregroundStyle(RespiteTheme.textMuted)
            Button {
                if let url = URL(string: "tiktok://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open TikTok", systemImage: "arrow.up.right.square")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(RespiteTheme.duskBlue)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var backgroundGradient: some View {
        ZStack {
            RespiteTheme.appBackground

            Circle()
                .fill(breathPhase.color.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 18)
                .offset(y: -170)

            Circle()
                .fill(RespiteTheme.mistBlue.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 20)
                .offset(x: -130, y: 220)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.9), value: breathPhase)
    }

    private var cycleIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalCycles, id: \.self) { i in
                Capsule()
                    .fill(i < cyclesCompleted ? breathPhase.color : RespiteTheme.border.opacity(0.8))
                    .frame(width: i < cyclesCompleted ? 28 : 16, height: 7)
                    .scaleEffect(i == cyclesCompleted && breathPhase != .done ? 1.08 : 1.0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: cyclesCompleted)
            }
        }
    }

    private var breathingCircle: some View {
        ZStack {
            Circle()
                .trim(from: 0.05, to: 0.95)
                .stroke(breathPhase.color.opacity(0.22), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [10, 10]))
                .frame(width: 230, height: 230)
                .rotationEffect(.degrees(rotatingAura ? 360 : 0))
                .animation(.linear(duration: 16).repeatForever(autoreverses: false), value: rotatingAura)

            ForEach(0..<3) { i in
                Circle()
                    .strokeBorder(breathPhase.color.opacity(0.14 - Double(i) * 0.03), lineWidth: 1)
                    .scaleEffect(ringScale + CGFloat(i) * 0.12)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [breathPhase.color.opacity(0.58), breathPhase.color.opacity(0.16)],
                        center: .center,
                        startRadius: 12,
                        endRadius: 94
                    )
                )
                .frame(width: 188, height: 188)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .strokeBorder(breathPhase.color.opacity(0.62), lineWidth: 2)
                .frame(width: 188, height: 188)
                .scaleEffect(ringScale)

            if breathPhase != .ready && breathPhase != .done {
                Text("\(max(countdown, 0))")
                    .font(.system(size: 52, weight: .thin, design: .rounded))
                    .foregroundStyle(RespiteTheme.textPrimary)
                    .contentTransition(.numericText())
            }
        }
        .frame(height: 250)
        .animation(.easeInOut(duration: 0.95), value: ringScale)
        .animation(.easeInOut(duration: 0.95), value: ringOpacity)
    }

    private var phaseLabel: some View {
        VStack(spacing: 6) {
            Text(breathPhase.label)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(RespiteTheme.textPrimary)
                .animation(.easeInOut(duration: 0.35), value: breathPhase)

            if breathPhase != .ready && breathPhase != .done {
                Text(phaseSubtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(RespiteTheme.textSecondary)
                    .transition(.opacity)
            }
        }
    }

    private var phaseSubtitle: String {
        switch breathPhase {
        case .inhale: return "through your nose"
        case .hold: return "keep still"
        case .exhale: return "slowly through your mouth"
        default: return ""
        }
    }

    private var instructionText: some View {
        Group {
            if breathPhase == .ready {
                Text("Inhale 4 seconds · Hold 7 · Exhale 8")
            } else if breathPhase == .done {
                Text("You completed \(totalCycles) full cycles.")
            } else {
                Text("Cycle \(cyclesCompleted + 1) of \(totalCycles)")
            }
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(RespiteTheme.textSecondary)
        .multilineTextAlignment(.center)
    }

    private var actionButton: some View {
        Group {
            switch breathPhase {
            case .ready:
                Button(action: startSession) {
                    Text("Begin")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 14).fill(RespiteTheme.duskBlue))
                }
                .shadow(color: RespiteTheme.duskBlue.opacity(0.18), radius: 10, y: 6)

            case .done:
                VStack(spacing: 10) {
                    if !isRegulationSession {
                        Button {
                            resetSession()
                        } label: {
                            Text("Go again")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(RoundedRectangle(cornerRadius: 14).fill(RespiteTheme.pine))
                        }
                    }
                    Button { isPresented = false } label: {
                        Text("I’m done")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(RespiteTheme.textSecondary)
                    }
                }

            default:
                EmptyView()
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(RespiteTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(RespiteTheme.border, lineWidth: 1)
            )
    }

    private func startSession() {
        cyclesCompleted = 0
        startPhase(.inhale)
    }

    private func resetSession() {
        cyclesCompleted = 0
        withAnimation { breathPhase = .ready }
        ringScale = 0.68
        ringOpacity = 0.42
    }

    private func startPhase(_ phase: BreathPhase) {
        stopTimer()
        withAnimation(.easeInOut(duration: 0.35)) {
            breathPhase = phase
        }
        countdown = phase.duration
        elapsedInPhase = 0

        withAnimation(.easeInOut(duration: Double(max(phase.duration, 1)))) {
            ringScale = phase.targetScale
            ringOpacity = phase == .exhale ? 0.35 : 0.76
        }

        guard phase.duration > 0 else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedInPhase += 1
            withAnimation { countdown = max(phase.duration - elapsedInPhase, 0) }
            if elapsedInPhase >= phase.duration {
                advancePhase(from: phase)
            }
        }
    }

    private func advancePhase(from current: BreathPhase) {
        switch current {
        case .inhale:
            startPhase(.hold)
        case .hold:
            startPhase(.exhale)
        case .exhale:
            cyclesCompleted += 1
            if cyclesCompleted >= totalCycles {
                stopTimer()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    breathPhase = .done
                }
                ringScale = 0.68
                ringOpacity = 0.42
                if isRegulationSession, !didCallRegulationComplete {
                    didCallRegulationComplete = true
                    onRegulationComplete?()
                    showTikTokNudge = true
                }
            } else {
                startPhase(.inhale)
            }
        default:
            break
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
