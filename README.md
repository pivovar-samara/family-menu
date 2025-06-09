# Family Menu Planner

An iOS application for families to plan their weekly menu, built with SwiftUI using MVVM architecture with coordinators pattern. Features CoreData with iCloud sync and comprehensive background operation support for optimal performance.

## Features

- **Weekly Menu Planning**: Plan meals for each day of the week with different meal types
- **Product Management**: Manage grocery products with units and categories
- **Dish Management**: Create and manage dishes with ingredients and meal types
- **iCloud Sync**: Automatic synchronization across devices
- **Background Operations**: Heavy operations run in background contexts for smooth UI performance
- **Performance Optimization**: Optimized fetch requests, caching, and batch operations

## Architecture

### MVVM with Coordinators
- **Views**: SwiftUI views for user interface
- **ViewModels**: Handle business logic and state management
- **Coordinators**: Manage navigation and view creation
- **Services**: Handle data operations and business logic

### Core Data
- **Entities**: Product, Unit, Dish, DishCategory, MealType, Menu, IngredientDetail
- **Background Context**: Heavy operations use background contexts to prevent UI blocking
- **iCloud Sync**: Automatic synchronization using NSPersistentCloudKitContainer
- **Performance**: Batch fetching, query optimization, and caching
- **Deduplication**: Automatic cleanup of duplicate data from CloudKit sync conflicts

### Background Operations

The app includes a comprehensive background operation system for handling heavy CoreData operations without blocking the UI:

#### BackgroundOperationManager
Central manager for executing heavy operations in background contexts:

```swift
// Execute heavy operation in background
BackgroundOperationManager.shared.executeHeavyOperation { backgroundContext in
    // Heavy operation code
    return result
} completion: { result in
    // Handle result on main queue
}

// Batch save operations
BackgroundOperationManager.shared.executeBatchSaveOperation(objectIDs: objectIDs) { backgroundObjects in
    // Modify objects in background
} completion: { result in
    // Handle completion
}

// Bulk operations (create, delete multiple items)
BackgroundOperationManager.shared.executeBulkOperation { backgroundContext in
    // Bulk operation code
} completion: { result in
    // Handle completion
}
```

#### Service Integration
Services automatically use background context for heavy operations:

- **ProductListService**: Background deletion for 4+ products, background creation for bulk operations
- **DishListService**: Background deletion for 4+ dishes, bulk creation and update operations
- **EditProductService**: Background saves for complex changes
- **DishDetailsService**: Background saves for dishes with many ingredients
- **PersistenceController**: Background initial data generation and bulk import/export

#### Performance Thresholds
Operations automatically choose between synchronous and background execution based on data size:

- **Small operations** (≤3 items): Synchronous execution for immediate feedback
- **Medium operations** (4-10 items): Background execution with completion callbacks
- **Large operations** (10+ items): Background execution with progress tracking

#### Static Data Caching
- **StaticDataCacheManager**: Caches frequently accessed static data (Units, MealTypes, DishCategories)
- **Automatic Invalidation**: Cache automatically updates when data changes
- **Performance Optimization**: Reduces database queries for commonly accessed data

## Testing

### Test Architecture
- **Unit Tests**: Test individual components and business logic
- **Integration Tests**: Test component interactions and data flow
- **Performance Tests**: Test background operations and caching performance

### Background Operation Testing
- **BackgroundOperationManagerTests**: Comprehensive tests for all background operation types
- **Service Integration Tests**: Test background operations in real service contexts
- **Performance Benchmarks**: Measure operation times and UI responsiveness

### Test Data Factory
- **TestDataFactory**: Centralized test data creation
- **Bulk Test Data**: Support for creating large datasets for performance testing
- **Background Test Operations**: Test background operations with realistic data volumes

## Performance Features

### Background Context Operations
- **Non-blocking UI**: Heavy operations never block the main thread
- **Automatic Context Management**: Background contexts are properly configured and cleaned up
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Memory Management**: Efficient memory usage with proper context lifecycle management

### Batch Operations
- **Batch Fetching**: Optimized fetch requests with appropriate batch sizes
- **Batch Saves**: Multiple related changes saved together for better performance
- **Batch Deletions**: Efficient deletion of multiple items using background contexts

### Caching Strategy
- **Static Data Caching**: Frequently accessed reference data cached in memory
- **Cache Invalidation**: Automatic cache updates when underlying data changes
- **Thread-Safe Caching**: Cache manager handles concurrent access safely

### CloudKit Deduplication
The app includes comprehensive deduplication logic to handle CloudKit sync conflicts that can create duplicate static data:

#### Automatic Cleanup
- **Startup Cleanup**: Automatic detection and removal of duplicate entities on app startup
- **Relationship Preservation**: Duplicate entities are merged while preserving all relationships
- **Background Processing**: Cleanup operations run in background to avoid UI blocking

#### Deduplication Strategy
- **Entity Detection**: Identifies duplicates based on entity name and key attributes
- **Smart Merging**: Keeps the entity with the lowest sortOrder or earliest creation
- **Relationship Migration**: Moves all relationships from duplicates to the kept entity
- **Safe Deletion**: Ensures referential integrity during cleanup process

#### Supported Entities
- **MealTypes**: Removes duplicate meal types (Breakfast, Lunch, Dinner)
- **Units**: Consolidates duplicate measurement units (kg, g, l, ml, pcs, etc.)
- **DishCategories**: Merges duplicate dish categories
- **Products**: Handles duplicate products considering name and unit combinations

#### Prevention Measures
- **Existence Checks**: New entity creation includes existence checks to prevent duplicates
- **Database State Validation**: Comprehensive database emptiness check before initial data seeding
- **CloudKit-Safe Seeding**: Initial data generation respects existing CloudKit synced data

This ensures users never see duplicate meal types or other static data, even when CloudKit sync creates conflicts during app installation or updates.

## Development Guidelines

### Adding Background Operations
When adding new heavy operations:

1. **Assess Operation Weight**: Determine if operation needs background execution
2. **Use BackgroundOperationManager**: Leverage existing background operation infrastructure
3. **Handle Callbacks**: Ensure proper completion handling on main queue
4. **Add Tests**: Include tests for both success and error scenarios

### Performance Considerations
- **Batch Size**: Use appropriate batch sizes based on data and UI requirements
- **Context Usage**: Use background contexts for operations that might block UI
- **Cache Strategy**: Cache frequently accessed data to reduce database queries
- **Memory Management**: Be mindful of memory usage in background operations

### Testing Background Operations
- **Async Testing**: Use XCTestExpectation for testing async operations
- **Error Scenarios**: Test both success and failure paths
- **Performance Testing**: Measure operation times to ensure performance goals
- **Integration Testing**: Test background operations in realistic scenarios

## Requirements

- iOS 15.0+
- Xcode 15.0+
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

The background operation system ensures all tests run efficiently with proper context management and realistic performance characteristics.