//
//  ContentView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            ModelBrowserView()
                .tabItem {
                    Label("Models", systemImage: "list.bullet")
                }

            ChatListView()
                .tabItem {
                    Label("Chats", systemImage: "message")
                }

            UsageTrackerView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
