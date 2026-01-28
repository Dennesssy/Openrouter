import SwiftUI
import SwiftData

struct UsageTrackerView: View {
    @Query(sort: \DailyCostLog.date, order: .reverse) private var dailyLogs: [DailyCostLog]
    @Environment(\.modelContext) private var modelContext

    // Period selection
    @State private var selectedPeriod: Period = .week

    enum Period: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                            value: formatCurrency(filteredLogs.reduce(0) { $0 + $1.totalCost }),
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

                    // Cost Trend Chart (simplified placeholder)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cost Trend")
                            .font(.headline)
                            .padding(.horizontal)

                        if filteredLogs.isEmpty {
                            Text("No data available for selected period")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else {
                            // Placeholder for chart - would implement with SwiftUI Charts
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 200)
                                .overlay(
                                    Text("Chart would show cost over time")
                                        .foregroundStyle(.secondary)
                                )
                                .padding(.horizontal)
                        }
                    }

                    // Model Usage Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Model Usage")
                            .font(.headline)
                            .padding(.horizontal)

                        if filteredLogs.isEmpty {
                            Text("No usage data available")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            // Calculate model usage
                            let modelUsage = calculateModelUsage()

                            ForEach(modelUsage.sorted { $0.value > $1.value }, id: \.key) { modelId, usage in
                                HStack {
                                    Text(modelId)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatCurrency(usage.cost))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Usage Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Computed Properties

    private var filteredLogs: [DailyCostLog] {
        let calendar = Calendar.current
        let now = Date()

        return dailyLogs.filter { log in
            switch selectedPeriod {
            case .day:
                return calendar.isDate(log.date, inSameDayAs: now)
            case .week:
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                return log.date >= weekStart
            case .month:
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
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

    private func calculateModelUsage() -> [String: (cost: Double, tokens: Int)] {
        var usage: [String: (cost: Double, tokens: Int)] = [:]

        for log in filteredLogs {
            // This is a simplified calculation - in a real app you'd store model usage per log
            // For now, we'll aggregate all usage under "Various Models"
            let key = "Various Models"
            usage[key] = (
                cost: (usage[key]?.cost ?? 0) + log.totalCost,
                tokens: (usage[key]?.tokens ?? 0) + log.totalTokens
            )
        }

        return usage
    }
}

// MARK: - Summary Card Component

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

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}

#Preview {
    UsageTrackerView()
        .modelContainer(for: DailyCostLog.self, inMemory: true)
}