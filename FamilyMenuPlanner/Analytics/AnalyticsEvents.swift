import Foundation

/// A namespace for all analytics event names used throughout the app.
///
/// Usage:
/// ```swift
/// AnalyticsManager.shared.track(name: AnalyticsEventName.app_open)
/// ```
public enum AnalyticsEventName {
    public static let app_open = "app_open"
    public static let app_background = "app_background"
    public static let screen_view = "screen_view"
    public static let onboarding_started = "onboarding_started"
    public static let onboarding_completed = "onboarding_completed"
    public static let auth_login_started = "auth_login_started"
    public static let auth_login_success = "auth_login_success"
    public static let auth_login_failed = "auth_login_failed"
    public static let auth_logout = "auth_logout"
    public static let search_performed = "search_performed"
    public static let search_result_tapped = "search_result_tapped"
    public static let recommendation_shown = "recommendation_shown"
    public static let recommendation_tapped = "recommendation_tapped"
    public static let dish_viewed = "dish_viewed"
    public static let dish_saved_to_favorites = "dish_saved_to_favorites"
    public static let dish_removed_from_favorites = "dish_removed_from_favorites"
    public static let dish_added_to_plan = "dish_added_to_plan"
    public static let dish_removed_from_plan = "dish_removed_from_plan"
    public static let dish_shared = "dish_shared"
    public static let meal_plan_viewed = "meal_plan_viewed"
    public static let meal_plan_generated = "meal_plan_generated"
    public static let meal_plan_cleared = "meal_plan_cleared"
    public static let shopping_list_viewed = "shopping_list_viewed"
    public static let shopping_item_added = "shopping_item_added"
    public static let shopping_item_checked = "shopping_item_checked"
    public static let shopping_item_removed = "shopping_item_removed"
    public static let paywall_shown = "paywall_shown"
    public static let paywall_cta_tapped = "paywall_cta_tapped"
    public static let purchase_started = "purchase_started"
    public static let purchase_success = "purchase_success"
    public static let purchase_failed = "purchase_failed"
    public static let experiment_exposed = "experiment_exposed"
    public static let feature_used = "feature_used"
    public static let error_occurred = "error_occurred"
    public static let network_request = "network_request"
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
    public static let source = "source"
    public static let dish_id = "dish_id"
    public static let dish_name = "dish_name"
    public static let date = "date"
    public static let meal_slot = "meal_slot"
    public static let query = "query"
    public static let filters = "filters"
    public static let results_count = "results_count"
    public static let duration_ms = "duration_ms"
    public static let placement = "placement"
    public static let variant = "variant"
    public static let product_id = "product_id"
    public static let price = "price"
    public static let currency = "currency"
    public static let transaction_id = "transaction_id"
    public static let provider = "provider"
    public static let error_code = "error_code"
    public static let error_domain = "error_domain"
    public static let error_message = "error_message"
    public static let experiment_id = "experiment_id"
    public static let feature_name = "feature_name"
    public static let week_start_date = "week_start_date"
    public static let count = "count"
    public static let algorithm = "algorithm"
    public static let position = "position"
    public static let is_favorite = "is_favorite"
    public static let success = "success"
    public static let status = "status"
    public static let app_version = "app_version"
    public static let build_number = "build_number"
    public static let os_version = "os_version"
    public static let event_version = "event_version"
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
