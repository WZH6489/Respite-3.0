import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var interventions: InterventionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    interventionCard(
                        icon: "logo.tiktok",
                        systemIcon: "wind",
                        title: "Breathing gate",
                        description: "Five slow breaths (2s in, 3s out) — the same flow as Screen Time and idle prompts.",
                        accentColor: .black,
                        action: { interventions.presentBreathingGate(.externalLaunch) }
                    )

                    interventionCard(
                        icon: "🧩",
                        systemIcon: nil,
                        title: "Puzzle Break",
                        description: "Solve a quick math puzzle to engage your brain instead of scrolling.",
                        accentColor: .purple,
                        action: { interventions.triggerPuzzleBreak() }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Respite")
            .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private func interventionCard(
        icon: String,
        systemIcon: String?,
        title: String,
        description: String,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accentColor.opacity(accentColor == .black ? 1.0 : 0.12))
                        .frame(width: 56, height: 56)

                    if let sys = systemIcon {
                        Image(systemName: sys)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(accentColor == .black ? .white : accentColor)
                    } else {
                        Text(icon)
                            .font(.system(size: 28))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}
