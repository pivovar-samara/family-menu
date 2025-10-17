import Foundation

/// A namespace for all analytics event names used throughout the app.
///
/// Usage:
/// ```swift
/// AnalyticsManager.shared.track(name: AnalyticsEventName.app_open)
/// ```
public enum AnalyticsEventName {
    // Common
    public static let screen_view = "screen_view"
    public static let search_happened = "search_happened"
    
    // Menu
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
    public static let menu_replace_dishes_failed = "menu_replace_dishes_failed"
    public static let menu_clear_meal_failed = "menu_clear_meal_failed"
    public static let menu_clear_day_failed = "menu_clear_day_failed"
    public static let menu_generation_completed = "menu_generation_completed"
    public static let menu_generation_failed = "menu_generation_failed"
    public static let menu_empty_state_shown = "menu_empty_state_shown"
    
    // Shopping List
    public static let shopping_list_item_selected = "shopping_list_item_selected"
    public static let shopping_list_item_deselected = "shopping_list_item_deselected"
    public static let shopping_list_all_selected = "shopping_list_all_selected"
    public static let shopping_list_all_deselected = "shopping_list_all_deselected"
    public static let shopping_list_sorting_changed = "shopping_list_sorting_changed"
    
    // Dish Selection
    public static let dish_selection_search = "dish_selection_search"
    public static let menu_dish_selection_opened = "menu_dish_selection_opened"
    public static let menu_dish_selection_cancelled = "menu_dish_selection_cancelled"
    public static let menu_dish_selection_done = "menu_dish_selection_done"
    
    // Dish List
    public static let dish_list_search = "dish_list_search"
    public static let dish_list_sorting_changed = "dish_list_sorting_changed"
    public static let dish_list_empty_state_shown = "dish_list_empty_state_shown"

    // Product List
    public static let product_list_search = "product_list_search"
    public static let product_list_sorting_changed = "product_list_sorting_changed"
    public static let product_list_empty_state_shown = "product_list_empty_state_shown"
    
    // Edit Product
    public static let edit_product_save_tap = "edit_product_save_tap"
    public static let edit_product_saved = "edit_product_saved"
    public static let edit_product_save_failed = "edit_product_save_failed"
    public static let edit_product_cancelled = "edit_product_cancelled"
    
    // Edit Dish
    public static let edit_dish_save_tap = "edit_dish_save_tap"
    public static let edit_dish_saved = "edit_dish_saved"
    public static let edit_dish_save_failed = "edit_dish_save_failed"
    public static let edit_dish_cancelled = "edit_dish_cancelled"
    public static let edit_dish_category_changed = "edit_dish_category_changed"
    public static let edit_dish_category_changing_failed = "edit_dish_category_changing_failed"
    public static let edit_dish_meal_type_toggled = "edit_dish_meal_type_toggled"
    public static let edit_dish_meal_type_toggle_failed = "edit_dish_meal_type_toggle_failed"
    public static let edit_dish_ingredients_added = "edit_dish_ingredients_added"
    public static let edit_dish_ingredients_removed = "edit_dish_ingredients_removed"
    public static let edit_dish_ingredients_quantity_changed = "edit_dish_ingredients_quantity_changed"
    public static let edit_dish_ingredients_sorting_changed = "edit_dish_ingredients_sorting_changed"
    public static let edit_dish_update_ingredient_quantity_failed = "edit_dish_update_ingredient_quantity_failed"
    public static let edit_dish_ingredients_adding_failed = "edit_dish_ingredients_adding_failed"
    public static let edit_dish_recreated = "edit_dish_recreated"
    public static let edit_dish_recreation_failed = "edit_dish_recreation_failed"
    public static let edit_dish_data_cleanup_failed = "edit_dish_data_cleanup_failed"
    public static let edit_dish_data_cleanup_finished = "edit_dish_data_cleanup_finished"
    
    // Product Selection
    public static let product_selection_search = "product_selection_search"
    public static let product_selection_opened = "product_selection_opened"
    public static let product_selection_cancelled = "product_selection_cancelled"
    public static let product_selection_done = "product_selection_done"
    public static let product_selection_new_product_added = "product_selection_new_product_added"
    public static let product_selection_new_product_tapped = "product_selection_new_product_tapped"
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
    public static let quantity = "quantity"
    public static let selected_count = "selected_count"
    public static let all_count = "all_count"
    public static let sort_type = "sort_type"
    public static let duration_ms = "duration_ms"
    public static let current_count = "current_count"
    public static let previous_week_index = "previous_week_index"
    public static let direction = "direction"
    public static let error_code = "error_code"
    public static let error_message = "error_message"
    public static let product_name = "product_name"
    public static let unit = "unit"
    public static let is_new_adding = "is_new_adding"
    public static let dish_name = "dish_name"
    public static let recipe_length = "recipe_length"
    public static let category = "category"
    public static let meal_types = "meal_types"
    public static let old_meal_types = "old_meal_types"
    public static let ingredients_count = "ingredients_count"
    public static let old_category = "old_category"
    public static let new_category = "new_category"
    public static let toggled_meal_type = "toggled_meal_type"
    public static let source = "source"
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
    public static let AddProduct = "Add New Product"
}
