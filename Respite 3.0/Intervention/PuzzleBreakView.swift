import SwiftUI
import UIKit

struct PuzzleBreakView: View {
    @Binding var isPresented: Bool
    var isRegulationSession: Bool = false
    var onSuccessfulSolve: (() -> Void)? = nil
    var onRegulationLeaveFlow: (() -> Void)? = nil

    @State private var puzzle: MathPuzzle = .random()
    @State private var userAnswer: String = ""
    @State private var phase: PuzzlePhase = .solving
    @State private var shakeOffset: CGFloat = 0
    @State private var attemptsLeft: Int = 3
    @State private var didCompleteRegulationSolve = false
    @State private var showTikTokNudge = false
    @FocusState private var isInputFocused: Bool

    enum PuzzlePhase {
        case solving, correct, failed
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                puzzleContent
                    .padding(.horizontal, 24)

                Spacer()

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .navigationTitle("Puzzle Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if phase == .correct || phase == .failed {
                        Button("Done") {
                            if isRegulationSession, phase == .correct { onRegulationLeaveFlow?() }
                            isPresented = false
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .onAppear { isInputFocused = true }
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
        return "Nice work — your brain is sharper than a TikTok algorithm."
    }

    private var tikTokNudgeBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Return to your app")
                .font(.subheadline.weight(.semibold))
            Text("TikTok should open for you now during your grace window.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                onRegulationLeaveFlow?()
                isPresented = false
                openTikTokAfterDismissal()
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
                color: .green
            )
        case .failed:
            resultView(
                emoji: "🧠",
                title: "Answer: \(puzzle.answer)",
                subtitle: "You tried \(3 - attemptsLeft) time\(attemptsLeft < 2 ? "s" : ""). The answer was \(puzzle.answer). Keep your mind sharp!",
                color: .orange
            )
        }
    }

    private var solvingView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                headerBadge

                Text("Solve this to take your break")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            questionCard

            answerField

            attemptsIndicator
        }
    }

    private var headerBadge: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 80, height: 80)
            Text("🧩")
                .font(.system(size: 40))
        }
    }

    private var questionCard: some View {
        VStack(spacing: 8) {
            Text("What is")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(puzzle.question)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("= ?")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .offset(x: shakeOffset)
    }

    private var answerField: some View {
        HStack(spacing: 12) {
            TextField("Your answer", text: $userAnswer)
                .keyboardType(.numberPad)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .focused($isInputFocused)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1.5)
                        )
                )
                .submitLabel(.done)
                .onSubmit { checkAnswer() }

            Button(action: checkAnswer) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(userAnswer.isEmpty ? Color.secondary : Color.purple)
            }
            .disabled(userAnswer.isEmpty)
        }
    }

    private var attemptsIndicator: some View {
        HStack(spacing: 8) {
            Text("Attempts left:")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(0..<3) { i in
                Image(systemName: i < attemptsLeft ? "heart.fill" : "heart")
                    .font(.footnote)
                    .foregroundStyle(i < attemptsLeft ? Color.red : Color.secondary)
            }
        }
    }

    private func resultView(emoji: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 100, height: 100)
                Text(emoji)
                    .font(.system(size: 52))
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(color)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
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
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 28)
                        .background(RoundedRectangle(cornerRadius: 14).fill(color))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var bottomBar: some View {
        Button {
            isPresented = false
        } label: {
            Text(phase == .solving ? "Skip for now" : "Close")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func checkAnswer() {
        guard let typed = Int(userAnswer.trimmingCharacters(in: .whitespaces)) else {
            triggerShake()
            return
        }

        if typed == puzzle.answer {
            withAnimation(.spring(response: 0.5)) {
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
                withAnimation(.spring(response: 0.5)) {
                    phase = .failed
                }
            } else {
                triggerShake()
                isInputFocused = true
            }
        }
    }

    private func triggerShake() {
        withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) {
            shakeOffset = 12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) {
                shakeOffset = 0
            }
        }
    }

    private func openTikTokAfterDismissal() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if let url = URL(string: "tiktok://") {
                RegulationSettingsStore().armTikTokHandoffSuppressWindow()
                UIApplication.shared.open(url)
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

