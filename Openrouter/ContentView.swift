//  ContentView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState   // Observe global state

    var body: some View {
        ZStack {
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

            // Loading overlay while models are being imported
            if appState.isImportingModels {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Importing models…")
                    .progressViewStyle(CircularProgressViewStyle())
                    .foregroundColor(.white)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8)))
            }
        }
        // Present any import error to the user
        .alert("Import Error", isPresented: Binding(
            get: { appState.importError != nil },
            set: { if !$0 { appState.importError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(appState.importError ?? "An unknown error occurred.")
        }
    }
}
