//
//  MenuView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI

struct MenuView: View {
    @StateObject private var viewModel: MenuViewModel

    init(viewModel: MenuViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            weekSegmentControl
            menuList
        }
        .applyStyle()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                createToolbarButton(title: "Shopping List".localized(), systemImage: "cart") {
                    viewModel.isShowingShoppingList = true
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                createToolbarButton(title: "Generate Menu".localized(), systemImage: "wand.and.stars") {
                    viewModel.showGenerateMenuAlert = true
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingShoppingList) {
            NavigationStack {
                ShoppingListView(shoppingList: viewModel.generateShoppingList())
            }
        }
        .onAppear {
            viewModel.removeOldWeeks()
            viewModel.loadMenu(for: 0)
        }
        .sheet(isPresented: Binding(
            get: { !viewModel.selectedMealType.isEmpty },
            set: { if !$0 { viewModel.selectedMealType = "" } }
        )) {
            NavigationStack {
                DishSelectionCoordinator().createDishSelectionView(currentDish: viewModel.editingDish, mealType: viewModel.selectedMealType) { newDish in
                    viewModel.replaceDish(for: viewModel.selectedDay, mealType: viewModel.selectedMealType, with: newDish)
                }
            }
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
        .alert("Generate New Menu", isPresented: $viewModel.showGenerateMenuAlert) {
            Button("Cancel", role: .cancel) {
                viewModel.showGenerateMenuAlert = false
            }
            Button("Generate", role: .destructive) {
                viewModel.generateMenu()
            }
        } message: {
            Text("This will overwrite the current menu. Are you sure?")
        }
    }
    
    private var weekSegmentControl: some View {
        Picker("Select Week", selection: $viewModel.selectedWeekIndex) {
            ForEach(0..<viewModel.weekOptions.count, id: \.self) { index in
                Text(formattedWeek(viewModel.weekOptions[index])).tag(index)
            }
        }
        .listRowBackground(Color("BackgroundColor"))
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: viewModel.selectedWeekIndex) { _ in viewModel.loadMenu(for: viewModel.selectedWeekIndex) }
    }
    
    private var menuList: some View {
        ForEach(viewModel.weeklyMenu.keys.sorted(), id: \.self) { day in
            Section(header: Text(sectionHeader(for: day))) {
                if let meals = viewModel.weeklyMenu[day] {
                    ForEach(meals.keys.sorted(), id: \.self) { mealType in
                        mealTypeSection(day: day, mealType: mealType, dishesForMeal: meals[mealType] ?? [])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mealTypeSection(day: String, mealType: String, dishesForMeal: [Dish]) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(mealType.localized())
                    .font(.headline)
                    .padding(.bottom, 4)

                if !dishesForMeal.isEmpty {
                    ForEach(dishesForMeal, id: \.self) { dish in
                        Text((dish.name ?? "Unnamed Dish").localized())
                            .font(.subheadline)
                    }
                } else {
                    Text("Choose a dish")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            Spacer()
            Image(systemName: "pencil")
                .foregroundColor(Color("AccentColor"))
        }
        .listRowBackground(Color("SecondaryBackgroundColor"))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedDay = day
            if dishesForMeal.isEmpty {
                viewModel.editingDish = nil
            } else if let currentDish = dishesForMeal.first {
                viewModel.editingDish = currentDish
            }
            viewModel.selectedMealType = mealType
        }
        .contextMenu {
            Button("Clear Dishes", role: .destructive) {
                viewModel.clearMealType(for: day, mealType: mealType)
            }
            Button("Clear All Day", role: .destructive) {
                viewModel.clearMealType(for: day)
            }
        }
    }
    
    private func sectionHeader(for day: String) -> String {
        let startDate = startOfWeek(for: viewModel.weekOptions[viewModel.selectedWeekIndex])
        guard let index = viewModel.weekdays.firstIndex(of: day) else { return day }
        let date = Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        var resultArray: [String] = [day, formatter.string(from: date)]
        if Calendar.current.isDateInToday(date) {
            resultArray.append("Today".localized())
        }
        return resultArray.joined(separator: ", ")
    }

}
