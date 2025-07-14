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
            menuContent
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .navigationTitle("Menu".localized())
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
            if viewModel.selectedWeekIndex >= 0 && viewModel.selectedWeekIndex < viewModel.weekOptions.count {
                NavigationStack {
                    ShoppingListView(
                        shoppingList: viewModel.generateShoppingList(),
                        weekDate: viewModel.weekOptions[viewModel.selectedWeekIndex]
                    )
                }
            } else {
                NavigationStack {
                    ShoppingListIncorrectView(onDismiss: {
                        viewModel.isShowingShoppingList = false
                    })
                }
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
                DishSelectionCoordinator().createDishSelectionView(currentDishes: viewModel.editingDishes, mealType: viewModel.selectedMealType) { newDishes in
                    viewModel.replaceDishes(for: viewModel.selectedDay, mealType: viewModel.selectedMealType, with: newDishes)
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
        VStack(spacing: 16) {
            Picker("Select Week", selection: $viewModel.selectedWeekIndex) {
                ForEach(0..<viewModel.weekOptions.count, id: \.self) { index in
                    Text(formattedWeek(viewModel.weekOptions[index])).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.selectedWeekIndex) { _ in 
                viewModel.loadMenu(for: viewModel.selectedWeekIndex) 
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color("SecondaryBackgroundColor"))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    private var menuContent: some View {
        Group {
            if viewModel.weeklyMenu.isEmpty {
                EmptyMenuView()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("menu_empty_state")
            } else {
                ForEach(viewModel.weeklyMenu, id: \.self) { dailyMenu in
                    DailyMenuCardView(
                        dailyMenu: dailyMenu,
                        weekDate: viewModel.selectedWeekIndex >= 0 && viewModel.selectedWeekIndex < viewModel.weekOptions.count ? viewModel.weekOptions[viewModel.selectedWeekIndex] : Date(),
                        weekdays: viewModel.weekdays,
                        onMealTap: { day, mealType, dishes in
                            viewModel.selectedDay = day
                            viewModel.editingDishes = dishes
                            viewModel.selectedMealType = mealType
                        },
                        onClearMeal: { day, mealType in
                            viewModel.clearMealType(for: day, mealType: mealType)
                        },
                        onClearDay: { day in
                            viewModel.clearMealType(for: day)
                        }
                    )
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("menu_day_\(dailyMenu.day)")
                }
            }
            
            // Spacer to keep content above the bottom
            Color.clear
                .frame(height: 20)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }
    
    private func formattedWeek(_ date: Date) -> String {
        let startOfWeek = startOfWeek(for: date)
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek
        return "\(MenuView.weekDateFormatter.string(from: startOfWeek)) - \(MenuView.weekDateFormatter.string(from: endOfWeek))"
    }
    
    private func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
    }
}

extension MenuView {
    static let weekDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// MARK: - Daily Menu Card Component
struct DailyMenuCardView: View {
    let dailyMenu: DailyMenu
    let weekDate: Date
    let weekdays: [String]
    let onMealTap: (String, String, [Dish]) -> Void
    let onClearMeal: (String, String) -> Void
    let onClearDay: (String) -> Void
    @State private var showDayContextMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with day and date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dailyMenu.day)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(formattedDate(for: dailyMenu.day))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Today indicator
                if Calendar.current.isDateInToday(dateForDay(dailyMenu.day)) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color("AccentColor"))
                            .frame(width: 8, height: 8)
                        Text("Today".localized())
                            .font(.caption.weight(.medium))
                            .foregroundColor(Color("AccentColor"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color("AccentColor").opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Meal types
            VStack(spacing: 12) {
                ForEach(dailyMenu.dailyMeals, id: \.self) { dailyMeal in
                    MealTypeRowView(
                        mealType: dailyMeal.meal,
                        dishes: dailyMeal.dishes,
                        onTap: {
                            onMealTap(dailyMenu.day, dailyMeal.meal, dailyMeal.dishes)
                        },
                        onClear: {
                            onClearMeal(dailyMenu.day, dailyMeal.meal)
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(Color("SecondaryBackgroundColor"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onClearDay(dailyMenu.day)
                }
            } label: {
                Label("Clear All Day".localized(), systemImage: "trash")
            }
            ForEach(dailyMenu.dailyMeals, id: \.self) { dailyMeal in
                if !dailyMeal.dishes.isEmpty {
                    Button(role: .destructive) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onClearMeal(dailyMenu.day, dailyMeal.meal)
                        }
                    } label: {
                        Label("Clear \(dailyMeal.meal.localized())", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private func formattedDate(for day: String) -> String {
        guard let index = weekdays.firstIndex(of: day) else {
            return ""
        }
        let startOfWeek = startOfWeek(for: weekDate)
        let date = Calendar.current.date(byAdding: .day, value: index, to: startOfWeek) ?? Date()
        return DailyMenuCardView.dateFormatter.string(from: date)
    }
    
    private func dateForDay(_ day: String) -> Date {
        guard let index = weekdays.firstIndex(of: day) else {
            return Date()
        }
        let startOfWeek = startOfWeek(for: weekDate)
        return Calendar.current.date(byAdding: .day, value: index, to: startOfWeek) ?? Date()
    }
    
    private func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
    }
}

extension DailyMenuCardView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

// MARK: - Meal Type Row Component
struct MealTypeRowView: View {
    let mealType: String
    let dishes: [Dish]
    let onTap: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Meal type icon and name
                HStack(spacing: 8) {
                    Image(systemName: mealTypeIcon)
                        .font(.title3)
                        .foregroundColor(mealTypeColor)
                        .frame(width: 24, height: 24)
                    
                    Text(mealType.localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Dishes or placeholder
                VStack(alignment: .trailing, spacing: 4) {
                    if !dishes.isEmpty {
                        ForEach(dishes, id: \.self) { dish in
                            Text(dish.name ?? "Unnamed Dish".localized())
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        Text("Choose a dish".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                // Edit icon
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(Color("AccentColor"))
                    .frame(width: 28, height: 28)
                    .background(Color("AccentColor").opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(16)
            .background(Color("BackgroundColor"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(mealType.localized()))
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button(role: .destructive) {
                onClear()
            } label: {
                Label("Clear \(mealType.localized())", systemImage: "trash")
            }
        }
    }
    
    private var mealTypeIcon: String {
        ViewHelper.mealTypeIcon(for: mealType)
    }
    
    private var mealTypeColor: Color {
        ViewHelper.mealTypeColor(for: mealType)
    }
}

// MARK: - Empty Menu View
struct EmptyMenuView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Illustration
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color("AccentColor").opacity(0.1), Color("AccentColor").opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(Color("AccentColor").opacity(0.6))
                )
            
            VStack(spacing: 12) {
                Text("No Menu Planned".localized())
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("Generate a menu for this week to start planning your meals".localized())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

struct ShoppingListIncorrectView: View {
    let onDismiss: (() -> Void)?
    
    var body: some View {
        List {
            Color.clear
                .emptyState(message: "InvalidWeekSelectionMessage".localized())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("product_selection_no_results_state")
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .navigationTitle("Shopping List".localized())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close".localized()) {
                    onDismiss?()
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
    }
}
