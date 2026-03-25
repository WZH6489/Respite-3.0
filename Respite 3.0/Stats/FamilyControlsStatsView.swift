import SwiftUI
import FamilyControls
import DeviceActivity

struct FamilyControlsStatsView: View {
    @State private var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var didAttemptAuthorization = false
    @State private var requestErrorMessage: String?

    @State private var reportContext: DeviceActivityReport.Context = .respiteBarGraph

    private var weekInterval: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now) ?? DateInterval(start: .now, duration: 7 * 24 * 60 * 60)
    }

    private var deviceActivityFilter: DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(during: weekInterval),
            // This SDK only exposes `.children` and `.all` for DeviceActivityFilter.Users.
            // Use `.all` to include the user's own authorized activity.
            users: .all,
            devices: .init([.iPhone, .iPad]),
            // Empty sets mean "no token filtering" in this SDK.
            applications: [],
            categories: [],
            webDomains: []
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if authorizationStatus == .approved {
                        Picker("Chart", selection: $reportContext) {
                            Text("Bar Graph").tag(DeviceActivityReport.Context.respiteBarGraph)
                            Text("Pie Chart").tag(DeviceActivityReport.Context.respitePieChart)
                        }
                        .pickerStyle(.segmented)

                        // DeviceActivityReport is a privacy-preserving report rendered by
                        // the app's Device Activity Report Extension.
                        DeviceActivityReport(reportContext, filter: deviceActivityFilter)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .navigationTitle("Stats")
        }
        .onReceive(AuthorizationCenter.shared.$authorizationStatus) { newStatus in
            authorizationStatus = newStatus
        }
        .task {
            // Request authorization on first launch (or after external changes).
            guard !didAttemptAuthorization else { return }
            didAttemptAuthorization = true
            await ensureAuthorization()
        }
    }

    @ViewBuilder
    private var header: some View {
        switch authorizationStatus {
        case .notDetermined:
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Controls isn’t enabled yet.")
                    .font(.headline)
                Text("Enable access to show your weekly app and category stats.")
                    .foregroundStyle(.secondary)

                Button {
                    Task { await requestAuthorization() }
                } label: {
                    Text("Enable Family Controls")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Controls access was denied.")
                    .font(.headline)
                Text("You may be able to request authorization again from here.")
                    .foregroundStyle(.secondary)

                if let requestErrorMessage {
                    Text(requestErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await requestAuthorization() }
                } label: {
                    Text("Request Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

        case .approved:
            VStack(alignment: .leading, spacing: 6) {
                Text("Family Controls enabled.")
                    .font(.headline)
                Text("Loading your weekly stats.")
                    .foregroundStyle(.secondary)
            }

        @unknown default:
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Controls status updated.")
                    .font(.headline)
                Text("Please refresh authorization to continue.")
                    .foregroundStyle(.secondary)

                Button {
                    Task { await requestAuthorization() }
                } label: {
                    Text("Refresh Authorization")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

        }
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
    // These raw-values must match the extension's supported contexts.
    static let respiteBarGraph = Self("Respite Bar Graph")
    static let respitePieChart = Self("Respite Pie Chart")
}

