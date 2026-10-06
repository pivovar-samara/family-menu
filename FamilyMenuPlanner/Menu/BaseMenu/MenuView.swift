//
//  MenuView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI
import Foundation

struct MenuView: View {
    @StateObject private var viewModel: MenuViewModel

    init(viewModel: MenuViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            weekSegmentControl
            editingWeekBanner
            menuContent
            FeedbackFooterView()
        }
        .trackScreenAppear(name: AnalyticsScreenName.Menu)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Menu".localized())
        .onAppear {
            viewModel.removeOldWeeks()
            viewModel.loadMenu(for: viewModel.selectedWeekIndex)
        }
        .menuToolbar(viewModel: viewModel)
        .menuSheets(viewModel: viewModel)
        .menuAlerts(viewModel: viewModel)
    }
    
    private var weekSegmentControl: some View {
        HStack {
            Picker("Select Week", selection: Binding(
                get: { viewModel.selectedWeekIndex },
                set: { newValue in
                    let oldIndex = viewModel.selectedWeekIndex
                    viewModel.updateSelectedWeekIndex(newValue)
                    if viewModel.selectedWeekIndex != oldIndex {
                        viewModel.loadMenu(for: viewModel.selectedWeekIndex)
                        AnalyticsManager.shared.track(name: AnalyticsEventName.menu_week_switched, properties: [AnalyticsPropertyKey.week_index: newValue])
                    }
                }
            )) {
                ForEach(0..<viewModel.weekOptions.count, id: \.self) { index in
                    Text(CalendarHelper.formattedWeek(viewModel.weekOptions[index])).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: .infinity)
        }
        .centeredMaxWidth()
        .padding(.bottom, UIConstants.sectionSpacing)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var editingWeekBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .foregroundColor(Color.accent)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.editingWeekBannerTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(viewModel.todayBannerSubtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBorder, lineWidth: 1)
        )
        .centeredMaxWidth()
        .padding(.bottom, UIConstants.sectionSpacing)
        .accessibilityIdentifier("menu_editing_week_banner")
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var menuContent: some View {
        if viewModel.weeklyMenu.isEmpty {
            return AnyView(
                VStack(spacing: 0) {
                    EmptyMenuView()
                        .centeredMaxWidth()
                        .accessibilityIdentifier("menu_empty_state")
                        .onAppear {
                            AnalyticsManager.shared.track(
                                name: AnalyticsEventName.menu_empty_state_shown,
                                properties: [AnalyticsPropertyKey.week_index: viewModel.selectedWeekIndex]
                            )
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    // Spacer to keep content above the bottom
                    Color.clear
                        .frame(height: 20)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            )
        } else {
            return AnyView(
                VStack(spacing: 0) {
                    let columns = GridLayoutHelper.columns()
                    LazyVGrid(columns: columns, spacing: UIConstants.sectionSpacing) {
                        ForEach(Array(viewModel.weeklyMenu.enumerated()), id: \.element) { index, dailyMenu in
                            DailyMenuCardView(
                                dailyMenu: dailyMenu,
                                dayIndex: index,
                                weekDate: viewModel.selectedWeekDate,
                                weekdays: viewModel.weekdays,
                                onMealTap: { day, mealType, dishes in
                                    viewModel.prepareEditFor(day: day, mealType: mealType, dishes: dishes)
                                },
                                onClearMeal: { day, mealType in
                                    let dailyMeal = dailyMenu.dailyMeals.first { $0.meal == mealType }
                                    let dishesCount = dailyMeal?.dishes.count ?? 0
                                    viewModel.clearMealType(for: day, mealType: mealType)
                                    AnalyticsManager.shared.track(
                                        name: AnalyticsEventName.menu_daily_cleared,
                                        properties: [
                                            AnalyticsPropertyKey.day_index: index,
                                            AnalyticsPropertyKey.meal_type: mealType,
                                            AnalyticsPropertyKey.count: dishesCount
                                        ])
                                },
                                onClearDay: { day in
                                    viewModel.clearMealType(for: day)
                                    let breakfastCount = dailyMenu.dailyMeals.indices.contains(0) ? dailyMenu.dailyMeals[0].dishes.count : 0
                                    let lunchCount = dailyMenu.dailyMeals.indices.contains(1) ? dailyMenu.dailyMeals[1].dishes.count : 0
                                    let dinnerCount = dailyMenu.dailyMeals.indices.contains(2) ? dailyMenu.dailyMeals[2].dishes.count : 0
                                    AnalyticsManager.shared.track(name: AnalyticsEventName.menu_daily_cleared_all_day, properties: [AnalyticsPropertyKey.day_index: index, AnalyticsPropertyKey.dish_count_for_breakfast: breakfastCount, AnalyticsPropertyKey.dish_count_for_lunch: lunchCount, AnalyticsPropertyKey.dish_count_for_dinner: dinnerCount])
                                }
                            )
                            .frame(maxWidth: UIConstants.maxContentWidth)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier("menu_day_\(dailyMenu.day)")
                        }
                    }
                    .padding(.horizontal, UIConstants.horizontalPadding)

                    // Spacer to keep content above the bottom
                    Color.clear
                        .frame(height: 20)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.appBackground)
            )
        }
    }
}

struct MenuToolbarModifier: ViewModifier {
    @ObservedObject var viewModel: MenuViewModel

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ViewHelper.createToolbarButton(title: "Shopping List".localized(), systemImage: "cart") {
                    viewModel.isShowingShoppingList = true
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                ViewHelper.createToolbarButton(title: "Generate Menu".localized(), systemImage: "wand.and.stars") {
                    viewModel.showGenerateMenuAlert = true
                    AnalyticsManager.shared.track(name: AnalyticsEventName.menu_generation_dialog_shown, properties: [AnalyticsPropertyKey.week_index: viewModel.selectedWeekIndex])
                }
            }
        }
    }
}

extension View {
    func menuToolbar(viewModel: MenuViewModel) -> some View {
        self.modifier(MenuToolbarModifier(viewModel: viewModel))
    }
}

struct MenuSheetsModifier: ViewModifier {
    @ObservedObject var viewModel: MenuViewModel

    func body(content: Content) -> some View {
        content
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
            .sheet(isPresented: Binding(
                get: { !viewModel.selectedMealType.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        // Sheet dismissed, treat as cancel if not completed
                        viewModel.markDishSelectionCancelled(currentCount: viewModel.editingDishes.count)
                        viewModel.selectedMealType = ""
                    }
                }
            )) {
                NavigationStack {
                    DishSelectionCoordinator().createDishSelectionView(currentDishes: viewModel.editingDishes, mealType: viewModel.selectedMealType) { newDishes in
                        viewModel.replaceDishes(for: viewModel.selectedDay, mealType: viewModel.selectedMealType, with: newDishes)
                        AnalyticsManager.shared.track(name: AnalyticsEventName.menu_daily_dishes_added, properties: [AnalyticsPropertyKey.week_index: viewModel.selectedWeekIndex, AnalyticsPropertyKey.day_index: viewModel.weekdays.firstIndex(of: viewModel.selectedDay) ?? -1, AnalyticsPropertyKey.meal_type: viewModel.selectedMealType, AnalyticsPropertyKey.count: newDishes.count])
                        viewModel.markDishSelectionCompleted(selectedCount: newDishes.count)
                    }
                    .onAppear {
                        viewModel.markDishSelectionOpened(currentCount: viewModel.editingDishes.count)
                    }
                }
            }
    }
}

extension View {
    func menuSheets(viewModel: MenuViewModel) -> some View {
        self.modifier(MenuSheetsModifier(viewModel: viewModel))
    }
}

struct MenuAlertsModifier: ViewModifier {
    @ObservedObject var viewModel: MenuViewModel

    private var currentAlertBinding: Binding<AlertItem?> {
        Binding<AlertItem?>(
            get: { viewModel.currentAlert },
            set: { _ in viewModel.dismissAlert() }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(item: currentAlertBinding) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK".localized())) {
                        alert.action?()
                    }
                )
            }
            .alert("Warning".localized(), isPresented: $viewModel.showPastEditWarning) {
                Button("Cancel".localized(), role: .cancel) {
                    AnalyticsManager.shared.track(name: AnalyticsEventName.menu_past_edit_warning_cancelled, properties: [AnalyticsPropertyKey.week_index: viewModel.selectedWeekIndex, AnalyticsPropertyKey.day_index: viewModel.selectedDay])
                    viewModel.cancelPendingEdit()
                }
                Button("Continue".localized()) {
                    AnalyticsManager.shared.track(name: AnalyticsEventName.menu_past_edit_warning_confirmed, properties: [AnalyticsPropertyKey.week_index: viewModel.selectedWeekIndex, AnalyticsPropertyKey.day_index: viewModel.weekdays.firstIndex(of: viewModel.selectedDay) ?? -1])
                    viewModel.confirmPendingEdit()
                }
            } message: {
                Text("You are editing a past date.".localized())
                    .onAppear {
                        AnalyticsManager.shared.track(name: AnalyticsEventName.menu_past_edit_warning_shown, properties: [AnalyticsPropertyKey.week_index: viewModel.selectedWeekIndex, AnalyticsPropertyKey.day_index: viewModel.weekdays.firstIndex(of: viewModel.selectedDay) ?? -1])
                    }
            }
            .alert("Generate New Menu".localized(), isPresented: $viewModel.showGenerateMenuAlert) {
                Button("Cancel".localized(), role: .cancel) {
                    viewModel.showGenerateMenuAlert = false
                    AnalyticsManager.shared.track(name: AnalyticsEventName.menu_generation_dialog_cancelled, properties: [AnalyticsPropertyKey.week_index: viewModel.selectedWeekIndex])
                }
                Button("Generate".localized(), role: .destructive) {
                    viewModel.generateMenu()
                    AnalyticsManager.shared.track(name: AnalyticsEventName.menu_generation_dialog_confirmed, properties: [AnalyticsPropertyKey.week_index: viewModel.selectedWeekIndex])
                }
            } message: {
                Text("This will overwrite the current menu. Are you sure?".localized())
            }
    }
}

extension View {
    func menuAlerts(viewModel: MenuViewModel) -> some View {
        self.modifier(MenuAlertsModifier(viewModel: viewModel))
    }
}

extension MenuView {
    static let weekDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Daily Menu Card Component
struct DailyMenuCardView: View {
    let dailyMenu: DailyMenu
    let dayIndex: Int
    let weekDate: Date
    let weekdays: [String]
    let onMealTap: (String, String, [Dish]) -> Void
    let onClearMeal: (String, String) -> Void
    let onClearDay: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with day and date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Only show the date (without weekday name)
                    Text(formattedDate(for: dailyMenu.day))
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Today indicator
                if Calendar.current.isDateInToday(dateForDay(dailyMenu.day)) {
                    ChipView(
                        text: "Today".localized(),
                        icon: "circle.fill",
                        buttonStateStyle: .chip,
                        isSelected: true,
                        font: .caption.weight(.medium),
                        horizontalPadding: 12,
                        verticalPadding: 6,
                        cornerRadius: 12
                    )
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
        .appCardStyle(
            cornerRadius: UIConstants.cardCornerRadius,
            background: Color.appSecondaryBackground,
            shadowColor: .black.opacity(0.06),
            shadowRadius: UIConstants.cardShadowRadius,
            borderColor: Color.appBorder,
            borderWidth: UIConstants.cardBorderWidth,
            padding: UIConstants.cardPadding
        )
        .contextMenu {
            Button(role: .destructive) {
                onClearDay(dailyMenu.day)
            } label: {
                Label("Clear All Day".localized(), systemImage: "trash")
            }
            .onAppear {
                let breakfastCount = dailyMenu.dailyMeals.indices.contains(0) ? dailyMenu.dailyMeals[0].dishes.count : 0
                let lunchCount = dailyMenu.dailyMeals.indices.contains(1) ? dailyMenu.dailyMeals[1].dishes.count : 0
                let dinnerCount = dailyMenu.dailyMeals.indices.contains(2) ? dailyMenu.dailyMeals[2].dishes.count : 0
                AnalyticsManager.shared.track(name: AnalyticsEventName.menu_daily_clear_dialog_shown, properties: [AnalyticsPropertyKey.day_index: dayIndex, AnalyticsPropertyKey.dish_count_for_breakfast: breakfastCount, AnalyticsPropertyKey.dish_count_for_lunch: lunchCount, AnalyticsPropertyKey.dish_count_for_dinner: dinnerCount])
            }
            ForEach(dailyMenu.dailyMeals, id: \.self) { dailyMeal in
                if !dailyMeal.dishes.isEmpty {
                    Button(role: .destructive) {
                        onClearMeal(dailyMenu.day, dailyMeal.meal)
                    } label: {
                        Label(String(format: "Clear %@".localized(), dailyMeal.meal.localized()), systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private func formattedDate(for day: String) -> String {
        guard let index = weekdays.firstIndex(of: day) else {
            return ""
        }
        let date = CalendarHelper.date(forDayIndex: index, inWeekOf: weekDate)
        return DailyMenuCardView.dateFormatter.string(from: date)
    }
    
    private func dateForDay(_ day: String) -> Date {
        guard let index = weekdays.firstIndex(of: day) else {
            return Date()
        }
        return CalendarHelper.date(forDayIndex: index, inWeekOf: weekDate)
    }
}

extension DailyMenuCardView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        let locale = formatter.locale
        let template = "EEEE, d MMMM" // e.g., Monday, 15 September / понедельник, 15 сентября
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale)
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
            VStack(alignment: .leading, spacing: 8) {
                headerRow
                dishesContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.appBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(mealType.localized()))
        .accessibilityHint(Text(dishes.isEmpty ? "Choose a dish".localized() : String(format: "%d selected".localized(), dishes.count)))
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button(role: .destructive) {
                onClear()
            } label: {
                Label(String(format: "Clear %@".localized(), mealType.localized()), systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private var dishesContent: some View {
        if !dishes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(dishes, id: \.self) { dish in
                    Text("• \(dish.name ?? "Unnamed Dish".localized())")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 4)
        } else {
            Text("Choose a dish".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
                .padding(.top, 4)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: mealTypeIcon)
                .font(.title3)
                .foregroundColor(mealTypeColor)
                .frame(width: 24, height: 24)

            Text(mealType.localized())
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .allowsTightening(false)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

            Spacer()

            Image(systemName: "pencil")
                .font(.caption)
                .foregroundColor(Color.accent)
                .frame(width: 28, height: 28)
                .background(Color.accent.opacity(0.1))
                .cornerRadius(6)
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
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "No Menu Planned".localized(),
            description: "Generate a menu for this week to start planning your meals".localized()
        )
    }
}

struct ShoppingListIncorrectView: View {
    let onDismiss: (() -> Void)?
    
    var body: some View {
        List {
            ViewHelper.emptyState(Color.clear, message: "InvalidWeekSelectionMessage".localized())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("product_selection_no_results_state")
        }
        .scrollContentBackground(.hidden)
                .background(Color.appBackground)
        .navigationTitle("Shopping List".localized())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close".localized()) {
                    onDismiss?()
                }
                .foregroundColor(Color.accent)
            }
        }
    }
}

