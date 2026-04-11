import SwiftUI
import UIKit

struct PuzzleBreakView: View {
    @Binding var isPresented: Bool
    var isRegulationSession: Bool = false
    var onSuccessfulSolve: (() -> Void)? = nil

    @State private var puzzle: MathPuzzle = .random()
    @State private var userAnswer: String = ""
    @State private var phase: PuzzlePhase = .solving
    @State private var shakeOffset: CGFloat = 0
    @State private var attemptsLeft: Int = 3
    @State private var didCompleteRegulationSolve = false
    @State private var showTikTokNudge = false
    @State private var contentVisible = false
    @State private var badgeFloat = false
    @State private var resultScale: CGFloat = 0.92
    @FocusState private var isInputFocused: Bool

    enum PuzzlePhase {
        case solving, correct, failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RespiteTheme.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    puzzleContent
                        .padding(.horizontal, 20)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 12)
                        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: contentVisible)

                    Spacer(minLength: 8)

                    bottomBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Puzzle Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if phase == .correct || phase == .failed {
                        Button("Done") { isPresented = false }
                            .foregroundStyle(RespiteTheme.duskBlue)
                    }
                }
            }
            .onAppear {
                contentVisible = true
                badgeFloat = true
                isInputFocused = true
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase != .solving {
                    resultScale = 0.92
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                        resultScale = 1.0
                    }
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

    private var regulationCorrectSubtitle: String {
        if isRegulationSession {
            return "You're unlocked for a short grace period — head back when you're ready."
        }
        return "Nice work — your attention is back in your hands."
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

    @ViewBuilder
    private var puzzleContent: some View {
        switch phase {
        case .solving:
            solvingView
        case .correct:
            resultView(
                emoji: "🎉",
                title: "Correct!",
                subtitle: regulationCorrectSubtitle,
                color: RespiteTheme.pine
            )
            .scaleEffect(resultScale)
        case .failed:
            resultView(
                emoji: "🧠",
                title: "Answer: \(puzzle.answer)",
                subtitle: "You tried \(3 - attemptsLeft) time\(attemptsLeft < 2 ? "s" : ""). The answer was \(puzzle.answer).",
                color: RespiteTheme.berryAccent
            )
            .scaleEffect(resultScale)
        }
    }

    private var solvingView: some View {
        VStack(spacing: 18) {
            headerCard
                .padding(.top, 8)

            questionCard

            answerField

            attemptsIndicator
        }
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(RespiteTheme.berryAccent.opacity(0.16))
                    .frame(width: 84, height: 84)
                Text("🧩")
                    .font(.system(size: 40))
            }
            .offset(y: badgeFloat ? -2 : 3)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: badgeFloat)

            Text("Switch into active mode")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(RespiteTheme.textPrimary)
            Text("Solve one quick puzzle to continue")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(cardBackground)
    }

    private var questionCard: some View {
        VStack(spacing: 8) {
            Text("What is")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            Text(puzzle.question)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(RespiteTheme.textPrimary)
                .contentTransition(.numericText())

            Text("= ?")
                .font(.title2)
                .foregroundStyle(RespiteTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(cardBackground)
        .offset(x: shakeOffset)
    }

    private var answerField: some View {
        HStack(spacing: 12) {
            TextField("Your answer", text: $userAnswer)
                .keyboardType(.numberPad)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .focused($isInputFocused)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(RespiteTheme.surfaceSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(RespiteTheme.berryAccent.opacity(0.45), lineWidth: 1.5)
                        )
                )
                .submitLabel(.done)
                .onSubmit { checkAnswer() }

            Button(action: checkAnswer) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(userAnswer.isEmpty ? RespiteTheme.textMuted : RespiteTheme.berryAccent)
                    .scaleEffect(userAnswer.isEmpty ? 1.0 : 1.08)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: userAnswer.isEmpty)
            }
            .disabled(userAnswer.isEmpty)
        }
        .padding(.horizontal, 2)
    }

    private var attemptsIndicator: some View {
        HStack(spacing: 8) {
            Text("Attempts left:")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
            ForEach(0..<3) { i in
                Image(systemName: i < attemptsLeft ? "circle.fill" : "circle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(i < attemptsLeft ? RespiteTheme.berryAccent : RespiteTheme.border)
                    .scaleEffect(i < attemptsLeft ? 1.0 : 0.85)
            }
        }
    }

    private func resultView(emoji: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 104, height: 104)
                Text(emoji)
                    .font(.system(size: 52))
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(color)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(RespiteTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            if phase == .correct && !isRegulationSession {
                Button {
                    puzzle = .random()
                    userAnswer = ""
                    attemptsLeft = 3
                    phase = .solving
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isInputFocused = true
                    }
                } label: {
                    Label("Try another", systemImage: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 28)
                        .background(RoundedRectangle(cornerRadius: 14).fill(color))
                }
                .shadow(color: color.opacity(0.2), radius: 8, y: 5)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    private var bottomBar: some View {
        Button {
            isPresented = false
        } label: {
            Text(phase == .solving ? "Skip for now" : "Close")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
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

    private func checkAnswer() {
        guard let typed = Int(userAnswer.trimmingCharacters(in: .whitespaces)) else {
            triggerShake()
            return
        }

        if typed == puzzle.answer {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.74)) {
                phase = .correct
            }
            if isRegulationSession, !didCompleteRegulationSolve {
                didCompleteRegulationSolve = true
                onSuccessfulSolve?()
                showTikTokNudge = true
            }
        } else {
            attemptsLeft -= 1
            userAnswer = ""
            if attemptsLeft <= 0 {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.74)) {
                    phase = .failed
                }
            } else {
                triggerShake()
                isInputFocused = true
            }
        }
    }

    private func triggerShake() {
        withAnimation(.interpolatingSpring(stiffness: 620, damping: 10)) {
            shakeOffset = 12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.interpolatingSpring(stiffness: 620, damping: 10)) {
                shakeOffset = 0
            }
        }
    }
}

struct MathPuzzle {
    let question: String
    let answer: Int

    static func random() -> MathPuzzle {
        let kind = Int.random(in: 0..<3)
        switch kind {
        case 0:
            let a = Int.random(in: 10...40)
            let b = Int.random(in: 5...30)
            return MathPuzzle(question: "\(a) + \(b)", answer: a + b)
        case 1:
            let b = Int.random(in: 5...25)
            let a = Int.random(in: b + 1...50)
            return MathPuzzle(question: "\(a) − \(b)", answer: a - b)
        default:
            let a = Int.random(in: 2...12)
            let b = Int.random(in: 2...9)
            return MathPuzzle(question: "\(a) × \(b)", answer: a * b)
        }
    }
}
