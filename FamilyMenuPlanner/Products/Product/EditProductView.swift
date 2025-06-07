//
//  EditProductView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct EditProductView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: EditProductViewModel

    init(viewModel: EditProductViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section(header: Text("Product Details")) {
                TextField("Product Name", text: Binding(
                    get: { viewModel.product.name ?? "" },
                    set: { viewModel.product.name = $0 }
                ))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                
                Picker("Unit", selection: $viewModel.selectedUnit) {
                    ForEach(viewModel.units, id: \.self) { unit in
                        Text((unit.name ?? "").localized()).tag(unit as Unit?)
                    }
                }
                .onChange(of: viewModel.selectedUnit) { newUnit in
                    viewModel.product.unit = newUnit
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
                    viewModel.saveChanges {
                        dismiss()
                    }
                }
                .foregroundColor(Color("AccentColor"))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.rollback()
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
        .onAppear {
            viewModel.setupSelectedUnit()
        }
        .alert(item: Binding(
            get: { viewModel.currentAlert },
            set: { _ in viewModel.dismissAlert() }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    alert.action?()
                }
            )
        }
    }
}
