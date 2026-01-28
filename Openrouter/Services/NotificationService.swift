//
//  NotificationService.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/27/26.
//

import Foundation
import SwiftData
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                return true
            }
        } catch {
            print("Failed to request notification authorization: \(error)")
        }
        return false
    }

    func scheduleNewModelNotification(modelNames: [String]) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "New Models Available"
        
        if modelNames.count == 1 {
            content.body = "\(modelNames[0]) is now available!"
        } else {
            content.body = "\(modelNames.count) new models added: \(modelNames.prefix(3).joined(separator: ", "))\(modelNames.count > 3 ? "..." : "")"
        }
        
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func scheduleAppUpdatedNotification() {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Models Updated"
        content.body = "The model catalog has been updated. Check out what's new!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func clearBadge() {
        let center = UNUserNotificationCenter.current()
        center.setBadgeCount(0)
    }
}