import Foundation

/// A namespace for all analytics event names used throughout the app.
///
/// Usage:
/// ```swift
/// AnalyticsManager.shared.track(name: AnalyticsEventName.app_open)
/// ```
public enum AnalyticsEventName {
    public static let screen_view = "screen_view"
    public static let search_happened = "search_happened"
    public static let menu_week_switched = "menu_week_switched"
    public static let menu_daily_clear_dialog_shown = "menu_daily_clear_dialog_shown"
    public static let menu_daily_cleared = "menu_daily_cleared"
    public static let menu_daily_cleared_all_day = "menu_daily_cleared_all_day"
    public static let menu_generation_dialog_shown = "menu_generation_dialog_shown"
    public static let menu_generation_dialog_confirmed = "menu_generation_dialog_confirmed"
    public static let menu_generation_dialog_cancelled = "menu_generation_dialog_cancelled"
    public static let menu_daily_dishes_added = "menu_daily_dishes_added"
    public static let menu_past_edit_warning_shown = "menu_past_edit_warning_shown"
    public static let menu_past_edit_warning_confirmed = "menu_past_edit_warning_confirmed"
    public static let menu_past_edit_warning_cancelled = "menu_past_edit_warning_cancelled"
    public static let shopping_list_item_selected = "shopping_list_item_selected"
    public static let shopping_list_item_deselected = "shopping_list_item_deselected"
    public static let shopping_list_all_selected = "shopping_list_all_selected"
    public static let shopping_list_all_deselected = "shopping_list_all_deselected"
    public static let shopping_list_sorting_changed = "shopping_list_sorting_changed"
    public static let dish_selection_search = "dish_selection_search"
    public static let menu_dish_selection_opened = "menu_dish_selection_opened"
    public static let menu_dish_selection_cancelled = "menu_dish_selection_cancelled"
    public static let menu_dish_selection_done = "menu_dish_selection_done"
    public static let menu_replace_dishes_failed = "menu_replace_dishes_failed"
    public static let menu_clear_meal_failed = "menu_clear_meal_failed"
    public static let menu_clear_day_failed = "menu_clear_day_failed"
    public static let menu_generation_completed = "menu_generation_completed"
    public static let menu_generation_failed = "menu_generation_failed"
    public static let menu_empty_state_shown = "menu_empty_state_shown"
}

/// A namespace for commonly reused analytics property keys.
///
/// Usage:
/// ```swift
/// AnalyticsManager.shared.track(
///     name: AnalyticsEventName.dish_viewed,
///     properties: [AnalyticsPropertyKey.dish_id: "12345", AnalyticsPropertyKey.dish_name: "Avocado Toast"]
/// )
/// ```
public enum AnalyticsPropertyKey {
    public static let screen_name = "screen_name"
    public static let week_index = "week_index"
    public static let day_index = "day_index"
    public static let dish_count_for_breakfast = "dish_count_for_breakfast"
    public static let dish_count_for_lunch = "dish_count_for_lunch"
    public static let dish_count_for_dinner = "dish_count_for_dinner"
    public static let meal_type = "meal_type"
    public static let count = "count"
    public static let query = "query"
    public static let results = "results"
    public static let selected_count = "selected_count"
    public static let all_count = "all_count"
    public static let sort_type = "sort_type"
    public static let duration_ms = "duration_ms"
    public static let current_count = "current_count"
    public static let previous_week_index = "previous_week_index"
    public static let direction = "direction"
    public static let error_code = "error_code"
    public static let error_message = "error_message"
}

/// A namespace for common screen names used across the app.
///
/// Usage:
/// ```swift
/// AnalyticsManager.shared.trackScreen(name: AnalyticsScreenName.Home)
/// ```
public enum AnalyticsScreenName {
    /// Menu
    public static let Menu = "Menu"
    /// Dish Selection
    public static let DishSelection = "Menu - Dish Selection"
    /// Shopping List screen
    public static let ShoppingList = "Menu - Shopping List"
    
    /// Dish List
    public static let DishList = "Dish List"
    /// Dish Details
    public static let DishDetailsBasicInfo = "Dish Details - Basic Info"
    public static let DishDetailsIngredients = "Dish Details - Ingredients"
    public static let DishDetailsMealTypes = "Dish Details - Meal Types"
    public static let DishDetailsReview = "Dish Details - Review"
    public static let ProductSelection = "Dish Details - Product Selection"
    
    /// Product List
    public static let ProductList = "Product List"
    /// Edit Product screen
    public static let EditProduct = "Edit Product"
}
