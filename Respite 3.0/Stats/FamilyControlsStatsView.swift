import SwiftUI
import FamilyControls
import DeviceActivity

struct FamilyControlsStatsView: View {
    @State private var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var didAttemptAuthorization = false
    @State private var requestErrorMessage: String?
    @State private var reportContext: DeviceActivityReport.Context = .respiteBarGraph

    private let settings = RegulationSettingsStore()

    private var weekInterval: DateInterval {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        return DateInterval(start: start, end: .now)
    }

    private var deviceActivityFilter: DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(during: weekInterval),
            users: .all,
            devices: .init([.iPhone, .iPad]),
            applications: [],
            categories: [],
            webDomains: []
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    summaryGrid
                    accessCard
                    if authorizationStatus == .approved {
                        chartCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(RespiteTheme.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onReceive(AuthorizationCenter.shared.$authorizationStatus) { newStatus in
            authorizationStatus = newStatus
        }
        .task {
            guard !didAttemptAuthorization else { return }
            didAttemptAuthorization = true
            await ensureAuthorization()
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your weekly rhythm")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(RespiteTheme.textPrimary)
            Text("A calm overview of progress and protection.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
        }
    }

    private var summaryGrid: some View {
        HStack(spacing: 12) {
            statTile(title: "Saved today", value: "\(DailyProgressStore.minutesSavedToday())m", caption: "From completed interventions")
            statTile(title: "Apps blocked", value: "\(blockedAppsCount)", caption: "Daily \(dailyLimitAppsCount) · Gate \(intentGateAppsCount)")
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
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .background(cardBackground)
    }

    @ViewBuilder
    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch authorizationStatus {
            case .notDetermined:
                Text("Family Controls is not enabled yet.")
                    .font(.headline)
                    .foregroundStyle(RespiteTheme.textPrimary)
                Text("Enable access to render app and category activity.")
                    .foregroundStyle(RespiteTheme.textSecondary)
                actionButton(title: "Enable Family Controls") {
                    Task { await requestAuthorization() }
                }

            case .denied:
                Text("Family Controls access is unavailable.")
                    .font(.headline)
                    .foregroundStyle(RespiteTheme.textPrimary)
                Text("Review Screen Time permissions and try again.")
                    .foregroundStyle(RespiteTheme.textSecondary)
                if let requestErrorMessage {
                    Text(requestErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                actionButton(title: "Request Again") {
                    Task { await requestAuthorization() }
                }

            case .approved:
                Text("Family Controls enabled.")
                    .font(.headline)
                    .foregroundStyle(RespiteTheme.textPrimary)
                Text("Showing the last 7 days of app activity.")
                    .foregroundStyle(RespiteTheme.textSecondary)

            default:
                Text("Family Controls status updated.")
                    .font(.headline)
                    .foregroundStyle(RespiteTheme.textPrimary)
                actionButton(title: "Refresh Authorization") {
                    Task { await requestAuthorization() }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Chart", selection: $reportContext) {
                Text("Bar Graph").tag(DeviceActivityReport.Context.respiteBarGraph)
                Text("Pie Chart").tag(DeviceActivityReport.Context.respitePieChart)
            }
            .pickerStyle(.segmented)
            .tint(RespiteTheme.duskBlue)

            DeviceActivityReport(reportContext, filter: deviceActivityFilter)
                .frame(maxWidth: .infinity, minHeight: 380, alignment: .top)

            Text("If this looks empty, open the selected apps first so iOS can collect activity samples.")
                .font(.footnote)
                .foregroundStyle(RespiteTheme.textMuted)
        }
        .padding(16)
        .background(cardBackground)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(RespiteTheme.duskBlue)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(RespiteTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(RespiteTheme.border, lineWidth: 1)
            )
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

    private func ensureAuthorization() async {
        guard authorizationStatus == .notDetermined else { return }
        await requestAuthorization()
    }

    private func requestAuthorization() async {
        do {
            requestErrorMessage = nil
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            requestErrorMessage = error.localizedDescription
        }
    }
}

private extension DeviceActivityReport.Context {
    static let respiteBarGraph = Self("Respite Bar Graph")
    static let respitePieChart = Self("Respite Pie Chart")
}
