//
//  EditDishView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct EditDishView: View {
    
    class EditDishViewModel: ObservableObject {
        @Published var selectedIngredient: IngredientDetail?
        @Published var selectedIngredients: [IngredientDetail] = []
        @Published var isAddingIngredient: Bool = false
        @Published var dish: Dish?
        
        init(dish: Dish? = nil) {
            self.dish = dish
        }
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        entity: Product.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)]
    ) private var allProducts: FetchedResults<Product>

    @FetchRequest(
        entity: Unit.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]
    ) private var units: FetchedResults<Unit>
    
    @FetchRequest(
        entity: MealType.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
    ) private var allMealTypes: FetchedResults<MealType>

    @State private var descriptionText: String = ""
    @State private var selectedMealTypes: Set<MealType> = []
    @State private var validationError: String?
    @State private var showAlert: Bool = false
    @State private var currentAlert: Alert? = nil
    @State private var showProductSelection = false
    @StateObject private var viewModel = EditDishViewModel()
    
    init(dish: Dish? = nil) {
        _viewModel = StateObject(wrappedValue: EditDishViewModel(dish: dish))
    }
    
    var body: some View {
        Form {
            // Dish details
            Section(header: Text("Dish Details")) {
                TextField("Dish Name", text: Binding(
                    get: { viewModel.dish?.name ?? "" },
                    set: { viewModel.dish?.name = $0 }
                ))

                TextEditor(text: $descriptionText)
                    .frame(height: 100)
                    .onAppear {
                        descriptionText = viewModel.dish?.details ?? ""
                    }
                    .onChange(of: descriptionText) { newValue in
                        viewModel.dish?.details = newValue
                    }
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))
            
            // Meal type
            Section(header: Text("Meal Types")) {
                ForEach(allMealTypes, id: \.self) { mealType in
                    HStack {
                        Text((mealType.name ?? "").localized())
                        Spacer()
                        if selectedMealTypes.contains(mealType) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleMealTypeSelection(mealType)
                    }
                }
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))

            Section(header: Text("Ingredients")) {
                ForEach(viewModel.selectedIngredients, id: \.self) { detail in
                    HStack {
                        Button(action: {
                            viewModel.selectedIngredient = detail
                            viewModel.isAddingIngredient = false
                            showProductSelection = true
                        }) {
                            HStack {
                                Text(detail.product?.name ?? "Select a product")
                                    .foregroundColor(detail.product == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("Quantity", value: Binding(
                            get: { detail.quantity },
                            set: { detail.quantity = $0 }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        
                        Text((detail.product?.unit?.name ?? "").localized())
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)
                    }
                }
                .onMove(perform: moveIngredient)
                .onDelete(perform: deleteIngredient)

                Button("Add Ingredient") {
                    viewModel.selectedIngredient = nil
                    viewModel.isAddingIngredient = true
                    showProductSelection = true
                }
                .foregroundColor(Color("AccentColor"))
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))

            // Validation error
            if let error = validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .listRowBackground(Color("SecondaryBackgroundColor"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .sheet(isPresented: $showProductSelection) {
            NavigationStack {
                ProductSelectionView(currentProduct: viewModel.selectedIngredient?.product) { selectedProduct in
                    if viewModel.isAddingIngredient {
                        addIngredient(for: selectedProduct)
                    } else {
                        viewModel.selectedIngredient?.product = selectedProduct
                        
                        // WA to update UI
                        if let lastElement = viewModel.selectedIngredients.popLast(){
                            viewModel.selectedIngredients.append(lastElement)
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Dish")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if validate() {
                        saveChanges()
                    } else {
                        currentAlert = AlertHelper.presentAlert(
                            title: "Error",
                            message: validationError ?? ""
                        )
                        showAlert = true
                    }
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
                if viewModel.dish == nil {
                    viewModel.dish = Dish(context: viewContext)
                }
                loadIngredients()
                loadSelectedMealTypes()
            } catch {
                print("Failed to set query generation: \(error)")
            }
        }
        .alert(isPresented: $showAlert) {
            currentAlert!
        }
    }
    
    private func loadIngredients() {
        if let ingredientDetails = viewModel.dish?.ingredientDetails as? Set<IngredientDetail> {
            viewModel.selectedIngredients = Array(ingredientDetails).sorted { $0.sortOrder < $1.sortOrder }
        }
    }
    
    private func loadSelectedMealTypes() {
        if let mealTypes = viewModel.dish?.mealTypes as? Set<MealType> {
            selectedMealTypes = mealTypes
        }
    }

    private func addIngredient(for product: Product) {
        let newDetail = IngredientDetail(context: viewContext)
        newDetail.dish = viewModel.dish
        newDetail.product = product
        newDetail.quantity = 1.0
        newDetail.sortOrder = (viewModel.selectedIngredients.last?.sortOrder ?? 0) + 1

        viewModel.selectedIngredients.append(newDetail)
    }

    private func moveIngredient(from source: IndexSet, to destination: Int) {
        viewModel.selectedIngredients.move(fromOffsets: source, toOffset: destination)

        for (index, ingredient) in viewModel.selectedIngredients.enumerated() {
            ingredient.sortOrder = Int16(index)
        }
    }
    
    private func deleteIngredient(at offsets: IndexSet) {
        for index in offsets {
            let detail = viewModel.selectedIngredients[index]
            viewContext.delete(detail)
        }
        viewModel.selectedIngredients.remove(atOffsets: offsets)
    }
    
    private func toggleMealTypeSelection(_ mealType: MealType) {
        if selectedMealTypes.contains(mealType) {
            selectedMealTypes.remove(mealType)
            if let dish = viewModel.dish {
                mealType.removeFromDishes(dish)
            }
        } else {
            selectedMealTypes.insert(mealType)
            if let dish = viewModel.dish {
                mealType.addToDishes(dish)
            }
        }
    }

    private func saveChanges() {
        do {
            try viewContext.setQueryGenerationFrom(.current)
            try viewContext.save()
            loadIngredients()
            loadSelectedMealTypes()
            dismiss()
        } catch {
            currentAlert = AlertHelper.presentAlert(
                title: "Error",
                message: "Failed to save changes. Please try again."
            )
            showAlert = true
        }
    }

    // Validate dish data
    private func validate() -> Bool {
        // Clear previous errors
        validationError = nil

        // Validate name
        if viewModel.dish?.name?.isEmpty ?? true {
            validationError = "Dish name cannot be empty."
            return false
        }

        // Validate ingredients
        if viewModel.selectedIngredients.isEmpty {
            validationError = "Dish must have at least one ingredient."
            return false
        }
        
        // Validate meal type
        if selectedMealTypes.isEmpty {
            validationError = "Dish must have at least one meal type."
            return false
        }

        return true
    }
}
