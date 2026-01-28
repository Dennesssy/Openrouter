//
//  ModelDetailView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

struct ModelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let model: AIModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(model.name)
                    .font(.largeTitle)
                    .bold()

                if !model.modelDescription.isEmpty {
                    Text(model.modelDescription)
                        .font(.body)
                }

                Divider()

                if let created = model.created {
                    HStack {
                        Text("Created:")
                            .bold()
                        Text(created.formatted(date: .abbreviated, time: .omitted))
                    }
                }

                HStack {
                    Text("Context Length:")
                        .bold()
                    Text("\(model.contextLength) tokens")
                }

                if let pricing = model.pricing {
                    Section("Pricing") {
                        HStack {
                            Text("Prompt:")
                            Text("$\(pricing.prompt, format: .number.precision(.fractionLength(6))) / token")
                        }

                        HStack {
                            Text("Completion:")
                            Text("$\(pricing.completion, format: .number.precision(.fractionLength(6))) / token")
                        }
                    }
                }

                if let provider = model.provider {
                    Section("Provider") {
                        HStack {
                            Text("Max Completion:")
                            Text("\(provider.maxCompletionTokens) tokens")
                        }

                        HStack {
                            Text("Moderated:")
                            Text(provider.isModerated ? "Yes" : "No")
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(model.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}