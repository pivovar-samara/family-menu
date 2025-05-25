//
//  MenuViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 14.01.25.
//

import Foundation
import SwiftUI

struct DailyMenu: Hashable {
    let day: String
    let dailyMeals: [DailyMeal]
}

struct DailyMeal: Hashable {
    let meal: String
    let dishes: [Dish]
}

class MenuViewModel: ObservableObject {
    @Published var weeklyMenu: [DailyMenu] = []
    @Published var isShowingShoppingList: Bool = false
    @Published var showGenerateMenuAlert = false
    @Published var dishes: [Dish] = []
    @Published var editingDishes: [Dish] = []
    @Published var selectedDay: String = ""
    @Published var selectedMealType: String = ""
    @Published var selectedWeekIndex: Int = 0
    @Published var hasScrolledToToday: Bool = false
    @Published var currentAlert: AlertItem?
    
    let weekdays: [String] = localizedWeekdayNamesStartingFromMonday()
    
    private let alertManager = AlertQueueManager()

    var weekOptions: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return (0...2).compactMap { calendar.date(byAdding: .weekOfYear, value: $0, to: startOfCurrentWeek) }
    }

    private let menuService: MenuService

    init(menuService: MenuService) {
        self.menuService = menuService
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
    }

    func loadMenu(for weekIndex: Int) {
        weeklyMenu = menuService.fetchMenu(for: weekIndex)
    }

    func generateMenu() {
        let selectedWeekDate = weekOptions[selectedWeekIndex]
        menuService.generateMenu(for: selectedWeekDate)
        loadMenu(for: selectedWeekIndex)
    }

    func removeOldWeeks() {
        menuService.removeOldWeeks()
    }
    
    func replaceDishes(for day: String, mealType: String, with newDishes: [Dish]) {
        let selectedWeekDate = weekOptions[selectedWeekIndex]
        
        do {
            try menuService.replaceDishes(for: day, mealType: mealType, selectedWeekDate: selectedWeekDate, with: newDishes)
            loadMenu(for: selectedWeekIndex)
        } catch {
            DispatchQueue.main.asyncAfter(deadline: .now()+0.3) {
                self.enqueueAlert(title: "Error", message: "Error replacing dish. Please try again.")
            }
        }
    }

    func clearMealType(for day: String, mealType: String? = nil) {
        let selectedWeekDate = weekOptions[selectedWeekIndex]
        do {
            try menuService.clearMealType(for: day, selectedWeekDate: selectedWeekDate, mealType: mealType)
            loadMenu(for: selectedWeekIndex)
        } catch {
            DispatchQueue.main.asyncAfter(deadline: .now()+0.3) {
                self.enqueueAlert(title: "Error", message: "Error clearing mealType. Please try again.")
            }
        }
    }

    func generateShoppingList() -> [String: [String: Double]] {
        var shoppingList: [String: [String: Double]] = [:]
        
        for dailyMenu in weeklyMenu {
            for dailyMeals in dailyMenu.dailyMeals {
                for dish in dailyMeals.dishes {
                    if let ingredientDetails = dish.ingredientDetails as? Set<IngredientDetail> {
                        for detail in ingredientDetails {
                            let productName = detail.product?.name ?? "Unnamed Product".localized()
                            let unitName = detail.product?.unit?.name ?? "Unit".localized()
                            shoppingList[productName, default: [:]][unitName, default: 0] += detail.quantity
                        }
                    }
                }
            }
        }

        return shoppingList
    }

    func enqueueAlert(title: String, message: String, action: (() -> Void)? = nil) {
        let alert = AlertItem(title: title.localized(), message: message.localized(), action: action)
        alertManager.enqueue(alert: alert)
    }
    
    func dismissAlert() {
        alertManager.dismissCurrentAlert()
    }
}

