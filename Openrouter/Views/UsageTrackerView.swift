//
//  UsageTrackerView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData
import Charts

struct UsageTrackerView: View {
    @Query(sort: \DailyCostLog.date, order: .forward) private var dailyLogs: [DailyCostLog]
    @Environment(\.modelContext) private var modelContext

    // Period selection
    @State private var selectedPeriod: Period = .week

    enum Period: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Period Picker
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(Period.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        SummaryCard(
                            title: "Total Cost",
                            value: formatCurrency(filteredLogs.reduce(0) { $0 + $1.totalSpent }),
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )

                        SummaryCard(
                            title: "Total Tokens",
                            value: formatNumber(filteredLogs.reduce(0) { $0 + $1.totalTokens }),
                            icon: "number.circle.fill",
                            color: .blue
                        )

                        SummaryCard(
                            title: "Messages",
                            value: formatNumber(filteredLogs.reduce(0) { $0 + $1.messageCount }),
                            icon: "message.fill",
                            color: .orange
                        )

                        SummaryCard(
                            title: "Sessions",
                            value: formatNumber(filteredLogs.reduce(0) { $0 + $1.sessionCount }),
                            icon: "rectangle.stack.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)

                    // Cost Trend Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cost Trend")
                            .font(.headline)
                            .padding(.horizontal)

                        if filteredLogs.isEmpty {
                            EmptyStateView(message: "No data available")
                        } else {
                            Chart(filteredLogs) { log in
                                LineMark(
                                    x: .value("Date", log.date, unit: .day),
                                    y: .value("Cost", log.totalSpent)
                                )
                                .interpolationMethod(.catmullRom)
                                .symbol(by: .value("Date", log.date))

                                AreaMark(
                                    x: .value("Date", log.date, unit: .day),
                                    y: .value("Cost", log.totalSpent)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .blue.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                            .chartYAxis {
                                AxisMarks(format: .currency(code: "USD"))
                            }
                            .frame(height: 220)
                            .padding(.horizontal)
                        }
                    }

                    // Model Usage Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Model Cost Distribution")
                            .font(.headline)
                            .padding(.horizontal)

                        if filteredLogs.isEmpty {
                            EmptyStateView(message: "No usage data available")
                        } else {
                            let modelUsage = calculateModelUsage()
                            let sortedUsage = modelUsage.sorted { $0.value > $1.value }

                            // Donut Chart
                            Chart(sortedUsage, id: \.key) { key, value in
                                SectorMark(
                                    angle: .value("Cost", value),
                                    innerRadius: .ratio(0.618),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("Model", key))
                            }
                            .frame(height: 220)
                            .padding(.horizontal)

                            // Legend List
                            VStack(spacing: 8) {
                                ForEach(sortedUsage, id: \.key) { modelId, cost in
                                    HStack {
                                        Circle()
                                            .fill(Color.blue) // In a real app, match chart colors
                                            .frame(width: 8, height: 8)
                                        Text(modelId)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(formatCurrency(cost))
                                            .font(.subheadline)
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Usage Analytics")
            // REMOVED: .navigationBarTitleDisplayMode(.inline) - not available on macOS
        }
    }

    // MARK: - Computed Properties

    private var filteredLogs: [DailyCostLog] {
        let calendar = Calendar.current
        let now = Date()

        return dailyLogs.filter { log in
            switch selectedPeriod {
            case .week:
                let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
                return log.date >= weekStart
            case .month:
                let monthStart = calendar.date(byAdding: .month, value: -1, to: now)!
                return log.date >= monthStart
            case .all:
                return true
            }
        }
    }

    // MARK: - Helper Methods

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func calculateModelUsage() -> [String: Double] {
        var usage: [String: Double] = [:]

        for log in filteredLogs {
            for (modelId, cost) in log.modelBreakdown {
                usage[modelId, default: 0] += cost
            }
        }

        return usage
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor)) // FIXED: macOS color
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyStateView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5)) // FIXED: macOS color
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

#Preview {
    UsageTrackerView()
        .modelContainer(for: DailyCostLog.self, inMemory: true)
}
