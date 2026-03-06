//
//  DailyCostLog.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

@Model
final class DailyCostLog {
    @Attribute(.unique) var date: Date  // Start of day
    var totalSpent: Double = 0
    var messageCount: Int = 0
    var totalTokens: Int = 0
    var sessionCount: Int = 0
    var modelBreakdown: [String: Double] = [:]  // Model ID -> Cost
    var modelTokens: [String: Int] = [:]  // Model ID -> Total tokens
    var modelMessages: [String: Int] = [:]  // Model ID -> Message count

    init(date: Date, totalSpent: Double = 0, messageCount: Int = 0, totalTokens: Int = 0, sessionCount: Int = 0, modelBreakdown: [String: Double] = [:], modelTokens: [String: Int] = [:], modelMessages: [String: Int] = [:]) {
        self.date = Calendar.current.startOfDay(for: date)
        self.totalSpent = totalSpent
        self.messageCount = messageCount
        self.totalTokens = totalTokens
        self.sessionCount = sessionCount
        self.modelBreakdown = modelBreakdown
        self.modelTokens = modelTokens
        self.modelMessages = modelMessages
    }

    // Computed properties
    var formattedDate: String {
        date.formatted(.dateTime.day().month().year())
    }

    var averageCostPerMessage: Double {
        guard messageCount > 0 else { return 0 }
        return totalSpent / Double(messageCount)
    }

    // Methods
    func addCost(_ cost: Double, tokens: Int, forModel modelId: String) {
        totalSpent += cost
        messageCount += 1
        totalTokens += tokens
        
        // Track per-model stats
        modelBreakdown[modelId, default: 0] += cost
        modelTokens[modelId, default: 0] += tokens
        modelMessages[modelId, default: 0] += 1
    }
    
    // Get stats for a specific model
    func statsForModel(_ modelId: String) -> (cost: Double, tokens: Int, messages: Int) {
        return (
            cost: modelBreakdown[modelId] ?? 0,
            tokens: modelTokens[modelId] ?? 0,
            messages: modelMessages[modelId] ?? 0
        )
    }

    // Static helpers
    static func startOfDay(for date: Date = Date()) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func yesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: startOfDay())!
    }

    static func thisWeek() -> [Date] {
        let calendar = Calendar.current
        let today = startOfDay()
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday - calendar.firstWeekday
        let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!

        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }

    static func thisMonth() -> [Date] {
        let calendar = Calendar.current
        let today = startOfDay()
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)

        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        return (0..<daysInMonth).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: monthStart)
        }
    }
}