import SwiftUI

struct ActivityBreakdownView: View {
    let configuration: ActivityBreakdownConfiguration

    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()

    private func formatDuration(_ duration: TimeInterval) -> String {
        Self.formatter.string(from: duration) ?? "0m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Controls Stats")
                .font(.headline)

            Text("Total: \(formatDuration(configuration.totalDuration))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if configuration.categories.isEmpty {
                Text("No activity data available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(configuration.categories) { category in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.name)
                            .font(.headline)
                        Text(formatDuration(category.duration))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(category.apps) { app in
                                HStack {
                                    Text(app.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatDuration(app.duration))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .padding()
    }
}

