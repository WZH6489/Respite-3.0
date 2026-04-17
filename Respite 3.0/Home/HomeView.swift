import SwiftUI

struct HomeView: View {
    @ObservedObject private var stats = RespiteStatsStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("respite.home.tiktokShortcutsSetupDismissed") private var tiktokShortcutsSetupDismissed = false
    @State private var showTikTokShortcutsSetup = false

    private var today: (interruptions: Int, sessions: Int, estimatedMinutesSaved: Int) {
        stats.todaySummary()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(DailyWelcomeView.greetingLine(for: Date()))
                        .font(.largeTitle.bold())
                        .padding(.top, 4)

                    Text("Here’s how today is going.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !tiktokShortcutsSetupDismissed {
                        tiktokShortcutsCallout
                    }

                    VStack(spacing: 12) {
                        summaryRow(
                            title: "Scroll interferences",
                            value: "\(today.interruptions)",
                            subtitle: "Times you hit the shield and chose a Respite action.",
                            symbol: "hand.raised.fill"
                        )
                        summaryRow(
                            title: "Regulation sessions",
                            value: "\(today.sessions)",
                            subtitle: "Completed puzzle or breathing from a shield session.",
                            symbol: "checkmark.circle.fill"
                        )
                        summaryRow(
                            title: "Est. time saved",
                            value: formatMinutes(today.estimatedMinutesSaved),
                            subtitle: "Rough estimate from interruptions and sessions — not exact screen time.",
                            symbol: "clock.fill"
                        )
                    }

                    Text("Estimates use simple multipliers so you can spot trends; see the Stats tab for charts.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                stats.reloadFromDisk()
            }
        }
        .onAppear {
            stats.reloadFromDisk()
        }
        .sheet(isPresented: $showTikTokShortcutsSetup) {
            TikTokShortcutsSetupSheet()
        }
    }

    private var tiktokShortcutsCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TikTok calm (Shortcuts)")
                        .font(.subheadline.weight(.semibold))
                    Text("iOS can’t turn on automations for you—one Add in Shortcuts is normal. Use a ready-made link when available, or open full steps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    tiktokShortcutsSetupDismissed = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            Button {
                showTikTokShortcutsSetup = true
            } label: {
                Text(RespiteTikTokShortcutSetup.hasPrebuiltShareLink ? "Add pre-built automation" : "Set up TikTok calm")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func summaryRow(title: String, value: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func formatMinutes(_ m: Int) -> String {
        if m < 60 {
            return "\(m) min"
        }
        let h = m / 60
        let rem = m % 60
        if rem == 0 {
            return "\(h) hr"
        }
        return "\(h) hr \(rem) min"
    }
}
