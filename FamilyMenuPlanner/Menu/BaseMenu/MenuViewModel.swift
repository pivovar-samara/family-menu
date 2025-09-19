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
    @Published var showPastEditWarning: Bool = false
    private var pendingDay: String = ""
    private var pendingMealType: String = ""
    private var pendingDishes: [Dish] = []
    
    let weekdays: [String] = CalendarHelper.localizedWeekdayNamesStartingFromMonday()
    
    private let alertManager = AlertQueueManager()
    
    // UserDefaults key for storing selected week index
    static let selectedWeekIndexKey = "MenuSelectedWeekIndex"

    var weekOptions: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return (0...2).compactMap { calendar.date(byAdding: .weekOfYear, value: $0, to: startOfCurrentWeek) }
    }

    var selectedWeekDate: Date {
        (selectedWeekIndex >= 0 && selectedWeekIndex < weekOptions.count)
            ? weekOptions[selectedWeekIndex]
            : Date()
    }

    private let menuService: MenuServiceProtocol

    init(menuService: MenuServiceProtocol) {
        self.menuService = menuService
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
        
        // Load persistent selected week index after all stored properties are initialized
        loadSelectedWeekIndex()

        // Refresh menu after CloudKit reconciliation completes
        NotificationCenter.default.addObserver(forName: .appDataDidReconcileAfterCloudKitImport, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.loadMenu(for: self.selectedWeekIndex)
        }
    }
    
    /// Loads the persistent selected week index from UserDefaults
    private func loadSelectedWeekIndex() {
        let savedWeekIndex = UserDefaults.standard.integer(forKey: Self.selectedWeekIndexKey)
        // Ensure the saved index is valid for current week options
        if savedWeekIndex >= 0 && savedWeekIndex < weekOptions.count {
            selectedWeekIndex = savedWeekIndex
        } else {
            selectedWeekIndex = 0 // Default to current week if saved index is invalid
        }
        AppLogger.info("Loaded menu selected week index: \(selectedWeekIndex)", category: AppLogger.viewModel)
    }
    
    /// Saves the current selected week index to UserDefaults
    private func saveSelectedWeekIndex() {
        UserDefaults.standard.set(selectedWeekIndex, forKey: Self.selectedWeekIndexKey)
        AppLogger.info("Saved menu selected week index: \(selectedWeekIndex)", category: AppLogger.viewModel)
    }

    // MARK: - Week Context Banner
    enum WeekPosition {
        case current
        case next
        case afterNext
    }

    var weekPosition: WeekPosition {
        switch selectedWeekIndex {
        case 0: return .current
        case 1: return .next
        default: return .afterNext
        }
    }

    /// Localized title for the banner describing which week is being edited
    var editingWeekBannerTitle: String {
        switch weekPosition {
        case .current:
            return "Editing current week".localized()
        case .next:
            return "Editing next week".localized()
        case .afterNext:
            return "Editing week after next".localized()
        }
    }

    /// Localized subtitle with today's date
    var todayBannerSubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        let template = "d MMMM" // e.g., 15 September / 15 сентября
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: .current)
        let dateString = formatter.string(from: Date())
        return String(format: "Today is %@".localized(), dateString)
    }

    func loadMenu(for weekIndex: Int) {
        weeklyMenu = menuService.fetchMenu(for: weekIndex)
    }
    
    func updateSelectedWeekIndex(_ newWeekIndex: Int) {
        // Validate the new index to ensure it is within the valid range
        guard newWeekIndex >= 0 && newWeekIndex < weekOptions.count else {
            AppLogger.error("Attempted to set an invalid week index: \(newWeekIndex)", category: AppLogger.viewModel)
            return
        }
        
        // Only update and save if the new index is different from the current index
        guard newWeekIndex != selectedWeekIndex else {
            AppLogger.info("Selected week index is already \(newWeekIndex). No update needed.", category: AppLogger.viewModel)
            return
        }
        
        selectedWeekIndex = newWeekIndex
        saveSelectedWeekIndex()
    }

    func generateMenu() {
        guard selectedWeekIndex >= 0 && selectedWeekIndex < weekOptions.count else {
            enqueueAlert(title: "Error".localized(), message: "InvalidWeekSelectionMessage".localized())
            return
        }
        let selectedWeekDate = weekOptions[selectedWeekIndex]
        menuService.generateMenu(for: selectedWeekDate)
        loadMenu(for: selectedWeekIndex)
    }

    func removeOldWeeks() {
        menuService.removeOldWeeks()
    }
    
    func replaceDishes(for day: String, mealType: String, with newDishes: [Dish]) {
        guard selectedWeekIndex >= 0 && selectedWeekIndex < weekOptions.count else {
            enqueueAlert(title: "Error".localized(), message: "InvalidWeekSelectionMessage".localized())
            return
        }
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
        guard selectedWeekIndex >= 0 && selectedWeekIndex < weekOptions.count else {
            enqueueAlert(title: "Error".localized(), message: "InvalidWeekSelectionMessage".localized())
            return
        }
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
            for dailyMeal in dailyMenu.dailyMeals {
                for dish in dailyMeal.dishes {
                    if let ingredientDetails = dish.ingredientDetails as? Set<IngredientDetail> {
                        for detail in ingredientDetails {
                            if let productName = detail.product?.name,
                               let unitName = detail.product?.unit?.name {
                                shoppingList[productName, default: [:]][unitName, default: 0] += detail.quantity
                            }
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

    // MARK: - Editing Notice
    // MARK: - Edit Preparation / Confirmation
    @MainActor
    func prepareEditFor(day: String, mealType: String, dishes: [Dish]) {
        if isDateInPast(day: day) {
            pendingDay = day
            pendingMealType = mealType
            pendingDishes = dishes
            showPastEditWarning = true
        } else {
            openEditor(day: day, mealType: mealType, dishes: dishes)
        }
    }

    @MainActor
    func confirmPendingEdit() {
        openEditor(day: pendingDay, mealType: pendingMealType, dishes: pendingDishes)
        clearPendingEdit()
    }

    @MainActor
    func cancelPendingEdit() {
        clearPendingEdit()
    }

    @MainActor
    private func openEditor(day: String, mealType: String, dishes: [Dish]) {
        selectedDay = day
        editingDishes = dishes
        selectedMealType = mealType
    }

    private func clearPendingEdit() {
        showPastEditWarning = false
        pendingDay = ""
        pendingMealType = ""
        pendingDishes = []
    }
    
    private func isDateInPast(day: String) -> Bool {
        guard let date = dateFor(day: day) else { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return date < startOfToday
    }
    
    private func dateFor(day: String) -> Date? {
        guard let dayIndex = weekdays.firstIndex(of: day) else { return nil }
        let calendar = Calendar.current
        let startOfWeek = CalendarHelper.startOfWeek(for: selectedWeekDate, calendar: calendar)
        return calendar.date(byAdding: .day, value: dayIndex, to: startOfWeek)
    }
}

