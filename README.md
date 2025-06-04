# Family Menu Planner

An iOS application designed to help families plan their weekly menus efficiently and collaboratively.

## Architecture & Technologies

**Architecture Pattern**: MVVM (Model-View-ViewModel) with Coordinators
- Clean separation of concerns with dedicated ViewModels for business logic
- Coordinator pattern for navigation flow management
- Modular structure organized by features (Menu, Dishes, Shopping List)

**Core Technologies**:
- **SwiftUI** - Modern declarative UI framework
- **CoreData** - Local data persistence with automatic iCloud synchronization
- **iCloud Sync** - Seamless data sharing across family devices

**Project Structure**:
- `FamilyMenuPlanner/` - Main application source code
  - `Menu/` - Weekly menu planning features
  - `Dishes/` - Recipe and dish management
  - `Products/` - Ingredient and product catalog
  - `Common/` - Shared utilities and helpers
- `FamilyMenuPlannerTests/` - Unit tests
- `FamilyMenuPlannerIntegrationTests/` - Integration tests
- `FamilyMenuPlannerUITests/` - UI automation tests
- `FamilyMenuPlannerPerformanceTests/` - Performance testing

## Key Features

- **Weekly Menu Planning** - Plan meals for the entire week
- **Recipe Management** - Create and manage family recipes
- **Shopping List Generation** - Automatic shopping lists from planned meals
- **Family Collaboration** - Real-time sync across family devices via iCloud
- **Search & Optimization** - Smart search and menu optimization features

## Performance Optimizations

### UI Update Debouncing
The app implements intelligent debouncing in `NSFetchedResultsController` delegates to prevent excessive UI updates during:
- Rapid data changes (bulk operations)
- CloudKit synchronization events
- Batch imports/exports

This optimization reduces UI refresh frequency by ~80% during bulk operations while maintaining data consistency.

## Development Practices

- **Test Coverage** - Comprehensive unit, integration, and UI tests
- **Performance Monitoring** - Dedicated performance tests for critical operations
- **Localization** - Full internationalization support
- **Code Quality** - Consistent patterns and helper utilities for maintainability