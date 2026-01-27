//
//  ModelDetailView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

struct ModelDetailView: View {
    let model: AIModel
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    @State private var isFavorite = false

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(model.name)
                            .font(.title)
                            .fontWeight(.bold)

                        Spacer()

                        Button(action: toggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .gray)
                                .font(.title2)
                        }
                    }

                    Text(model.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)

                // Pricing Section
                if let pricing = model.pricing {
                    PricingSectionView(pricing: pricing)
                }

                // Technical Details
                TechnicalDetailsSectionView(model: model)

                // Capabilities
                if !model.supportedParameters.isEmpty {
                    CapabilitiesSectionView(parameters: model.supportedParameters)
                }

                // Architecture
                if let architecture = model.architecture {
                    ArchitectureSectionView(architecture: architecture)
                }

                // Provider Info
                if let provider = model.provider {
                    ProviderSectionView(provider: provider)
                }

                // Default Parameters
                if let parameters = model.parameters {
                    DefaultParametersSectionView(parameters: parameters)
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: startChat) {
                        Label("Start Chat", systemImage: "message")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: compareModels) {
                        Label("Compare Models", systemImage: "chart.bar")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateFavoriteStatus()
        }
    }

    private func toggleFavorite() {
        guard var prefs = userPreferences else {
            // Create new preferences if none exist
            let newPrefs = UserPreferences()
            modelContext.insert(newPrefs)
            newPrefs.toggleFavorite(model.id)
            isFavorite = true
            return
        }

        prefs.toggleFavorite(model.id)
        isFavorite = prefs.isFavoriteModel(model.id)
    }

    private func updateFavoriteStatus() {
        isFavorite = userPreferences?.isFavoriteModel(model.id) ?? false
    }

    private func startChat() {
        let newSession = ChatSession(title: "Chat with \(model.name)", model: model)
        modelContext.insert(newSession)

        // TODO: Navigate to the chat view
        // For now, this just creates the session
        print("Created new chat session with model: \(model.name)")
    }

    private func compareModels() {
        // TODO: Navigate to model comparison view
        print("Compare models including: \(model.name)")
    }
}

struct PricingSectionView: View {
    let pricing: ModelPricing

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pricing")
                .font(.headline)

            VStack(spacing: 12) {
                PricingRowView(
                    label: "Prompt",
                    price: pricing.prompt,
                    icon: "text.bubble"
                )

                PricingRowView(
                    label: "Completion",
                    price: pricing.completion,
                    icon: "arrow.right"
                )

                if let cachePrice = pricing.inputCacheRead, cachePrice > 0 {
                    PricingRowView(
                        label: "Cache Read",
                        price: cachePrice,
                        icon: "memorychip"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct PricingRowView: View {
    let label: String
    let price: Double
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(String(format: "$%.6f", price))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
}

struct TechnicalDetailsSectionView: View {
    let model: AIModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Technical Details")
                .font(.headline)

            VStack(spacing: 12) {
                DetailRowView(
                    label: "Context Length",
                    value: "\(model.contextLength.formatted()) tokens",
                    icon: "text.word.spacing"
                )

                if let provider = model.provider {
                    DetailRowView(
                        label: "Max Completion",
                        value: "\(provider.maxCompletionTokens.formatted()) tokens",
                        icon: "arrow.right"
                    )

                    DetailRowView(
                        label: "Moderated",
                        value: provider.isModerated ? "Yes" : "No",
                        icon: provider.isModerated ? "checkmark.shield" : "shield.slash"
                    )
                }

                if let created = model.created {
                    DetailRowView(
                        label: "Created",
                        value: created.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct DetailRowView: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct CapabilitiesSectionView: View {
    let parameters: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supported Parameters")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                ForEach(parameters, id: \.self) { parameter in
                    Text(parameter)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ArchitectureSectionView: View {
    let architecture: ModelArchitecture

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Architecture")
                .font(.headline)

            VStack(spacing: 12) {
                DetailRowView(
                    label: "Modality",
                    value: architecture.modality,
                    icon: "cpu"
                )

                DetailRowView(
                    label: "Tokenizer",
                    value: architecture.tokenizer,
                    icon: "textformat"
                )

                if let instructType = architecture.instructType {
                    DetailRowView(
                        label: "Instruction Type",
                        value: instructType,
                        icon: "command"
                    )
                }
            }

            if !architecture.inputModalities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input Modalities")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                        ForEach(architecture.inputModalities, id: \.self) { modality in
                            Text(modality)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            if !architecture.outputModalities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Modalities")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                        ForEach(architecture.outputModalities, id: \.self) { modality in
                            Text(modality)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ProviderSectionView: View {
    let provider: ModelProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Provider Settings")
                .font(.headline)

            VStack(spacing: 12) {
                DetailRowView(
                    label: "Context Length",
                    value: "\(provider.contextLength.formatted()) tokens",
                    icon: "text.word.spacing"
                )

                DetailRowView(
                    label: "Max Completion Tokens",
                    value: "\(provider.maxCompletionTokens.formatted()) tokens",
                    icon: "arrow.right"
                )

                DetailRowView(
                    label: "Content Moderation",
                    value: provider.isModerated ? "Enabled" : "Disabled",
                    icon: provider.isModerated ? "checkmark.shield.fill" : "shield.slash"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct DefaultParametersSectionView: View {
    let parameters: ModelParameters

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default Parameters")
                .font(.headline)

            VStack(spacing: 12) {
                if let temperature = parameters.temperature {
                    DetailRowView(
                        label: "Temperature",
                        value: String(format: "%.2f", temperature),
                        icon: "thermometer"
                    )
                }

                if let topP = parameters.topP {
                    DetailRowView(
                        label: "Top P",
                        value: String(format: "%.2f", topP),
                        icon: "percent"
                    )
                }

                if let frequencyPenalty = parameters.frequencyPenalty {
                    DetailRowView(
                        label: "Frequency Penalty",
                        value: String(format: "%.2f", frequencyPenalty),
                        icon: "waveform"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}