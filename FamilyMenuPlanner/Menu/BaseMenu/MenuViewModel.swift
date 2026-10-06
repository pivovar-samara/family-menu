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
    
    private var dishSelectionStartAt: Date?
    private var dishSelectionCompleted: Bool = false
    
    let weekdays: [String] = CalendarHelper.localizedWeekdayNamesStartingFromMonday()
    
    private let alertManager = AlertQueueManager()
    
    // UserDefaults key for storing selected week index
    static let selectedWeekIndexKey = "MenuSelectedWeekIndex"

    var weekOptions: [Date] {
        let today = now()
        return (0...2).map { CalendarHelper.startOfWeek(offset: $0, from: today, calendar: calendar) }
    }

    var selectedWeekDate: Date {
        (selectedWeekIndex >= 0 && selectedWeekIndex < weekOptions.count)
            ? weekOptions[selectedWeekIndex]
            : now()
    }

    private let menuService: MenuServiceProtocol
    private let calendar: Calendar
    private let now: () -> Date

    init(menuService: MenuServiceProtocol, calendar: Calendar = CalendarHelper.weekCalendar, now: @escaping () -> Date = Date.init) {
        self.menuService = menuService
        self.calendar = calendar
        self.now = now
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
            AnalyticsManager.shared.track(
                name: AnalyticsEventName.menu_generation_failed,
                properties: [AnalyticsPropertyKey.week_index: selectedWeekIndex,
                             AnalyticsPropertyKey.error_message: "invalid_week_index"]
            )
            enqueueAlert(title: "Error".localized(), message: "InvalidWeekSelectionMessage".localized())
            return
        }
        let selectedWeekDate = weekOptions[selectedWeekIndex]
        menuService.generateMenu(for: selectedWeekDate)
        loadMenu(for: selectedWeekIndex)
        AnalyticsManager.shared.track(
            name: AnalyticsEventName.menu_generation_completed,
            properties: [AnalyticsPropertyKey.week_index: selectedWeekIndex]
        )
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
            let dayIndex = self.weekdays.firstIndex(of: day) ?? -1
            AnalyticsManager.shared.trackError(error, domain: "Menu", category: "Error replacing dish", properties: [
                AnalyticsPropertyKey.week_index: self.selectedWeekIndex,
                AnalyticsPropertyKey.day_index: dayIndex,
                AnalyticsPropertyKey.meal_type: mealType,
                AnalyticsPropertyKey.count: newDishes.count])
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
            let dayIndex = self.weekdays.firstIndex(of: day) ?? -1
            AnalyticsManager.shared.trackError(error, domain: "Menu", category: (mealType == nil) ? "Error clearing mealType for day" : "Error clearing mealType", properties: [
                AnalyticsPropertyKey.week_index: self.selectedWeekIndex,
                AnalyticsPropertyKey.day_index: dayIndex,
                AnalyticsPropertyKey.meal_type: mealType ?? ""])
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
        let startOfToday = calendar.startOfDay(for: now())
        return date < startOfToday
    }
    
    private func dateFor(day: String) -> Date? {
        guard let dayIndex = weekdays.firstIndex(of: day) else { return nil }
        return CalendarHelper.date(forDayIndex: dayIndex, inWeekOf: selectedWeekDate, calendar: calendar)
    }

    // MARK: - Dish Selection Analytics
    func markDishSelectionOpened(currentCount: Int) {
        dishSelectionCompleted = false
        dishSelectionStartAt = Date()
        AnalyticsManager.shared.track(
            name: AnalyticsEventName.menu_dish_selection_opened,
            properties: [
                AnalyticsPropertyKey.week_index: selectedWeekIndex,
                AnalyticsPropertyKey.day_index: weekdays.firstIndex(of: selectedDay) ?? -1,
                AnalyticsPropertyKey.meal_type: selectedMealType,
                AnalyticsPropertyKey.current_count: currentCount
            ]
        )
    }

    func markDishSelectionCompleted(selectedCount: Int) {
        dishSelectionCompleted = true
        let duration = Int64((Date().timeIntervalSince(dishSelectionStartAt ?? Date())) * 1000)
        AnalyticsManager.shared.track(
            name: AnalyticsEventName.menu_dish_selection_done,
            properties: [
                AnalyticsPropertyKey.week_index: selectedWeekIndex,
                AnalyticsPropertyKey.day_index: weekdays.firstIndex(of: selectedDay) ?? -1,
                AnalyticsPropertyKey.meal_type: selectedMealType,
                AnalyticsPropertyKey.selected_count: selectedCount,
                AnalyticsPropertyKey.duration_ms: duration
            ]
        )
        dishSelectionStartAt = nil
    }

    func markDishSelectionCancelled(currentCount: Int) {
        guard dishSelectionCompleted == false else { return }
        let duration = Int64((Date().timeIntervalSince(dishSelectionStartAt ?? Date())) * 1000)
        AnalyticsManager.shared.track(
            name: AnalyticsEventName.menu_dish_selection_cancelled,
            properties: [
                AnalyticsPropertyKey.week_index: selectedWeekIndex,
                AnalyticsPropertyKey.day_index: weekdays.firstIndex(of: selectedDay) ?? -1,
                AnalyticsPropertyKey.meal_type: selectedMealType,
                AnalyticsPropertyKey.current_count: currentCount,
                AnalyticsPropertyKey.duration_ms: duration
            ]
        )
        dishSelectionStartAt = nil
    }
}

