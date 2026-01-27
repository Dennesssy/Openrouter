//  Item.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//
//  NOTE: This model is no longer used in the application. It has been
//  retained temporarily only to allow a clean removal via a migration.
//  Once the migration is complete, delete this file from the project.

import Foundation
import SwiftData

@available(*, deprecated, message: "Item model is obsolete and should be removed.")
@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
