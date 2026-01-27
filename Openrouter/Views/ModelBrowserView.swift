//
//  ModelBrowserView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

struct ModelBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIModel.name) private var models: [AIModel]

    @State private var searchText = ""
    @State private var selectedProvider: String?
    @State private var maxPriceRange: ClosedRange<Double> = 0...1.0
    @State private var minContextLength: Int = 0
    @State private var showFilters = false

    // Filtered models based on search and filters
    private var filteredModels: [AIModel] {
        models.filter { model in
            // Search filter
            let matchesSearch = searchText.isEmpty ||
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.description.localizedCaseInsensitiveContains(searchText) ||
                model.id.localizedCaseInsensitiveContains(searchText)

            // Provider filter
            let matchesProvider = selectedProvider == nil ||
                model.id.hasPrefix(selectedProvider! + "/")

            // Price filter
            let promptPrice = model.pricing?.prompt ?? 0.0
            let matchesPrice = promptPrice >= maxPriceRange.lowerBound &&
                              promptPrice <= maxPriceRange.upperBound

            // Context length filter
            let matchesContext = model.contextLength >= minContextLength

            return matchesSearch && matchesProvider && matchesPrice && matchesContext
        }
    }

    // Available providers for filter
    private var availableProviders: [String] {
        let providers = models.compactMap { model -> String? in
            let components = model.id.split(separator: "/")
            return components.count > 1 ? String(components[0]) : nil
        }
        return Array(Set(providers)).sorted()
    }

    // Price range for filter
    private var priceRange: ClosedRange<Double> {
        let prices = models.compactMap { $0.pricing?.prompt }
        let min = prices.min() ?? 0.0
        let max = prices.max() ?? 1.0
        return min...max
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search models...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        Button(action: { showFilters.toggle() }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(showFilters ? .blue : .gray)
                        }
                    }
                    .padding(.horizontal)

                    if showFilters {
                        FilterView(
                            selectedProvider: $selectedProvider,
                            maxPriceRange: $maxPriceRange,
                            minContextLength: $minContextLength,
                            availableProviders: availableProviders,
                            priceRange: priceRange
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemBackground))

                // Model List
                List(filteredModels) { model in
                    NavigationLink(destination: ModelDetailView(model: model)) {
                        ModelRowView(model: model)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("AI Models")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ModelRowView: View {
    let model: AIModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let pricing = model.pricing {
                    Text(String(format: "$%.6f", pricing.prompt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            Text(model.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                if let contextLength = model.provider?.contextLength {
                    Label("\(contextLength)", systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let maxTokens = model.provider?.maxCompletionTokens {
                    Label("\(maxTokens)", systemImage: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let modality = model.architecture?.modality {
                    Text(modality)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct FilterView: View {
    @Binding var selectedProvider: String?
    @Binding var maxPriceRange: ClosedRange<Double>
    @Binding var minContextLength: Int

    let availableProviders: [String]
    let priceRange: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filters")
                .font(.headline)

            // Provider Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Provider")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("All") {
                            selectedProvider = nil
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(selectedProvider == nil ? .white : .primary)
                        .background(selectedProvider == nil ? Color.blue : Color.clear)
                        .cornerRadius(8)

                        ForEach(availableProviders, id: \.self) { provider in
                            Button(provider) {
                                selectedProvider = provider
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(selectedProvider == provider ? .white : .primary)
                            .background(selectedProvider == provider ? Color.blue : Color.clear)
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Price Range Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Max Price per Token: \(String(format: "$%.6f", maxPriceRange.upperBound))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { maxPriceRange.upperBound },
                        set: { newValue in
                            maxPriceRange = maxPriceRange.lowerBound...newValue
                        }
                    ),
                    in: priceRange
                )
            }

            // Context Length Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Min Context Length: \(minContextLength)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(minContextLength) },
                        set: { minContextLength = Int($0) }
                    ),
                    in: 0...131072,
                    step: 1024
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}