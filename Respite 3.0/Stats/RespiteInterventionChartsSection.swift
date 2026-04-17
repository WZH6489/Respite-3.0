import Charts
import SwiftUI

struct RespiteInterventionChartsSection: View {
    @ObservedObject private var stats = RespiteStatsStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var range: RespiteStatsChartRange = .week

    private var points: [RespiteChartPoint] {
        stats.chartPoints(for: range)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Respite activity")
                .font(.headline)

            Text("Cumulative interferences (shield) and estimated minutes saved over the selected window. Estimates use fixed multipliers, not exact usage.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Range", selection: $range) {
                ForEach(RespiteStatsChartRange.allCases) { r in
                    Text(r.menuLabel).tag(r)
                }
            }
            .pickerStyle(.segmented)

            if points.isEmpty || points.allSatisfy({ $0.interruptions == 0 && $0.estimatedMinutesSaved == 0 }) {
                Text("No data in this range yet. Interferences are recorded when you use buttons on the Screen Time shield.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                chartBlock(
                    title: "Interferences (cumulative)",
                    points: points,
                    yValue: \.interruptions,
                    color: .blue
                )

                chartBlock(
                    title: "Est. minutes saved (cumulative)",
                    points: points,
                    yValue: \.estimatedMinutesSaved,
                    color: .green
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                stats.reloadFromDisk()
            }
        }
        .onAppear {
            stats.reloadFromDisk()
        }
    }

    private func chartBlock(
        title: String,
        points: [RespiteChartPoint],
        yValue: KeyPath<RespiteChartPoint, Int>,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value(title, point[keyPath: yValue])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.date),
                        y: .value(title, point[keyPath: yValue])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: range == .today ? 6 : 5))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)
        }
    }
}
