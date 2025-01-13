//
//  MenuView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI
import CoreData

struct MenuView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: MealType.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
    ) private var mealTypes: FetchedResults<MealType>

    @FetchRequest(
        entity: Dish.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dish.name, ascending: true)]
    ) private var dishes: FetchedResults<Dish>

    @State private var weeklyMenu: [String: [String: [Dish]]] = [:]
    @State private var isShowingShoppingList: Bool = false // State for showing shopping list
    @State private var editingDish: Dish? = nil // Current dish being edited
    @State private var selectedDay: String = ""
    @State private var selectedMealType: String = ""
    @State private var selectedWeekIndex: Int = 0 // Index for week segment control
    @State private var showGenerateMenuAlert = false
    @State private var hasScrolledToToday = false

    @State private var showAlert: Bool = false
    @State private var currentAlert: Alert? = nil

    private let weekdays = localizedWeekdayNamesStartingFromMonday()
    private let weekOptions: [Date] = {
        let calendar = Calendar.current
        let today = Date()
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return (0...2).compactMap { calendar.date(byAdding: .weekOfYear, value: $0, to: startOfCurrentWeek) }
    }()

    var body: some View {
        List {
            weekSegmentControl
            
            ForEach(weekdays, id: \.self) { day in
                Section(header: Text(sectionHeader(for: day))) {
                    ForEach(mealTypes, id: \.self) { mealType in
                        if let dishesForMeal = weeklyMenu[day]?[mealType.name ?? ""] {
                            mealTypeSection(day: day, mealType: mealType.name ?? "", dishesForMeal: dishesForMeal)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                createToolbarButton(title: "Shopping List".localized(), systemImage: "cart") {
                    isShowingShoppingList = true
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                createToolbarButton(title: "Generate Menu".localized(), systemImage: "wand.and.stars") {
                    showGenerateMenuAlert = true
                }
            }
        }
        .sheet(isPresented: $isShowingShoppingList) {
            NavigationStack {
                ShoppingListView(shoppingList: generateShoppingList())
            }
        }
        .onAppear {
            removeOldWeeks()
            loadMenu()
        }
        .sheet(isPresented: Binding(
            get: { !selectedMealType.isEmpty },
            set: { if !$0 { selectedMealType = "" } }
        )) {
            NavigationStack {
                EditMenuDishView(currentDish: editingDish, mealType: selectedMealType) { newDish in
                    replaceDish(for: selectedDay, mealType: selectedMealType, with: newDish)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            currentAlert!
        }
        .alert("Generate New Menu", isPresented: $showGenerateMenuAlert) {
            Button("Cancel", role: .cancel) {
                showGenerateMenuAlert = false
            }
            Button("Generate", role: .destructive) {
                generateMenu()
            }
        } message: {
            Text("This will overwrite the current menu. Are you sure?")
        }
    }
    
    private var weekSegmentControl: some View {
        Picker("Select Week", selection: $selectedWeekIndex) {
            ForEach(0..<weekOptions.count, id: \.self) { index in
                Text(formattedWeek(weekOptions[index])).tag(index)
            }
        }
        .listRowBackground(Color("BackgroundColor"))
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedWeekIndex) { _ in loadMenu() }
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
            selectedDay = day
            if dishesForMeal.isEmpty {
                editingDish = nil
            } else if let currentDish = dishesForMeal.first {
                editingDish = currentDish
            }
            selectedMealType = mealType
        }
        .contextMenu {
            Button("Clear Dishes", role: .destructive) {
                clearMealType(for: day, mealType: mealType)
            }
            Button("Clear All Day", role: .destructive) {
                clearMealType(for: day)
            }
        }
    }
    
    private func sectionHeader(for day: String) -> String {
        let startDate = startOfWeek(for: weekOptions[selectedWeekIndex])
        guard let index = weekdays.firstIndex(of: day) else { return day }
        let date = Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        var resultArray: [String] = [day, formatter.string(from: date)]
        if Calendar.current.isDateInToday(date) {
            resultArray.append("Today".localized())
        }
        return resultArray.joined(separator: ", ")
    }
    
    private func removeOldWeeks() {
        let currentWeek = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        do {
            try viewContext.setQueryGenerationFrom(.current)
            let allMenuEntries = try viewContext.fetch(fetchRequest)
            for menu in allMenuEntries {
                if menu.calendarWeek < Int32(encodeWeek(currentWeek)) {
                    viewContext.delete(menu)
                }
            }
            try viewContext.save()
        } catch {
            print("Error removing old menu entries.")
        }
    }
    
    private func encodeWeek(_ weekComponents: DateComponents) -> Int {
        let year = weekComponents.yearForWeekOfYear ?? 0
        let week = weekComponents.weekOfYear ?? 0
        return year * 100 + week
    }

    private func generateMenu() {
        do {
            guard !dishes.isEmpty else {
                initiateAlert(message: "No dishes available to generate a menu.")
                return
            }

            let selectedWeekDate = weekOptions[selectedWeekIndex]
            let selectedWeekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
            let encodedWeek = encodeWeek(selectedWeekComponents)

            let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "calendarWeek == %d", encodedWeek)
            try viewContext.setQueryGenerationFrom(.current)
            let existingEntries = try viewContext.fetch(fetchRequest)
            for entry in existingEntries {
                viewContext.delete(entry)
            }

            for day in weekdays {
                for mealType in mealTypes {
                    let dishesForMealType = dishes.filter { dish in
                        guard let mealTypes = dish.mealTypes as? Set<MealType> else { return false }
                        return mealTypes.contains(mealType)
                    }

                    let newMenuEntry = Menu(context: viewContext)
                    newMenuEntry.day = day
                    newMenuEntry.mealType = mealType.name
                    newMenuEntry.calendarWeek = Int32(encodedWeek)

                    if let randomDish = dishesForMealType.randomElement() {
                        newMenuEntry.addToDishes(randomDish)
                    }
                }
            }

            try viewContext.save()
            loadMenu()
        } catch {
            initiateAlert(message: "Error generating menu. Please try again.")
        }
    }

    private func loadMenu() {
        let selectedWeekDate = weekOptions[selectedWeekIndex]
        let selectedWeekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
        let encodedWeek = encodeWeek(selectedWeekComponents)

        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "calendarWeek == %d", encodedWeek)

        do {
            try viewContext.setQueryGenerationFrom(.current)
            let menuEntries = try viewContext.fetch(fetchRequest)

            var initializedMenu: [String: [String: [Dish]]] = [:]
            for day in weekdays {
                initializedMenu[day] = [:]
                for mealType in mealTypes {
                    initializedMenu[day]?[mealType.name ?? ""] = []
                }
            }

            for entry in menuEntries {
                if let day = entry.day,
                   let mealType = entry.mealType,
                   let dishes = entry.dishes?.allObjects as? [Dish] {
                    initializedMenu[day]?[mealType] = dishes
                }
            }

            weeklyMenu = initializedMenu
        } catch {
            print("Error loading menu for the selected week.")
        }
    }

    private func replaceDish(for day: String, mealType: String, with newDish: Dish) {
        let selectedWeekDate = weekOptions[selectedWeekIndex]
        let selectedWeekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
        let encodedWeek = encodeWeek(selectedWeekComponents)

        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day == %@ AND mealType == %@ AND calendarWeek == %d", day, mealType, encodedWeek)
        do {
            try viewContext.setQueryGenerationFrom(.current)
            let results = try viewContext.fetch(fetchRequest)
            if let menuEntry = results.first {
                menuEntry.removeFromDishes(menuEntry.dishes ?? NSSet())
                menuEntry.addToDishes(newDish)
            } else {
                let newMenuEntry = Menu(context: viewContext)
                newMenuEntry.day = day
                newMenuEntry.mealType = mealType
                newMenuEntry.calendarWeek = Int32(encodedWeek)
                newMenuEntry.addToDishes(newDish)
            }
            try viewContext.save()
            loadMenu()
        } catch {
            initiateAlert(message: "Error replacing dish. Please try again.")
        }
    }

    private func clearMealType(for day: String, mealType: String? = nil) {
        let selectedWeekDate = weekOptions[selectedWeekIndex]
        let selectedWeekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
        let encodedWeek = encodeWeek(selectedWeekComponents)

        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        if let mealType = mealType {
            fetchRequest.predicate = NSPredicate(format: "day == %@ AND mealType == %@ AND calendarWeek == %d", day, mealType, encodedWeek)
        } else {
            fetchRequest.predicate = NSPredicate(format: "day == %@ AND calendarWeek == %d", day, encodedWeek)
        }
        
        do {
            try viewContext.setQueryGenerationFrom(.current)
            let results = try viewContext.fetch(fetchRequest)
            results.forEach { menuEntry in
                menuEntry.dishes = nil
            }
            try viewContext.save()
            loadMenu()
        } catch {
            initiateAlert(message: "Error clearing mealType. Please try again.")
        }
    }

    private func generateShoppingList() -> [String: [String: Double]] {
        var shoppingList: [String: [String: Double]] = [:]

        for day in weekdays {
            for mealType in mealTypes {
                if let dishesForMeal = weeklyMenu[day]?[mealType.name ?? ""] {
                    for dish in dishesForMeal {
                        if let ingredientDetails = dish.ingredientDetails as? Set<IngredientDetail> {
                            for detail in ingredientDetails {
                                let productName = detail.product?.name ?? "Unnamed Product"
                                let unitName = detail.product?.unit?.name ?? "unit"
                                shoppingList[productName, default: [:]][unitName, default: 0] += detail.quantity
                            }
                        }
                    }
                }
            }
        }

        return shoppingList
    }

    private func initiateAlert(message: LocalizedStringKey) {
        currentAlert = AlertHelper.presentAlert(
            title: "Error",
            message: message
        )
        showAlert = true
    }
}
