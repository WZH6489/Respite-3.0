import SwiftUI
import UIKit
import FamilyControls

struct DashboardView: View {
    @EnvironmentObject private var interventions: InterventionManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var now = Date()

    private let settings = RegulationSettingsStore()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    statsGrid
                    blockedAppsCard
                    quoteCard
                    interventionsCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { now = Date() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(dayGreeting), \(displayName)")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(RespiteTheme.textPrimary)

            Text(daySubtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RespiteTheme.surfaceSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(RespiteTheme.border, lineWidth: 1)
                )
        )
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statTile(
                title: "Time saved today",
                value: savedMinutesString,
                caption: "Estimated from completed interventions"
            )

            statTile(
                title: "Apps blocked",
                value: "\(blockedAppsCount)",
                caption: blockedAppsCaption
            )
        }
    }

    private func statTile(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(RespiteTheme.textPrimary)

            Text(caption)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textMuted)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RespiteTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(RespiteTheme.border.opacity(0.8), lineWidth: 1)
                )
        )
    }

    private var blockedAppsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Blocked app setup")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(RespiteTheme.textPrimary)

            blockRow(label: "Daily limit", value: "\(dailyLimitAppsCount) apps")
            blockRow(label: "Intent gate", value: "\(intentGateAppsCount) apps")

            if blockedAppsCount == 0 {
                Text("No blocked apps selected yet. Add them in Settings.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(RespiteTheme.textMuted)
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RespiteTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(RespiteTheme.border.opacity(0.8), lineWidth: 1)
                )
        )
    }

    private func blockRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(RespiteTheme.textPrimary)
        }
    }

    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily quote")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            Text(dailyQuote)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(RespiteTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RespiteTheme.quoteGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(RespiteTheme.border, lineWidth: 1)
                )
        )
    }

    private var interventionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start a mindful interruption")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(RespiteTheme.textPrimary)

            actionRow(
                title: "Intent check",
                subtitle: "Pause and name your reason before opening.",
                action: { interventions.triggerTikTokGate() }
            )

            actionRow(
                title: "Puzzle break",
                subtitle: "Switch from passive to active mode quickly.",
                action: { interventions.triggerPuzzleBreak() }
            )

            actionRow(
                title: "Breathwork timer",
                subtitle: "Three guided 4-7-8 cycles to reset.",
                action: { interventions.triggerBreathwork() }
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RespiteTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(RespiteTheme.border.opacity(0.8), lineWidth: 1)
                )
        )
    }

    private func actionRow(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(RespiteTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(RespiteTheme.textMuted)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RespiteTheme.duskBlue)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var background: LinearGradient { RespiteTheme.appBackground }

    private var dayGreeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var displayName: String {
        let deviceName = UIDevice.current.name
        if let ownerPart = deviceName.split(separator: "'").first,
           ownerPart.count > 1 {
            return String(ownerPart)
        }
        if let firstWord = deviceName.split(separator: " ").first,
           firstWord.count > 1 {
            return String(firstWord)
        }
        return "there"
    }

    private var daySubtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return "\(formatter.string(from: now)) · Keep your focus gentle and steady."
    }

    private var savedMinutesString: String {
        let minutes = DailyProgressStore.minutesSavedToday()
        return "\(minutes)m"
    }

    private var blockedAppsCount: Int {
        let dailyApps = settings.loadSelection()?.applicationTokens ?? []
        let intentApps = settings.loadTikTokSelection()?.applicationTokens ?? []
        return dailyApps.union(intentApps).count
    }

    private var dailyLimitAppsCount: Int {
        (settings.loadSelection()?.applicationTokens.count) ?? 0
    }

    private var intentGateAppsCount: Int {
        (settings.loadTikTokSelection()?.applicationTokens.count) ?? 0
    }

    private var blockedAppsCaption: String {
        if blockedAppsCount == 0 { return "No apps selected yet" }
        return "Daily \(dailyLimitAppsCount) · Gate \(intentGateAppsCount)"
    }

    private var dailyQuote: String {
        let quotes = [
            "Small pauses make strong days.",
            "Attention is a home. Return to it gently.",
            "What you repeat becomes your rhythm.",
            "Quiet choices change loud habits.",
            "Focus grows where intention goes.",
            "A calm minute now saves an hour later.",
            "Protect your mornings and your mind follows."
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
        return quotes[dayIndex % quotes.count]
    }
}
