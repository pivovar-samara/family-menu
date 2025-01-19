//
//  ShoppingListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    
    let shoppingList: [String: [String: Double]] // Dictionary where key is the product name and value is quantity with unit
    
    var body: some View {
        List {
            if shoppingList.isEmpty {
                Color.clear.emptyState(message: "No results found".localized())
            } else {
                ForEach(shoppingList.sorted(by: { $0.key < $1.key }), id: \.key) { product, details in
                    HStack {
                        Text(product)
                            .font(.headline)
                        Spacer()
                        Text(formattedDoubleForUnits(details.values.first ?? 0.0))
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Text((details.keys.first ?? "").localized())
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .listRowBackground(Color("SecondaryBackgroundColor"))
                }
            }
        }
        .navigationTitle("Shopping List")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
    }
}

