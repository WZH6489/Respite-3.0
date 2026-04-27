import SwiftUI

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss

    private let streakGoalMinutes = RegulationSettingsStore().streakGoalMinutes

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard

                    ForEach(AchievementBadge.allCases) { badge in
                        achievementRow(badge)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(RespiteDynamicBackground().ignoresSafeArea())
            .navigationTitle("All achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var snapshot: AchievementSnapshot {
        AchievementsStore.snapshot(streakGoalMinutes: streakGoalMinutes)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unlocked")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text("\(snapshot.unlocked.count) / \(AchievementBadge.allCases.count)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Next milestone: \(snapshot.nextMilestone)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func achievementRow(_ badge: AchievementBadge) -> some View {
        let unlocked = snapshot.unlocked.contains(badge)
        return HStack(spacing: 12) {
            Image(systemName: badge.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(unlocked ? RespiteTheme.pine : .secondary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((unlocked ? RespiteTheme.pine : Color.secondary).opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(badge.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(unlocked ? "Unlocked" : "Locked")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(unlocked ? RespiteTheme.pine : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill((unlocked ? RespiteTheme.pine : Color.secondary).opacity(0.12))
                )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 16)
    }
}
