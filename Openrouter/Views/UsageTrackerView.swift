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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyCostLog.date, order: .reverse) private var dailyLogs: [DailyCostLog]
    @Query private var preferences: [UserPreferences]

    @State private var selectedPeriod: Period = .week
    @State private var showPremiumAlert = false

    enum Period: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
    }

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    private var filteredLogs: [DailyCostLog] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .day:
            let today = DailyCostLog.startOfDay(for: now)
            return dailyLogs.filter { calendar.isDate($0.date, inSameDayAs: today) }
        case .week:
            let weekDates = DailyCostLog.thisWeek()
            return dailyLogs.filter { weekDates.contains($0.date) }
        case .month:
            let monthDates = DailyCostLog.thisMonth()
            return dailyLogs.filter { monthDates.contains($0.date) }
        }
    }

    private var totalSpent: Double {
        filteredLogs.reduce(0) { $0 + $1.totalSpent }
    }

    private var totalMessages: Int {
        filteredLogs.reduce(0) { $0 + $1.messageCount }
    }

    private var averageCostPerMessage: Double {
        guard totalMessages > 0 else { return 0 }
        return totalSpent / Double(totalMessages)
    }

    private var budgetStatus: BudgetStatus {
        guard let budget = userPreferences?.dailyBudgetLimit else { return .noBudget }
        let spent = totalSpent
        let percentage = (spent / budget) * 100

        if percentage >= 100 {
            return .exceeded
        } else if percentage >= 80 {
            return .warning
        } else {
            return .good
        }
    }

    enum BudgetStatus {
        case noBudget
        case good
        case warning
        case exceeded

        var color: Color {
            switch self {
            case .noBudget: return .secondary
            case .good: return .green
            case .warning: return .orange
            case .exceeded: return .red
            }
        }

        var icon: String {
            switch self {
            case .noBudget: return "dollarsign.circle"
            case .good: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .exceeded: return "xmark.circle"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(Period.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Summary Cards
                    HStack(spacing: 12) {
                        SummaryCard(
                            title: "Total Spent",
                            value: String(format: "$%.2f", totalSpent),
                            subtitle: selectedPeriod.rawValue.lowercased(),
                            icon: "dollarsign.circle",
                            color: .blue
                        )

                        SummaryCard(
                            title: "Messages",
                            value: "\(totalMessages)",
                            subtitle: selectedPeriod.rawValue.lowercased(),
                            icon: "message",
                            color: .green
                        )

                        SummaryCard(
                            title: "Avg Cost",
                            value: String(format: "$%.3f", averageCostPerMessage),
                            subtitle: "per message",
                            icon: "chart.bar",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)

                    // Budget Status (if premium or has budget set)
                    if let budget = userPreferences?.dailyBudgetLimit {
                        BudgetStatusCard(
                            budget: budget,
                            spent: totalSpent,
                            status: budgetStatus,
                            isPremium: userPreferences?.isSubscribedToPremium ?? false
                        )
                        .padding(.horizontal)
                    }

                    // Spending Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spending Trend")
                            .font(.headline)
                            .padding(.horizontal)

                        if filteredLogs.isEmpty {
                            EmptyChartView()
                        } else {
                            SpendingChart(logs: filteredLogs.sorted { $0.date < $1.date })
                                .frame(height: 200)
                                .padding(.horizontal)
                        }
                    }

                    // Model Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Model Usage")
                            .font(.headline)
                            .padding(.horizontal)

                        if filteredLogs.isEmpty {
                            Text("No usage data available")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ModelBreakdownView(logs: filteredLogs)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Usage Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !(userPreferences?.isSubscribedToPremium ?? false) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showPremiumAlert = true }) {
                            Image(systemName: "crown")
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            .alert("Premium Feature", isPresented: $showPremiumAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Upgrade") {
                    // TODO: Navigate to subscription view
                }
            } message: {
                Text("Advanced analytics, export features, and custom model ordering are available with Premium.")
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BudgetStatusCard: View {
    let budget: Double
    let spent: Double
    let status: UsageTrackerView.BudgetStatus
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Budget Status")
                    .font(.headline)

                Spacer()

                Image(systemName: status.icon)
                    .foregroundColor(status.color)

                if !isPremium {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }

            if isPremium {
                ProgressView(value: min(spent / budget, 1.0))
                    .tint(status.color)

                HStack {
                    Text(String(format: "$%.2f spent", spent))
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "$%.2f budget", budget))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(status.color)
            } else {
                Text("Set daily spending limits with Premium")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var statusMessage: String {
        let percentage = (spent / budget) * 100
        switch status {
        case .good:
            return String(format: "%.0f%% of daily budget used", percentage)
        case .warning:
            return String(format: "⚠️ %.0f%% of daily budget used", percentage)
        case .exceeded:
            return String(format: "🚨 Budget exceeded by $%.2f", spent - budget)
        case .noBudget:
            return ""
        }
    }
}

struct SpendingChart: View {
    let logs: [DailyCostLog]

    var body: some View {
        Chart {
            ForEach(logs) { log in
                LineMark(
                    x: .value("Date", log.date),
                    y: .value("Spent", log.totalSpent)
                )
                .foregroundStyle(.blue)

                PointMark(
                    x: .value("Date", log.date),
                    y: .value("Spent", log.totalSpent)
                )
                .foregroundStyle(.blue)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "$%.2f", doubleValue))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let dateValue = value.as(Date.self) {
                        Text(dateValue.formatted(.dateTime.day().month()))
                    }
                }
            }
        }
    }
}

struct ModelBreakdownView: View {
    let logs: [DailyCostLog]

    private var modelCosts: [(model: String, cost: Double)] {
        var breakdown: [String: Double] = [:]

        for log in logs {
            for (model, cost) in log.modelBreakdown {
                breakdown[model, default: 0] += cost
            }
        }

        return breakdown.map { ($0.key, $0.value) }
            .sorted { $0.cost > $1.cost }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(modelCosts.prefix(5), id: \.model) { item in
                HStack {
                    Text(item.model)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    Text(String(format: "$%.3f", item.cost))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            if modelCosts.count > 5 {
                Text("+\(modelCosts.count - 5) more models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No spending data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Start chatting to see your usage analytics")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    UsageTrackerView()
        .modelContainer(for: [DailyCostLog.self, UserPreferences.self], inMemory: true)
}