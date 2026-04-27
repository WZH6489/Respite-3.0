import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PuzzleBreakView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    var initialMode: PuzzleLaunchMode = .tile
    var isRegulationSession: Bool = false
    var onSuccessfulSolve: (() -> Void)? = nil

    @State private var mode: PuzzleMode = .tile
    @State private var selectedDifficulty: PuzzleDifficulty = .medium

    @State private var mathPuzzle: MathPuzzle = .random(for: .medium)
    @State private var userAnswer: String = ""
    @State private var attemptsLeft: Int = 3
    @State private var shakeOffset: CGFloat = 0

    @State private var tileBoard: [Int] = TilePuzzle.solvedBoard
    @State private var tileMoves = 0

    @State private var phase: PuzzlePhase = .solving
    @State private var didCompleteRegulationSolve = false
    @State private var showReturnNudge = false
    @State private var contentVisible = false
    @State private var resultScale: CGFloat = 0.92
    @FocusState private var isInputFocused: Bool

    enum PuzzlePhase {
        case solving
        case correct
        case failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RespiteDynamicBackground()

                VStack(spacing: 0) {
                    puzzleContent
                        .padding(.horizontal, 20)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 10)
                        .animation(.easeInOut(duration: 0.35), value: contentVisible)

                    Spacer(minLength: 8)

                    bottomBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if phase != .solving {
                        Button("Done") { isPresented = false }
                            .foregroundStyle(RespiteTheme.duskBlue)
                    }
                }
            }
            .onAppear {
                contentVisible = true
                mode = PuzzleMode(launchMode: initialMode)
                resetPuzzleState()
                isInputFocused = mode == .math
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase != .solving {
                    resultScale = 0.92
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        resultScale = 1.0
                    }
                }
            }
            .onChange(of: mode) { _, _ in
                resetPuzzleState()
            }
            .onChange(of: selectedDifficulty) { _, _ in
                resetPuzzleState()
            }
            .safeAreaInset(edge: .bottom) {
                if showReturnNudge {
                    returnNudgeBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private var puzzleContent: some View {
        Group {
            switch phase {
            case .solving:
                solvingView
            case .correct:
                resultView(
                    title: "Solved",
                    subtitle: isRegulationSession
                        ? "You're unlocked for a short grace period. Return when ready."
                        : "Nice reset. You shifted from passive to active mode.",
                    color: RespiteTheme.pine
                )
                .scaleEffect(resultScale)
            case .failed:
                resultView(
                    title: "Answer: \(mathPuzzle.answer)",
                    subtitle: "No problem. Take a breath and try another one.",
                    color: RespiteTheme.berryAccent
                )
                .scaleEffect(resultScale)
            }
        }
    }

    private var solvingView: some View {
        VStack(spacing: 16) {
            headerCard
                .padding(.top, 8)

            if mode == .math {
                difficultyCard
            }

            if mode == .math {
                mathChallengeCard
            } else {
                tileChallengeCard
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 8) {
            Text("Puzzle Break")
                .font(.system(size: 30, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var difficultyCard: some View {
        VStack(spacing: 12) {
            Picker("Difficulty", selection: $selectedDifficulty) {
                ForEach(PuzzleDifficulty.allCases, id: \.self) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .respiteGlassCard(cornerRadius: 16)
    }

    private var mathChallengeCard: some View {
        VStack(spacing: 12) {
            Text("Solve the expression, then enter the final number.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary)

            Text(mathPuzzle.question)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
                .contentTransition(.numericText())

            Text("= ?")
                .font(.title2)
                .foregroundStyle(textSecondary)

            HStack(spacing: 12) {
                TextField(
                    "",
                    text: $userAnswer,
                    prompt: Text("Answer").foregroundStyle(textSecondary.opacity(0.7))
                )
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .multilineTextAlignment(.center)
                    .focused($isInputFocused)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.24), lineWidth: 1)
                            )
                    )
                    .onSubmit { checkMathAnswer() }

                Button(action: checkMathAnswer) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(userAnswer.isEmpty ? textSecondary : RespiteTheme.duskBlue)
                }
                .disabled(userAnswer.isEmpty)
            }
            .offset(x: shakeOffset)

            HStack(spacing: 8) {
                Text("Attempts left")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < attemptsLeft ? "circle.fill" : "circle")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(i < attemptsLeft ? RespiteTheme.berryAccent : textSecondary.opacity(0.5))
                }
            }
        }
        .padding(18)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var tileChallengeCard: some View {
        VStack(spacing: 12) {
            Text("Slide tiles into order from 1 to 8 with the blank in the last spot.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary)
                .multilineTextAlignment(.center)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(tileBoard.enumerated()), id: \.offset) { index, value in
                    tileView(index: index, value: value)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.14), lineWidth: 1)
                    )
            )

            Text("Moves: \(tileMoves)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary)
        }
        .padding(18)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func tileView(index: Int, value: Int) -> some View {
        Button {
            moveTile(at: index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(value == 0 ? Color.clear : RespiteTheme.duskBlue.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(value == 0 ? Color.clear : RespiteTheme.duskBlue.opacity(0.45), lineWidth: 1)
                    )
                    .frame(height: 64)

                if value != 0 {
                    Text("\(value)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    moveTileBySwipe(from: index, translation: value.translation)
                }
        )
    }

    private func resultView(title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 102, height: 102)
                Image(systemName: phase == .correct ? "checkmark.seal.fill" : "brain")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.system(size: 31, weight: .semibold, design: .default))
                .foregroundStyle(color)

            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)

            if !isRegulationSession {
                Button {
                    InteractionFeedback.tap()
                    phase = .solving
                    resetPuzzleState()
                } label: {
                    Label("Try another", systemImage: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 28)
                        .background(RoundedRectangle(cornerRadius: 14).fill(color))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    private var bottomBar: some View {
        Button {
            InteractionFeedback.tap()
            isPresented = false
        } label: {
            Text(phase == .solving ? "Skip for now" : "Close")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
    }

    private var returnNudgeBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Return to your app")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textPrimary)
            Text("Your app is unlocked for Extra Time.")
                .font(.footnote)
                .foregroundStyle(textSecondary)
            Button {
                returnToPreviousApp()
            } label: {
                Label("Return now", systemImage: "arrow.uturn.backward")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(RespiteTheme.duskBlue)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func resetPuzzleState() {
        phase = .solving
        attemptsLeft = 3
        userAnswer = ""
        mathPuzzle = .random(for: selectedDifficulty)
        tileBoard = TilePuzzle.randomBoard(for: selectedDifficulty)
        tileMoves = 0
        isInputFocused = mode == .math
    }

    private func checkMathAnswer() {
        InteractionFeedback.tap()
        guard mode == .math else { return }
        guard let typed = Int(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            triggerShake()
            return
        }

        if typed == mathPuzzle.answer {
            markSolved()
            return
        }

        attemptsLeft -= 1
        userAnswer = ""

        if attemptsLeft <= 0 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                phase = .failed
            }
        } else {
            triggerShake()
            isInputFocused = true
        }
    }

    private func moveTile(at index: Int) {
        InteractionFeedback.tap()
        guard mode == .tile, phase == .solving else { return }
        guard let emptyIndex = tileBoard.firstIndex(of: 0) else { return }
        guard TilePuzzle.areAdjacent(index, emptyIndex) else { return }

        tileBoard.swapAt(index, emptyIndex)
        tileMoves += 1

        if tileBoard == TilePuzzle.solvedBoard {
            markSolved()
        }
    }

    private func moveTileBySwipe(from index: Int, translation: CGSize) {
        guard mode == .tile, phase == .solving else { return }
        guard abs(translation.width) > 10 || abs(translation.height) > 10 else { return }
        guard let emptyIndex = tileBoard.firstIndex(of: 0) else { return }

        let row = index / 3
        let col = index % 3

        let isHorizontal = abs(translation.width) > abs(translation.height)
        let targetRow: Int
        let targetCol: Int

        if isHorizontal {
            targetRow = row
            targetCol = translation.width > 0 ? col + 1 : col - 1
        } else {
            targetRow = translation.height > 0 ? row + 1 : row - 1
            targetCol = col
        }

        guard (0...2).contains(targetRow), (0...2).contains(targetCol) else { return }
        let targetIndex = (targetRow * 3) + targetCol
        guard emptyIndex == targetIndex else { return }
        moveTile(at: index)
    }

    private func markSolved() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            phase = .correct
        }
        InteractionFeedback.success()
        Task {
            try? await HealthKitMindfulnessStore.writeMindfulness(minutes: mode == .math ? 2 : 3)
        }

        if isRegulationSession, !didCompleteRegulationSolve {
            didCompleteRegulationSolve = true
            onSuccessfulSolve?()
            showReturnNudge = true
        }
    }

    private func triggerShake() {
        InteractionFeedback.warning()
        withAnimation(.interpolatingSpring(stiffness: 620, damping: 10)) {
            shakeOffset = 11
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.interpolatingSpring(stiffness: 620, damping: 10)) {
                shakeOffset = 0
            }
        }
    }

    private var textPrimary: Color { .primary }
    private var textSecondary: Color { .secondary }

    private func returnToPreviousApp() {
        #if canImport(UIKit)
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        #endif
    }
}

private enum PuzzleMode: CaseIterable {
    case tile
    case math

    var title: String {
        switch self {
        case .tile: return "Tile"
        case .math: return "Math"
        }
    }

    init(launchMode: PuzzleLaunchMode) {
        switch launchMode {
        case .tile:
            self = .tile
        case .math:
            self = .math
        }
    }
}

enum PuzzleDifficulty: CaseIterable {
    case easy
    case medium
    case hard

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var shuffleMoves: Int {
        switch self {
        case .easy: return 14
        case .medium: return 30
        case .hard: return 55
        }
    }
}

private enum TilePuzzle {
    static let solvedBoard: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 0]

    static func randomBoard(for difficulty: PuzzleDifficulty) -> [Int] {
        var board = solvedBoard
        var empty = 8
        for _ in 0..<difficulty.shuffleMoves {
            let neighbors = adjacentIndices(of: empty)
            guard let target = neighbors.randomElement() else { continue }
            board.swapAt(empty, target)
            empty = target
        }
        return board
    }

    static func areAdjacent(_ lhs: Int, _ rhs: Int) -> Bool {
        adjacentIndices(of: lhs).contains(rhs)
    }

    private static func adjacentIndices(of index: Int) -> [Int] {
        let row = index / 3
        let col = index % 3
        var output: [Int] = []
        if row > 0 { output.append(index - 3) }
        if row < 2 { output.append(index + 3) }
        if col > 0 { output.append(index - 1) }
        if col < 2 { output.append(index + 1) }
        return output
    }
}

struct MathPuzzle {
    let question: String
    let answer: Int

    static func random(for difficulty: PuzzleDifficulty) -> MathPuzzle {
        let kind = Int.random(in: 0..<4)

        switch (difficulty, kind) {
        case (.easy, 0):
            let a = Int.random(in: 2...12)
            let b = Int.random(in: 1...9)
            return MathPuzzle(question: "\(a) + \(b)", answer: a + b)
        case (.easy, 1):
            let b = Int.random(in: 1...8)
            let a = Int.random(in: b + 2...18)
            return MathPuzzle(question: "\(a) − \(b)", answer: a - b)
        case (.easy, 2):
            let a = Int.random(in: 2...6)
            let b = Int.random(in: 2...5)
            return MathPuzzle(question: "\(a) × \(b)", answer: a * b)
        case (.easy, _):
            let divisor = Int.random(in: 2...6)
            let answer = Int.random(in: 2...10)
            let dividend = divisor * answer
            return MathPuzzle(question: "\(dividend) ÷ \(divisor)", answer: answer)

        case (.medium, 0):
            let a = Int.random(in: 18...64)
            let b = Int.random(in: 9...36)
            return MathPuzzle(question: "\(a) + \(b)", answer: a + b)
        case (.medium, 1):
            let b = Int.random(in: 8...34)
            let a = Int.random(in: b + 10...86)
            return MathPuzzle(question: "\(a) − \(b)", answer: a - b)
        case (.medium, 2):
            let a = Int.random(in: 6...14)
            let b = Int.random(in: 5...12)
            return MathPuzzle(question: "\(a) × \(b)", answer: a * b)
        case (.medium, _):
            let divisor = Int.random(in: 4...11)
            let answer = Int.random(in: 5...18)
            let dividend = divisor * answer
            return MathPuzzle(question: "\(dividend) ÷ \(divisor)", answer: answer)

        case (.hard, 0):
            let a = Int.random(in: 85...240)
            let b = Int.random(in: 35...160)
            return MathPuzzle(question: "\(a) + \(b)", answer: a + b)
        case (.hard, 1):
            let b = Int.random(in: 40...170)
            let a = Int.random(in: b + 20...280)
            return MathPuzzle(question: "\(a) − \(b)", answer: a - b)
        case (.hard, 2):
            let a = Int.random(in: 12...27)
            let b = Int.random(in: 11...22)
            return MathPuzzle(question: "\(a) × \(b)", answer: a * b)
        case (.hard, _):
            let divisor = Int.random(in: 7...18)
            let answer = Int.random(in: 12...34)
            let dividend = divisor * answer
            return MathPuzzle(question: "\(dividend) ÷ \(divisor)", answer: answer)
        }
    }
}
