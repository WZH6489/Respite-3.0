import SwiftUI
import UIKit

struct BreathworkTimerView: View {
    @Binding var isPresented: Bool
    var isRegulationSession: Bool = false
    var onRegulationComplete: (() -> Void)? = nil

    @State private var breathPhase: BreathPhase = .ready
    @State private var countdown: Int = 0
    @State private var cyclesCompleted: Int = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0.4
    @State private var timer: Timer? = nil
    @State private var elapsedInPhase: Int = 0
    @State private var didCallRegulationComplete = false
    @State private var showTikTokNudge = false

    private let totalCycles = 3

    enum BreathPhase {
        case ready, inhale, hold, exhale, done

        var label: String {
            switch self {
            case .ready:   return "Ready to begin"
            case .inhale:  return "Breathe in"
            case .hold:    return "Hold"
            case .exhale:  return "Breathe out"
            case .done:    return "Well done"
            }
        }

        var duration: Int {
            switch self {
            case .inhale: return 4
            case .hold:   return 7
            case .exhale: return 8
            default:      return 0
            }
        }

        var color: Color {
            switch self {
            case .ready:  return .blue
            case .inhale: return .cyan
            case .hold:   return .indigo
            case .exhale: return .teal
            case .done:   return .green
            }
        }

        var targetScale: CGFloat {
            switch self {
            case .inhale:  return 1.0
            case .hold:    return 1.0
            case .exhale:  return 0.6
            default:       return 0.6
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack(spacing: 40) {
                    cycleIndicator
                        .padding(.top, 8)

                    Spacer()

                    breathingCircle

                    phaseLabel

                    Spacer()

                    instructionText

                    actionButton
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 32)
            }
            .navigationTitle("Breathwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        stopTimer()
                        isPresented = false
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showTikTokNudge {
                    tikTokNudgeBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private var tikTokNudgeBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Return to your app")
                .font(.subheadline.weight(.semibold))
            Text("TikTok should open for you now during your grace window.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                breathPhase.color.opacity(0.08),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.5), value: breathPhase)
    }

    private var cycleIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalCycles, id: \.self) { i in
                Capsule()
                    .fill(i < cyclesCompleted ? breathPhase.color : Color.secondary.opacity(0.2))
                    .frame(width: i < cyclesCompleted ? 24 : 16, height: 6)
                    .animation(.spring(response: 0.4), value: cyclesCompleted)
            }
        }
    }

    private var breathingCircle: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .strokeBorder(breathPhase.color.opacity(0.15 - Double(i) * 0.04), lineWidth: 1)
                    .scaleEffect(ringScale + CGFloat(i) * 0.12)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [breathPhase.color.opacity(0.6), breathPhase.color.opacity(0.2)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .strokeBorder(breathPhase.color.opacity(0.6), lineWidth: 2)
                .frame(width: 180, height: 180)
                .scaleEffect(ringScale)

            if breathPhase != .ready && breathPhase != .done {
                Text("\(max(countdown, 0))")
                    .font(.system(size: 52, weight: .thin, design: .rounded))
                    .foregroundStyle(breathPhase.color)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 220, height: 220)
        .animation(.easeInOut(duration: 1.0), value: ringScale)
        .animation(.easeInOut(duration: 1.0), value: ringOpacity)
    }

    private var phaseLabel: some View {
        VStack(spacing: 6) {
            Text(breathPhase.label)
                .font(.title2.weight(.semibold))
                .foregroundStyle(breathPhase.color)
                .animation(.easeInOut(duration: 0.4), value: breathPhase)

            if breathPhase != .ready && breathPhase != .done {
                Text(phaseSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: breathPhase)
    }

    private var phaseSubtitle: String {
        switch breathPhase {
        case .inhale:  return "through your nose"
        case .hold:    return "keep still"
        case .exhale:  return "slowly through your mouth"
        default:       return ""
        }
    }

    private var instructionText: some View {
        Group {
            if breathPhase == .ready {
                Text("4-7-8 breathing\nInhale 4s · Hold 7s · Exhale 8s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            } else if breathPhase == .done {
                Text("You completed \(totalCycles) full breath cycles.\nYour nervous system thanks you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            } else {
                Text("Cycle \(cyclesCompleted + 1) of \(totalCycles)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButton: some View {
        Group {
            switch breathPhase {
            case .ready:
                Button(action: startSession) {
                    Text("Begin")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
                }
            case .done:
                VStack(spacing: 12) {
                    if !isRegulationSession {
                        Button {
                            resetSession()
                        } label: {
                            Text("Go again")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
                        }
                    }
                    Button { isPresented = false } label: {
                        Text("I'm done")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    private func startSession() {
        cyclesCompleted = 0
        startPhase(.inhale)
    }

    private func resetSession() {
        cyclesCompleted = 0
        withAnimation { breathPhase = .ready }
        ringScale = 0.6
        ringOpacity = 0.4
    }

    private func startPhase(_ phase: BreathPhase) {
        stopTimer()
        withAnimation(.easeInOut(duration: 0.4)) {
            breathPhase = phase
        }
        countdown = phase.duration
        elapsedInPhase = 0

        withAnimation(.easeInOut(duration: Double(phase.duration))) {
            ringScale = phase.targetScale
            ringOpacity = phase == .exhale ? 0.35 : 0.75
        }

        guard phase.duration > 0 else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedInPhase += 1
            withAnimation {
                countdown = max(phase.duration - elapsedInPhase, 0)
            }
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
                withAnimation(.spring(response: 0.6)) {
                    breathPhase = .done
                }
                ringScale = 0.6
                ringOpacity = 0.4
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

