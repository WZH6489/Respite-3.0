import SwiftUI

struct WellnessView: View {
    @EnvironmentObject private var interventions: InterventionManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedExercise: WellnessExercise?
    @AppStorage("dev.ui.useTimePreview") private var useTimePreview = false
    @AppStorage("dev.ui.previewAuto") private var previewAuto = false
    @AppStorage("dev.ui.timePreviewHour") private var timePreviewHour = 12.0
    @AppStorage("dev.ui.colorIntensity") private var colorIntensity = 0.85
    @State private var popupTextVisible = false
    @StateObject private var sunTimes = SunTimesService()

    private let popupFadeDuration = 0.30
    private let popupTextEaseDuration = 0.34

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    mentalSection
                    physicalSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .respiteTrackBottomBarScroll()
            .background(background)
            .overlay {
                if let exercise = selectedExercise {
                    exercisePreviewOverlay(exercise)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { sunTimes.refresh() }
    }

    private var header: some View {
        Text("Wellness")
            .font(.system(size: 34, weight: .semibold, design: .default))
            .foregroundStyle(textPrimary)
    }

    private var mentalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mental exercises")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)

            wellnessAction(
                title: "Breathing exercise",
                subtitle: "Guided 4-7-8 cycles to calm your state.",
                action: { selectedExercise = .breathing }
            )

            wellnessAction(
                title: "Meditation",
                subtitle: "Short guided quiet sessions.",
                action: nil
            )

            wellnessAction(
                title: "Intent check",
                subtitle: "Pause and name your reason before opening.",
                action: { selectedExercise = .intentCheck }
            )

            wellnessAction(
                title: "Math challenge",
                subtitle: "Choose a difficulty and solve a quick challenge.",
                action: { selectedExercise = .mathPuzzle }
            )

            wellnessAction(
                title: "Tile puzzle",
                subtitle: "Slide tiles into order to reset attention.",
                action: { selectedExercise = .tilePuzzle }
            )
        }
        .padding(18)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var physicalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Physical exercises")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)

            wellnessAction(
                title: "Yoga flow",
                subtitle: "Gentle stretches for posture and breathing.",
                action: nil
            )

            wellnessAction(
                title: "Massage reset",
                subtitle: "Neck, jaw, and hand massage cues.",
                action: nil
            )

            wellnessAction(
                title: "No-equipment routine",
                subtitle: "Bodyweight movement breaks you can do anywhere.",
                action: nil
            )

            wellnessAction(
                title: "Equipment routine",
                subtitle: "Short sets using available gym/home equipment.",
                action: nil
            )
        }
        .padding(18)
        .respiteGlassCard(cornerRadius: 20)
    }

    @ViewBuilder
    private func wellnessAction(title: String, subtitle: String, action: (() -> Void)?) -> some View {
        Button(action: {
            guard let action else { return }
            InteractionFeedback.tap()
            action()
        }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundStyle(textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(textMuted)
                }

                Spacer()

                if action != nil {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                } else {
                    Text("Soon")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundStyle(textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private var background: some View {
        RespiteDynamicBackground()
    }

    @ViewBuilder
    private func exercisePreviewOverlay(_ exercise: WellnessExercise) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            RespiteTheme.sageDeep.opacity(0.38),
                            RespiteTheme.mistBlue.opacity(0.28),
                            RespiteTheme.sageDeep.opacity(0.44)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: popupFadeDuration)) { selectedExercise = nil }
                }

            VStack(spacing: 14) {
                Text("STEP 1")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .tracking(1.2)
                    .foregroundStyle(textMuted)
                    .opacity(popupTextVisible ? 1 : 0)
                    .offset(y: popupTextVisible ? 0 : -10)
                    .animation(.easeInOut(duration: popupTextEaseDuration).delay(0.02), value: popupTextVisible)

                Text(exercise.title)
                    .font(.system(size: 30, weight: .semibold, design: .default))
                    .foregroundStyle(textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(popupTextVisible ? 1 : 0)
                    .offset(y: popupTextVisible ? 0 : -10)
                    .animation(.easeInOut(duration: popupTextEaseDuration).delay(0.08), value: popupTextVisible)

                Text(exercise.description)
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(textSecondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .opacity(popupTextVisible ? 1 : 0)
                    .offset(y: popupTextVisible ? 0 : -10)
                    .animation(.easeInOut(duration: popupTextEaseDuration).delay(0.14), value: popupTextVisible)

                HStack(spacing: 10) {
                    Button {
                        InteractionFeedback.tap()
                        withAnimation(.easeInOut(duration: popupFadeDuration)) { selectedExercise = nil }
                    } label: {
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundStyle(textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }

                    Button {
                        InteractionFeedback.success()
                        withAnimation(.easeInOut(duration: popupFadeDuration)) { selectedExercise = nil }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            switch exercise {
                            case .breathing:
                                interventions.triggerBreathwork()
                            case .intentCheck:
                                interventions.triggerTikTokGate()
                            case .mathPuzzle:
                                interventions.triggerPuzzleBreak(mode: .math)
                            case .tilePuzzle:
                                interventions.triggerPuzzleBreak(mode: .tile)
                            }
                        }
                    } label: {
                        Text("Start")
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(RespiteTheme.pine)
                            )
                    }
                }
                .opacity(popupTextVisible ? 1 : 0)
                .offset(y: popupTextVisible ? 0 : -10)
                .animation(.easeInOut(duration: popupTextEaseDuration).delay(0.20), value: popupTextVisible)
            }
            .padding(22)
            .frame(maxWidth: 360, alignment: .center)
            .respiteGlassCard(cornerRadius: 24)
            .padding(.horizontal, 20)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .animation(.easeInOut(duration: popupFadeDuration), value: selectedExercise)
        .onAppear {
            popupTextVisible = false
            withAnimation(.easeInOut(duration: popupTextEaseDuration)) {
                popupTextVisible = true
            }
        }
        .onDisappear {
            popupTextVisible = false
        }
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

    private func decimalHour(_ date: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        return Double(hour) + (Double(minute) / 60.0)
    }

    private struct PhaseGradient {
        let top: Color
        let middle: Color
        let bottom: Color
        let highlight: Color
        let accent: Color
    }

    private func wellnessPhase(for date: Date, intensity: Double) -> PhaseGradient {
        let hour = Calendar.current.component(.hour, from: date)
        let warm = max(0.0, min(1.0, (sin((Double(hour) / 24.0) * .pi * 2 - .pi / 2) + 1) / 2))

        func adjusted(_ value: Double) -> Double {
            let centered = value - 0.5
            return min(1.0, max(0.0, 0.5 + (centered * intensity)))
        }

        return PhaseGradient(
            top: Color(red: adjusted(0.20), green: adjusted(0.30), blue: adjusted(0.25)),
            middle: Color(red: adjusted(0.28), green: adjusted(0.45), blue: adjusted(0.38)),
            bottom: Color(red: adjusted(0.30 + 0.04 * warm), green: adjusted(0.47), blue: adjusted(0.55 - 0.12 * warm)),
            highlight: Color(red: adjusted(0.62 + 0.18 * warm), green: adjusted(0.62), blue: adjusted(0.42)),
            accent: Color(red: adjusted(0.40), green: adjusted(0.62 - 0.08 * warm), blue: adjusted(0.68))
        )
    }
}

private extension WellnessView {
    var textPrimary: Color { .primary }
    var textSecondary: Color { .secondary }
    var textMuted: Color { .secondary.opacity(0.9) }
}

private enum WellnessExercise {
    case breathing
    case intentCheck
    case mathPuzzle
    case tilePuzzle

    var title: String {
        switch self {
        case .breathing: return "Breathing Exercise"
        case .intentCheck: return "Intent Check"
        case .mathPuzzle: return "Math Challenge"
        case .tilePuzzle: return "Tile Puzzle"
        }
    }

    var description: String {
        switch self {
        case .breathing:
            return "A guided 4-7-8 breathing routine that helps you lower stimulation and reset your focus."
        case .intentCheck:
            return "A short reflection prompt before opening distracting apps so your action is intentional, not automatic."
        case .mathPuzzle:
            return "A short arithmetic challenge to shift your mind from passive scrolling into active mode."
        case .tilePuzzle:
            return "A sliding tile puzzle that helps you reset with quiet, deliberate problem-solving."
        }
    }

}

