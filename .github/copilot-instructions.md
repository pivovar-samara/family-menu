# Family Menu Planner - Copilot Instructions

## Repository Overview

**Purpose**: iOS SwiftUI application for families to plan weekly menus, manage dishes, products, and shopping lists with iCloud sync.

**Scale**: ~102 Swift files (52 main app + 50 test files), 3.9MB total size, mature codebase with comprehensive testing infrastructure.

**Languages & Technologies**: Swift 5.9+, SwiftUI, Core Data with CloudKit, iOS 17.0+ target, localized (English/Russian).

**Architecture**: MVVM with Coordinators pattern, background operations for performance, card-based modern UI design.

## Critical Build & Environment Setup

### Prerequisites
- **macOS Environment** (Xcode is macOS-only)
- **Xcode 16.3+** (Required, earlier versions fail)
- **iOS 17.0+ Simulator** (iPhone 17 recommended for CI compatibility)
- **Swift 5.9+**

**Note**: This is an iOS project that requires Xcode and macOS for building and testing. Linux/Windows environments cannot build or run the project.

### Environment Detection
The app automatically detects test/CI environments and disables CloudKit accordingly:
- CI environments: `GITHUB_ACTIONS`, `CI`, `BUILD_NUMBER`, `XCTestConfigurationFilePath`
- UI test environments: `UI_TESTS`, `-UITests`, `-DisableCloudKit` arguments

### Build Commands (macOS/Xcode Required)

**Important**: These commands only work in macOS environments with Xcode installed. CI runs on Xcode Cloud.

**Clean Build**:
```bash
xcodebuild -scheme FamilyMenuPlanner -destination "platform=iOS Simulator,name=iPhone 17" clean build
```

**Run Tests** (ALL test suites - takes 3-5 minutes):
```bash
xcodebuild test \
  -scheme FamilyMenuPlanner \
  -project FamilyMenuPlanner.xcodeproj \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -testPlan FamilyMenuPlanner-Full \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

**Individual Test Suites**:
- Unit Tests: `xcodebuild test -scheme FamilyMenuPlanner -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:FamilyMenuPlannerUnitTests`
- Integration Tests: `xcodebuild test -scheme FamilyMenuPlanner -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:FamilyMenuPlannerIntegrationTests`
- Performance Tests: `xcodebuild test -scheme FamilyMenuPlanner -destination "platform=iOS Simulator,name=iPhone 17" -testPlan FamilyMenuPlanner-Full -only-testing:FamilyMenuPlannerPerformanceTests`
- UI Tests: `xcodebuild test -scheme FamilyMenuPlanner -destination "platform=iOS Simulator,name=iPhone 17" -testPlan FamilyMenuPlanner-Full -only-testing:FamilyMenuPlannerUITests`

**Important**: Always use iPhone 17 simulator for consistency with CI. UI tests require persistent storage (not in-memory).

## Project Layout & Architecture

### Root Structure
```
FamilyMenuPlanner.xcodeproj/          # Xcode project
FamilyMenuPlanner/                    # Main app source
├── FamilyMenuPlannerApp.swift       # App entry point
├── ContentView.swift                # Root SwiftUI view
├── Persistence.swift               # Core Data + CloudKit setup
├── Products/                       # Product management module
├── Dishes/                         # Dish management module
├── Menu/                          # Weekly menu planning module
├── Common/                        # Shared utilities
└── Resources/                     # Assets, localization, data
FamilyMenuPlannerUnitTests/           # Unit tests (mocked dependencies)
FamilyMenuPlannerIntegrationTests/    # Integration tests (real Core Data)
FamilyMenuPlannerPerformanceTests/    # Performance benchmarks
FamilyMenuPlannerUITests/             # Automated UI testing
ci_scripts/ci_post_clone.sh          # Xcode Cloud: generates Configs/Secrets.xcconfig
ci_scripts/ci_pre_xcodebuild.sh      # Xcode Cloud: checks Amplitude key before archive
FamilyMenuPlanner-PR.xctestplan      # Unit + Integration tests (default)
FamilyMenuPlanner-Full.xctestplan    # All 4 suites with timeouts
```

### Key Configuration Files
- **FamilyMenuPlanner.xcodeproj/xcshareddata/xcschemes/FamilyMenuPlanner.xcscheme**: Test configuration, environment variables
- **FamilyMenuPlanner/Info.plist**: App configuration, iOS version requirements
- **FamilyMenuPlanner/FamilyMenuPlanner.entitlements**: CloudKit and iCloud capabilities (`iCloud.container.menu`)
- **FamilyMenuPlanner/Resources/Localizable.xcstrings**: English and Russian localization
- **FamilyMenuPlanner/Resources/en.lproj/preloadData.json**: Initial app data (units, products, dishes)
- **FamilyMenuPlanner/Resources/ru.lproj/preloadData.json**: Russian version of initial data

### Core Data Model
**File**: `FamilyMenuPlanner/FamilyMenuPlanner.xcdatamodeld`
**Entities**: Product, Unit, Dish, DishCategory, MealType, Menu, IngredientDetail
**Features**: CloudKit sync, automatic migration, background operations

## MVVM + Coordinators Architecture

### Pattern Structure
```
View (SwiftUI) → ViewModel → Service → Core Data
     ↑              ↑
Coordinator ←──────┘
```

### Key Components by Module

**Products Module** (`FamilyMenuPlanner/Products/`):
- `ProductListView.swift` - Card-based product list UI
- `ProductListViewModel.swift` - Business logic, search, sorting
- `ProductListCoordinator.swift` - Navigation management
- `ProductListService.swift` - Core Data operations
- `EditProductView.swift` - Product creation/editing UI

**Dishes Module** (`FamilyMenuPlanner/Dishes/`):
- `DishListView.swift` - Dish management UI
- `DishListViewModel.swift` - Dish business logic
- `DishDetailsView.swift` - Dish editing with ingredients

**Menu Module** (`FamilyMenuPlanner/Menu/`):
- `MenuView.swift` - Weekly menu planning UI
- `MenuViewModel.swift` - Menu state management
- `DishSelectionView.swift` - Dish picker for meals

**Common Utilities** (`FamilyMenuPlanner/Common/`):
- `AppLogger.swift` - Structured logging (auto-detects CI)
- `BackgroundOperationManager.swift` - Heavy operations manager
- `StaticDataCacheManager.swift` - Units/MealTypes/Categories cache
- `SearchOptimizationHelper.swift` - Debounced search with caching

## Build Validation & CI

### CI Pipeline (Xcode Cloud)
Workflows are configured in Xcode / App Store Connect; the repo holds `ci_scripts/` and the test plans.
- **PR Validation**: on pull requests, test plan `FamilyMenuPlanner-PR` (Unit + Integration)
- **Full Tests**: manual, test plan `FamilyMenuPlanner-Full` (all 4 suites, 60s default / 120s max timeouts)
- **TestFlight**: on push to `main`, Test + Archive → TestFlight internal testing
- **App Store Release**: on tag, Archive → App Store
- **Secrets**: `ci_scripts/ci_post_clone.sh` writes `Configs/Secrets.xcconfig` from workflow env vars. TestFlight internal workflow defines only `AMPLITUDE_API_KEY_DEV` (archives fall back to it); App Store release workflow (tag) defines `AMPLITUDE_API_KEY_PROD`. `ci_scripts/ci_pre_xcodebuild.sh` fails an archive when the required key is missing (`_PROD` for tag builds, `_DEV` otherwise)
- **Environment**: test plans set `CI=true`
- **Dependencies**: `Package.resolved` must stay committed (Xcode Cloud does not resolve packages automatically)

### Validation Workflow
1. **Build First**: Always run clean build before tests
2. **Environment Check**: CI detection automatically disables CloudKit
3. **Test Order**: Unit → Integration → Performance → UI
4. **Timeout Handling**: Tests automatically fail after 120s
5. **Signing**: Xcode Cloud manages signing (automatic, team `TW4M5HXN5U`)

### Known Issues & Workarounds
- **CloudKit in Simulator**: Disabled by default for cleaner development
- **Test Isolation**: UI tests use persistent storage, others use in-memory
- **Static Data**: Automatically populated from `preloadData.json` on first launch
- **Duplicate Cleanup**: Automatic deduplication handles CloudKit sync conflicts

## Testing Architecture

### Test Categories
1. **Unit Tests** (`FamilyMenuPlannerUnitTests/`): ViewModels, helpers, business logic
2. **Integration Tests** (`FamilyMenuPlannerIntegrationTests/`): Service + Core Data interactions
3. **Performance Tests** (`FamilyMenuPlannerPerformanceTests/`): Core Data, caching, service benchmarks
4. **UI Tests** (`FamilyMenuPlannerUITests/`): End-to-end user workflows

### Test Data Factory
**File**: `FamilyMenuPlannerUnitTests/Common/TestDataFactory.swift`
**Purpose**: Centralized creation of test entities for all test types
**Usage**: Always use TestDataFactory for consistent test data

### Test Environment Setup
- **Automatic**: Tests auto-configure in-memory/persistent storage
- **Static Data**: Preloaded units, meal types, categories available
- **Isolation**: Each test gets clean persistence context

## Development Guidelines

### Code Standards
- **MVVM + Coordinators**: All features follow this pattern
- **Localization**: Use `.localized()` extension for all user-facing strings
- **Background Operations**: Use `BackgroundOperationManager` for heavy Core Data tasks
- **Logging**: Use `AppLogger` instead of `print` (auto-detects CI)
- **Error Handling**: Use `PersistenceController` error categorization

### UI/UX Consistency
- **Card-Based Design**: Use `ProductCardView`, `DishCardView` patterns
- **Colors**: `AccentColor`, `BackgroundColor`, `SecondaryBackgroundColor`
- **Buttons**: `ScaleButtonStyle` for tactile feedback
- **Accessibility**: Add identifiers and semantic labels

### Performance Patterns
- **Static Data Caching**: `StaticDataCacheManager` for Units/MealTypes/Categories
- **Search Optimization**: `SearchOptimizationHelper` with debouncing
- **Batch Operations**: Use background contexts for bulk operations
- **Memory Management**: Proper Core Data faulting and context lifecycle

## Common Tasks & Troubleshooting

### Adding New Features
1. Create MVVM structure in appropriate module directory
2. Add Coordinator for navigation
3. Use `BackgroundOperationManager` for Core Data operations
4. Add localized strings to `Localizable.xcstrings`
5. Create unit tests for ViewModels and integration tests for Services

### Core Data Changes
- **Schema Migration**: Handled automatically by Core Data
- **Preload Data**: Update `preloadData.json` in both language directories
- **Static Data**: Use `StaticDataCacheManager` for reference data

### Build Failures
- **Simulator Issues**: Restart simulator, ensure iPhone 17 available
- **CloudKit Errors**: Verify CI environment detection is working
- **Test Timeouts**: Check for infinite loops in Core Data operations
- **Code Signing**: Use `CODE_SIGNING_ALLOWED=NO` for local command-line test builds

### Trust These Instructions
These instructions are comprehensive and tested. Only search for additional information if:
- Build commands fail with specific errors not covered here
- New iOS/Xcode versions introduce compatibility issues  
- Adding features outside the documented MVVM + Coordinators pattern

The Xcode Cloud workflows validate these commands and patterns on every PR. Follow the documented architecture and build processes for reliable development.
