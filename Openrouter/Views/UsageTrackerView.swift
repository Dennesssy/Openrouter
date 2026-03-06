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
    @Query private var preferences: [UserPreferences]
    @Environment(\.modelContext) private var modelContext

    // Period selection
    @State private var selectedPeriod: Period = .week
    @State private var showExportSheet = false

    enum Period: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
    
    private var userPreferences: UserPreferences? {
        preferences.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with Period Picker and Export
                    VStack(spacing: 12) {
                        HStack {
                            Text("Usage Analytics")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button {
                                showExportSheet = true
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(Period.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }
                    .padding(.top)

                    // Budget Overview Card (if budget is set)
                    if let dailyBudget = userPreferences?.dailyBudgetLimit, dailyBudget > 0 {
                        BudgetOverviewCard(
                            dailyBudget: dailyBudget,
                            todaySpent: getTodaySpending(),
                            periodSpent: filteredLogs.reduce(0) { $0 + $1.totalSpent }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        SummaryCard(
                            title: "Total Cost",
                            value: formatCurrency(filteredLogs.reduce(0) { $0 + $1.totalSpent }),
                            subtitle: averageCostPerDay,
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )

                        SummaryCard(
                            title: "Total Tokens",
                            value: formatNumber(filteredLogs.reduce(0) { $0 + $1.totalTokens }),
                            subtitle: averageTokensPerMessage,
                            icon: "number.circle.fill",
                            color: .blue
                        )

                        SummaryCard(
                            title: "Messages",
                            value: formatNumber(filteredLogs.reduce(0) { $0 + $1.messageCount }),
                            subtitle: "\(filteredLogs.count) active days",
                            icon: "message.fill",
                            color: .orange
                        )

                        SummaryCard(
                            title: "Sessions",
                            value: formatNumber(filteredLogs.reduce(0) { $0 + $1.sessionCount }),
                            subtitle: averageSessionsPerDay,
                            icon: "rectangle.stack.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)

                    // Cost Trend Chart
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cost Trend")
                                    .font(.headline)
                                Text("Daily spending over time")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Peak day indicator
                            if let peakDay = filteredLogs.max(by: { $0.totalSpent < $1.totalSpent }) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Peak Day")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(formatCurrency(peakDay.totalSpent))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(.horizontal)

                        if filteredLogs.isEmpty {
                            EmptyStateView(message: "No data available", icon: "chart.line.uptrend.xyaxis")
                        } else {
                            Chart(filteredLogs) { log in
                                LineMark(
                                    x: .value("Date", log.date, unit: .day),
                                    y: .value("Cost", log.totalSpent)
                                )
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .symbol {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                }

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
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month().day(), centered: true)
                                }
                            }
                            .frame(height: 240)
                            .padding(.horizontal)
                        }
                    }
                    .padding()
#if os(iOS)
                    .background(Color(.systemGray6).opacity(0.5))
#else
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
#endif
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Model Usage Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Model Usage Breakdown")
                                    .font(.headline)
                                Text("Cost distribution by AI model")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)

                        if filteredLogs.isEmpty {
                            EmptyStateView(message: "No usage data available", icon: "cpu")
                        } else {
                            let modelStats = calculateDetailedModelStats()
                            let sortedStats = modelStats.sorted { $0.value.cost > $1.value.cost }

                            if sortedStats.isEmpty {
                                EmptyStateView(message: "No model usage data", icon: "cpu")
                            } else {
                                // Donut Chart
                                VStack(spacing: 8) {
                                    Chart(sortedStats.prefix(8), id: \.key) { key, value in
                                        SectorMark(
                                            angle: .value("Cost", value.cost),
                                            innerRadius: .ratio(0.618),
                                            angularInset: 1.5
                                        )
                                        .cornerRadius(5)
                                        .foregroundStyle(by: .value("Model", key))
                                    }
                                    .frame(height: 240)
                                    .padding(.horizontal)
                                    
                                    if sortedStats.count > 8 {
                                        Text("Showing top 8 models by cost")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                // Detailed Stats List
                                VStack(spacing: 12) {
                                    ForEach(sortedStats, id: \.key) { modelId, stats in
                                        ModelUsageRow(
                                            modelId: modelId,
                                            cost: stats.cost,
                                            tokens: stats.tokens,
                                            messages: stats.messages
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding()
#if os(iOS)
                    .background(Color(.systemGray6).opacity(0.5))
#else
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
#endif
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Usage Analytics")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .sheet(isPresented: $showExportSheet) {
                ExportView(logs: filteredLogs, period: selectedPeriod.rawValue)
            }
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
    
    private var averageCostPerDay: String {
        guard !filteredLogs.isEmpty else { return "$0.00/day" }
        let totalCost = filteredLogs.reduce(0) { $0 + $1.totalSpent }
        let avgCost = totalCost / Double(filteredLogs.count)
        return String(format: "$%.2f/day", avgCost)
    }
    
    private var averageTokensPerMessage: String {
        let totalTokens = filteredLogs.reduce(0) { $0 + $1.totalTokens }
        let totalMessages = filteredLogs.reduce(0) { $0 + $1.messageCount }
        guard totalMessages > 0 else { return "0 avg" }
        let avg = totalTokens / totalMessages
        return "\(formatNumber(avg)) avg"
    }
    
    private var averageSessionsPerDay: String {
        guard !filteredLogs.isEmpty else { return "0/day" }
        let totalSessions = filteredLogs.reduce(0) { $0 + $1.sessionCount }
        let avgSessions = Double(totalSessions) / Double(filteredLogs.count)
        return String(format: "%.1f/day", avgSessions)
    }
    
    private func getTodaySpending() -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return dailyLogs.first { calendar.isDate($0.date, inSameDayAs: today) }?.totalSpent ?? 0
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
    
    struct ModelUsageStats {
        var cost: Double
        var tokens: Int
        var messages: Int
    }
    
    private func calculateDetailedModelStats() -> [String: ModelUsageStats] {
        var stats: [String: ModelUsageStats] = [:]

        for log in filteredLogs {
            for (modelId, cost) in log.modelBreakdown {
                let existingStats = stats[modelId] ?? ModelUsageStats(cost: 0, tokens: 0, messages: 0)
                stats[modelId] = ModelUsageStats(
                    cost: existingStats.cost + cost,
                    tokens: existingStats.tokens + (log.modelTokens[modelId] ?? 0),
                    messages: existingStats.messages + (log.modelMessages[modelId] ?? 0)
                )
            }
        }

        return stats
    }
}

// MARK: - Supporting Views

struct BudgetOverviewCard: View {
    let dailyBudget: Double
    let todaySpent: Double
    let periodSpent: Double
    
    private var budgetProgress: Double {
        min(todaySpent / dailyBudget, 1.0)
    }
    
    private var budgetColor: Color {
        if budgetProgress < 0.5 { return .green }
        if budgetProgress < 0.8 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Budget")
                        .font(.headline)
                    Text("Daily spending limit: \(formatCurrency(dailyBudget))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                HStack {
                    Text(formatCurrency(todaySpent))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(budgetColor)
                    
                    Spacer()
                    
                    Text("\(Int(budgetProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(budgetColor)
                            .frame(width: geometry.size.width * budgetProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text("Remaining: \(formatCurrency(max(dailyBudget - todaySpent, 0)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(.systemGray6))
#else
        .background(Color(nsColor: .controlBackgroundColor))
#endif
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    
    init(title: String, value: String, subtitle: String? = nil, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }

            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.8)
                    .monospacedDigit()

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
#if os(iOS)
        .background(Color(.systemGray6))
#else
        .background(Color(nsColor: .controlBackgroundColor))
#endif
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct EmptyStateView: View {
    let message: String
    let icon: String
    
    init(message: String, icon: String = "chart.xyaxis.line") {
        self.message = message
        self.icon = icon
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
#if os(iOS)
        .background(Color(.systemGray6).opacity(0.5))
#else
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
#endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct ModelUsageRow: View {
    let modelId: String
    let cost: Double
    let tokens: Int
    let messages: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Text(modelId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formatCurrency(cost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "number.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(formatNumber(tokens)) tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(messages) msg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(averageCostPerMessage)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
#if os(iOS)
        .background(Color(.systemGray6))
#else
        .background(Color(nsColor: .controlBackgroundColor))
#endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var averageCostPerMessage: String {
        guard messages > 0 else { return "$0.00/msg" }
        let avg = cost / Double(messages)
        return String(format: "$%.4f/msg", avg)
    }
    
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
}

// MARK: - Export View

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    let logs: [DailyCostLog]
    let period: String
    
    @State private var exportFormat: ExportFormat = .csv
    @State private var includeModelBreakdown = true
    @State private var showShareSheet = false
    @State private var exportedText = ""
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case markdown = "Markdown"
        case json = "JSON"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Export Options") {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Include Model Breakdown", isOn: $includeModelBreakdown)
                }
                
                Section("Preview") {
                    ScrollView {
                        Text(generateExportText())
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                }
                
                Section {
                    Button {
                        exportedText = generateExportText()
                        showShareSheet = true
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Export Usage Data")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
#if os(iOS)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: exportedText, format: exportFormat)
            }
#endif
        }
    }
    
    private func generateExportText() -> String {
        switch exportFormat {
        case .csv:
            return generateCSV()
        case .markdown:
            return generateMarkdown()
        case .json:
            return generateJSON()
        }
    }
    
    private func generateCSV() -> String {
        var csv = "Date,Total Cost,Messages,Tokens,Sessions\n"
        
        for log in logs {
            let dateStr = formatDate(log.date)
            csv += "\(dateStr),\(log.totalSpent),\(log.messageCount),\(log.totalTokens),\(log.sessionCount)\n"
        }
        
        if includeModelBreakdown {
            csv += "\n\nModel Breakdown\n"
            csv += "Model,Cost,Messages,Tokens\n"
            
            var modelStats: [String: (cost: Double, messages: Int, tokens: Int)] = [:]
            for log in logs {
                for (modelId, cost) in log.modelBreakdown {
                    let existing = modelStats[modelId] ?? (0, 0, 0)
                    modelStats[modelId] = (
                        existing.cost + cost,
                        existing.messages + (log.modelMessages[modelId] ?? 0),
                        existing.tokens + (log.modelTokens[modelId] ?? 0)
                    )
                }
            }
            
            for (modelId, stats) in modelStats.sorted(by: { $0.value.cost > $1.value.cost }) {
                csv += "\(modelId),\(stats.cost),\(stats.messages),\(stats.tokens)\n"
            }
        }
        
        return csv
    }
    
    private func generateMarkdown() -> String {
        var md = "# Usage Analytics Report\n\n"
        md += "**Period:** \(period)\n\n"
        md += "**Generated:** \(formatDate(Date()))\n\n"
        
        let totalCost = logs.reduce(0) { $0 + $1.totalSpent }
        let totalMessages = logs.reduce(0) { $0 + $1.messageCount }
        let totalTokens = logs.reduce(0) { $0 + $1.totalTokens }
        let totalSessions = logs.reduce(0) { $0 + $1.sessionCount }
        
        md += "## Summary\n\n"
        md += "- **Total Cost:** $\(String(format: "%.4f", totalCost))\n"
        md += "- **Messages:** \(totalMessages)\n"
        md += "- **Tokens:** \(totalTokens)\n"
        md += "- **Sessions:** \(totalSessions)\n\n"
        
        md += "## Daily Breakdown\n\n"
        md += "| Date | Cost | Messages | Tokens | Sessions |\n"
        md += "|------|------|----------|--------|----------|\n"
        
        for log in logs {
            md += "| \(formatDate(log.date)) | $\(String(format: "%.4f", log.totalSpent)) | \(log.messageCount) | \(log.totalTokens) | \(log.sessionCount) |\n"
        }
        
        if includeModelBreakdown {
            md += "\n## Model Usage\n\n"
            md += "| Model | Cost | Messages | Tokens |\n"
            md += "|-------|------|----------|--------|\n"
            
            var modelStats: [String: (cost: Double, messages: Int, tokens: Int)] = [:]
            for log in logs {
                for (modelId, cost) in log.modelBreakdown {
                    let existing = modelStats[modelId] ?? (0, 0, 0)
                    modelStats[modelId] = (
                        existing.cost + cost,
                        existing.messages + (log.modelMessages[modelId] ?? 0),
                        existing.tokens + (log.modelTokens[modelId] ?? 0)
                    )
                }
            }
            
            for (modelId, stats) in modelStats.sorted(by: { $0.value.cost > $1.value.cost }) {
                md += "| \(modelId) | $\(String(format: "%.4f", stats.cost)) | \(stats.messages) | \(stats.tokens) |\n"
            }
        }
        
        return md
    }
    
    private func generateJSON() -> String {
        var jsonData: [String: Any] = [
            "period": period,
            "generated": ISO8601DateFormatter().string(from: Date()),
            "summary": [
                "totalCost": logs.reduce(0.0) { $0 + $1.totalSpent },
                "totalMessages": logs.reduce(0) { $0 + $1.messageCount },
                "totalTokens": logs.reduce(0) { $0 + $1.totalTokens },
                "totalSessions": logs.reduce(0) { $0 + $1.sessionCount }
            ],
            "dailyLogs": logs.map { log in
                [
                    "date": formatDate(log.date),
                    "cost": log.totalSpent,
                    "messages": log.messageCount,
                    "tokens": log.totalTokens,
                    "sessions": log.sessionCount
                ]
            }
        ]
        
        if includeModelBreakdown {
            var modelStats: [String: [String: Any]] = [:]
            for log in logs {
                for (modelId, cost) in log.modelBreakdown {
                    if var existing = modelStats[modelId] {
                        existing["cost"] = (existing["cost"] as! Double) + cost
                        existing["messages"] = (existing["messages"] as! Int) + (log.modelMessages[modelId] ?? 0)
                        existing["tokens"] = (existing["tokens"] as! Int) + (log.modelTokens[modelId] ?? 0)
                        modelStats[modelId] = existing
                    } else {
                        modelStats[modelId] = [
                            "cost": cost,
                            "messages": log.modelMessages[modelId] ?? 0,
                            "tokens": log.modelTokens[modelId] ?? 0
                        ]
                    }
                }
            }
            jsonData["modelBreakdown"] = modelStats
        }
        
        if let jsonDataEncoded = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
           let jsonString = String(data: jsonDataEncoded, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    let format: ExportView.ExportFormat
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let filename: String
        switch format {
        case .csv:
            filename = "usage-export.csv"
        case .markdown:
            filename = "usage-export.md"
        case .json:
            filename = "usage-export.json"
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#Preview {
    UsageTrackerView()
        .modelContainer(for: DailyCostLog.self, inMemory: true)
}
