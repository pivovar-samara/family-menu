//
//  EditProductView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct EditProductView: View {
    @ObservedObject var product: Product
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        entity: Unit.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]
    ) private var units: FetchedResults<Unit>

    @State private var selectedUnit: Unit?
    @State private var showAlert: Bool = false
    @State private var currentAlert: Alert? = nil

    var body: some View {
        Form {
            Section(header: Text("Product Details")) {
                TextField("Product Name", text: Binding(
                    get: { product.name ?? "" },
                    set: { product.name = $0 }
                ))
                
                Picker("Unit", selection: $selectedUnit) {
                    ForEach(units, id: \.self) { unit in
                        Text((unit.name ?? "").localized()).tag(unit as Unit?)
                    }
                }
                .onChange(of: selectedUnit) { newUnit in
                    product.unit = newUnit
                }
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .navigationTitle("Edit Product")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
                .foregroundColor(Color("AccentColor"))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewContext.rollback()
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
        .onAppear {
            do {
                try viewContext.setQueryGenerationFrom(.current)
                selectedUnit = product.unit ?? units.first
            } catch {
                print("Failed to set query generation: \(error)")
            }
        }
        .alert(isPresented: $showAlert) {
            currentAlert!
        }
    }

    private func saveChanges() {
        do {
            try viewContext.save()
            dismiss()
        } catch {
            currentAlert = AlertHelper.presentAlert(
                title: "Error",
                message: "Failed to save changes. Please try again."
            )
            showAlert = true
        }
    }
}
