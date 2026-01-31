//
//  ModelSelectorView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct ModelSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIModel.name) private var models: [AIModel]
    @Query private var preferences: [UserPreferences]

    let onModelSelected: (AIModel) -> Void

    @State private var searchText = ""
    @State private var selectedProvider: String?
    @State private var sortBy: SortOption = .name

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case price = "Price"
        case context = "Context Length"
        case created = "Recently Added"
    }

    private var filteredAndSortedModels: [AIModel] {
        var filtered = models.filter { model in
            // Search filter
            let matchesSearch = searchText.isEmpty ||
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.modelDescription.localizedCaseInsensitiveContains(searchText) ||
                model.id.localizedCaseInsensitiveContains(searchText)

            // Provider filter
            let matchesProvider = selectedProvider == nil ||
                model.id.hasPrefix(selectedProvider! + "/")

            return matchesSearch && matchesProvider
        }

        // Sort models
        switch sortBy {
        case .name:
            filtered.sort { $0.name < $1.name }
        case .price:
            filtered.sort { ($0.pricing?.prompt ?? 1.0) < ($1.pricing?.prompt ?? 1.0) }
        case .context:
            filtered.sort { $0.contextLength > $1.contextLength }
        case .created:
            filtered.sort { ($0.created ?? Date.distantPast) > ($1.created ?? Date.distantPast) }
        }

        return filtered
    }

    private var availableProviders: [String] {
        let providers = models.compactMap { model -> String? in
            let components = model.id.split(separator: "/")
            return components.count > 1 ? String(components[0]) : nil
        }
        return Array(Set(providers)).sorted()
    }

    private var favoriteModels: [AIModel] {
        guard let prefs = preferences.first else { return [] }
        return models.filter { prefs.isFavoriteModel($0.id) }
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
                    }
                    .padding(.horizontal)

                    // Quick Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterButton(title: "All", isSelected: selectedProvider == nil) {
                                selectedProvider = nil
                            }

                            ForEach(availableProviders, id: \.self) { provider in
                                FilterButton(title: provider, isSelected: selectedProvider == provider) {
                                    selectedProvider = provider
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Sort Options
                    HStack {
                        Text("Sort by:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("", selection: $sortBy) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
#if os(iOS)
                .background(Color(.systemGray6))
#else
                .background(Color.gray.opacity(0.1))
#endif

                // Favorites Section (if any)
                if !favoriteModels.isEmpty && selectedProvider == nil && searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorites")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(favoriteModels) { model in
                                    FavoriteModelCard(model: model) {
                                        selectModel(model)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
#if os(iOS)
                    .background(Color(.systemGray6).opacity(0.5))
#else
                    .background(Color.gray.opacity(0.1))
#endif
                }

                // Models List
                List(filteredAndSortedModels) { model in
                    Button(action: { selectModel(model) }) {
                        ModelSelectorRowView(model: model)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Model")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
#endif
        }
    }

    private func selectModel(_ model: AIModel) {
        onModelSelected(model)
        dismiss()
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
#if os(iOS)
                .background(isSelected ? Color.blue : Color(.systemGray5))
#else
                .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
#endif
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct FavoriteModelCard: View {
    let model: AIModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                if let pricing = model.pricing {
                    Text(String(format: "$%.6f", pricing.prompt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let contextLength = model.provider?.contextLength {
                    Text("\(contextLength.formatted()) tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 160)
            .padding()
#if os(iOS)
            .background(Color(.systemBackground))
#else
            .background(Color.gray.opacity(0.1))
#endif
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ModelSelectorRowView: View {
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
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            Text(model.modelDescription)
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
#if os(iOS)
                        .background(Color(.systemGray5))
#else
                        .background(Color.gray.opacity(0.15))
#endif
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
