# Family Menu Planner

An iOS application for families to plan their weekly menu, built with SwiftUI using MVVM with Coordinators architecture. Features Core Data with iCloud sync, robust background operation support, modern card-based UI, and comprehensive localization and testing.

## Features

- **Weekly Menu Planning**: Plan meals for each day of the week, organized by meal types (Breakfast, Lunch, Dinner)
- **Product Management**: Manage grocery products with units and categories in a modern card-based UI
- **Dish Management**: Create and manage dishes with ingredients, categories, and meal types
- **Shopping List**: Auto-generated, interactive shopping list with sorting, search, and persistent selection/quantity state
- **iCloud Sync**: Automatic synchronization across devices using CloudKit
- **Background Operations**: Heavy operations run in background contexts for smooth UI performance
- **Performance Optimization**: Optimized fetch requests, caching, and batch operations
- **Modern UI Design**: Consistent card-based interface, floating action buttons, and modern styling across all screens
- **Localization**: Full support for English and Russian, with all user-facing strings localized
- **Accessibility**: All interactive elements have accessibility identifiers and semantic labels

## Architecture

### MVVM with Coordinators
- **Views**: SwiftUI views for user interface, using card-based and modular components
- **ViewModels**: Handle business logic, state, and search/filtering (with `SearchOptimizationHelper`)
- **Coordinators**: Manage navigation and view creation
- **Services**: Handle data operations, business logic, and background execution

### Core Data & Persistence
- **Entities**: Product, Unit, Dish, DishCategory, MealType, Menu, IngredientDetail
- **iCloud Sync**: Uses `NSPersistentCloudKitContainer` for automatic sync
- **Background Contexts**: All heavy operations use background contexts via `BackgroundOperationManager`
- **Static Data Caching**: `StaticDataCacheManager` caches Units, MealTypes, and DishCategories for performance
- **Deduplication**: Automatic cleanup of duplicate static data from CloudKit sync conflicts
- **Robust Error Handling**: `PersistenceController` and `AppStateManager` provide categorized error handling and user-friendly recovery UI

### Background Operations
- **Centralized Management**: `BackgroundOperationManager` executes heavy, batch, and bulk operations in background contexts
- **Service Integration**: All major services (ProductList, DishList, EditProduct, DishDetails, Menu) use background operations for heavy tasks
- **Performance Thresholds**: Operations auto-select between synchronous and background execution based on data size
- **Batch Operations**: Batch fetching, saving, and deletion for performance

### UI/UX Design System
- **Modern Card-Based Interface**: All major lists and detail screens use card-based layouts (e.g., `ProductCardView`, `DishCardView`, `ShoppingListCardView`)
- **Floating Action Buttons**: Used for adding new products/dishes
- **Consistent Styling**: Uses `AccentColor`, `BackgroundColor`, `SecondaryBackgroundColor`, standard corner radii, and subtle shadows
- **Interactive Feedback**: All buttons use `ScaleButtonStyle` for tactile feedback
- **Accessibility**: Identifiers and semantic labels for all interactive elements
- **Localization**: All user-facing strings are localized (English, Russian)
- **Empty States**: Onboarding-style empty states for lists (e.g., `EmptyProductListView`, `EmptyMenuView`)
- **Sorting and Filtering**: Product, dish, and shopping list screens support sorting and search with persistent preferences

## Main Modules

- **Menu**: Plan weekly menus, generate shopping lists, clear meals, and manage weeks
- **Products**: Add, edit, delete, and sort products with unit selection
- **Dishes**: Create, edit, delete, and sort dishes with category and meal type assignment
- **Dish Selection**: Card-based selection UI for adding dishes to meals
- **Shopping List**: Interactive, persistent shopping list with search, sorting, and selection/quantity state
- **Debug Tools**: (Debug only) Data management and Core Data debug view

## Localization

- **Languages**: English, Russian
- **Coverage**: All user-facing strings, including error messages, onboarding, and UI labels
- **Dynamic Formatting**: Day names, meal types, and error messages are localized and formatted for context

## Testing

- **Unit Tests**: Cover all logic, ViewModels, and helpers (see `FamilyMenuPlannerUnitTests`)
- **Integration Tests**: Test service and ViewModel interactions with Core Data (see `FamilyMenuPlannerIntegrationTests`)
- **Performance Tests**: Measure Core Data, caching, and service performance (see `FamilyMenuPlannerPerformanceTests`)
- **UI Tests**: Automated UI flows for product, dish, menu, and shopping list management (see `FamilyMenuPlannerUITests`)
- **Test Data Factory**: Centralized creation of test data for all test types
- **CI Support**: Tests run in CI with in-memory or persistent stores as appropriate
- **Platform**: All tests run on iOS Simulator, iPhone 16 Pro, OS 18.5

## Development Guidelines

- **Follow MVVM + Coordinators**: All new features should use this pattern
- **Localize All User Strings**: Use `.localized()` for all user-facing text
- **Test Coverage**: All logic must be covered by unit/integration tests; update tests when changing logic
- **No Debug View Tests**: Do not cover debug-only views with tests
- **Consistent UI/UX**: Use card-based layouts, floating action buttons, and consistent color/typography
- **Accessibility**: Add identifiers and semantic labels for all new UI elements
- **Batch and Background Operations**: Use `BackgroundOperationManager` for heavy or bulk data tasks
- **Error Handling**: Use `PersistenceController` and `AppStateManager` for error propagation and user alerts

## Requirements

- iOS 16.0+
- Xcode 16.3+
- Swift 5.9+

## Building and Running

1. Clone the repository
2. Open `FamilyMenuPlanner.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run the project

## Testing

Run tests in Xcode:
- **Unit Tests**: `Cmd+U` to run all tests
- **Integration Tests**: Run `FamilyMenuPlannerIntegrationTests` scheme
- **Performance Tests**: Run `FamilyMenuPlannerPerformanceTests` scheme
- **UI Tests**: Run `FamilyMenuPlannerUITests` scheme

All tests are designed to run efficiently with proper context management and realistic performance characteristics.

## Error Handling & Recovery

- **Persistence Errors**: Comprehensive error categorization and user-friendly recovery UI
- **CloudKit Sync**: Automatic conflict resolution and duplicate data cleanup
- **Background Operations**: Graceful failure handling with user notifications
- **Data Validation**: Input validation with localized error messages
- **App State Management**: Centralized error handling through `AppStateManager` and `AlertQueueManager`

## Performance Features

- **Search Optimization**: `SearchOptimizationHelper` with debouncing and result caching
- **Static Data Caching**: `StaticDataCacheManager` for Units, MealTypes, and DishCategories
- **Batch Operations**: Optimized Core Data operations with configurable batch sizes
- **Background Processing**: Heavy operations moved to background contexts
- **Memory Management**: Proper faulting and context management for large datasets

## Environment Support

- **Production**: Full CloudKit sync with persistent storage
- **Simulator**: Configurable CloudKit support (disabled by default for performance)
- **Testing**: In-memory stores for unit/integration tests, persistent stores for UI tests
- **CI/CD**: Automated test execution with environment-specific configurations