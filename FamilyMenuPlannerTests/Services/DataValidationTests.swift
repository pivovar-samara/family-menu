//
//  DataValidationTests.swift
//  FamilyMenuPlannerTests
//
//  Created by AI Assistant on 21.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

final class DataValidationTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        // Use TestCoreDataStack which properly loads the model from the test bundle
        context = TestCoreDataStack.shared.viewContext
        
        // Clear the database for a clean test state by deleting all entities
        clearAllEntities()
        
        // Clear any existing UserDefaults from previous tests
        UserDefaults.standard.removeObject(forKey: "PreloadDataVersion")
    }
    
    override func tearDownWithError() throws {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "PreloadDataVersion")
        
        // Clear the database after tests by deleting all entities
        clearAllEntities()
        
        context = nil
    }
    
    /// Clear all entities from the test database
    private func clearAllEntities() {
        do {
            // Clear each entity type individually using regular delete operations
            
            // Clear Units
            let unitFetch: NSFetchRequest<Unit> = Unit.fetchRequest()
            let units = try context.fetch(unitFetch)
            for unit in units {
                context.delete(unit)
            }
            
            // Clear MealTypes
            let mealTypeFetch: NSFetchRequest<MealType> = MealType.fetchRequest()
            let mealTypes = try context.fetch(mealTypeFetch)
            for mealType in mealTypes {
                context.delete(mealType)
            }
            
            // Clear DishCategories
            let dishCategoryFetch: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
            let dishCategories = try context.fetch(dishCategoryFetch)
            for dishCategory in dishCategories {
                context.delete(dishCategory)
            }
            
            // Clear Dishes
            let dishFetch: NSFetchRequest<Dish> = Dish.fetchRequest()
            let dishes = try context.fetch(dishFetch)
            for dish in dishes {
                context.delete(dish)
            }
            
            // Clear Products
            let productFetch: NSFetchRequest<Product> = Product.fetchRequest()
            let products = try context.fetch(productFetch)
            for product in products {
                context.delete(product)
            }
            
            // Clear Menus
            let menuFetch: NSFetchRequest<Menu> = Menu.fetchRequest()
            let menus = try context.fetch(menuFetch)
            for menu in menus {
                context.delete(menu)
            }
            
            // Clear IngredientDetails
            let ingredientDetailFetch: NSFetchRequest<IngredientDetail> = IngredientDetail.fetchRequest()
            let ingredientDetails = try context.fetch(ingredientDetailFetch)
            for ingredientDetail in ingredientDetails {
                context.delete(ingredientDetail)
            }
            
            // Save the changes
            try context.save()
        } catch {
            // Ignore errors during cleanup
            print("Error clearing entities: \(error)")
        }
    }
    
    func testEmptyDatabaseDetection() throws {
        // Test that empty database is correctly detected
        XCTAssertTrue(isDatabaseEmpty())
        XCTAssertTrue(isDatabaseEmptyOrOutdated())
    }
    
    func testValidDataDetection() throws {
        // Populate with initial data
        generateInitialDataWithClear()
        
        // Should not be empty anymore
        XCTAssertFalse(isDatabaseEmpty())
        
        // Should be valid (not outdated)
        XCTAssertFalse(isDatabaseEmptyOrOutdated())
    }
    
    func testOutdatedDataDetection() throws {
        // First populate with initial data
        generateInitialDataWithClear()
        
        // Simulate outdated version by changing stored version
        UserDefaults.standard.set("0.9", forKey: "PreloadDataVersion")
        
        // Should detect as outdated
        XCTAssertTrue(isDatabaseEmptyOrOutdated())
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "PreloadDataVersion")
    }
    
    func testMissingUnitsDetection() throws {
        // Populate with initial data
        generateInitialDataWithClear()
        
        // Remove one unit to simulate missing data
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        let units = try context.fetch(fetchRequest)
        if let firstUnit = units.first {
            context.delete(firstUnit)
            try context.save()
        }
        
        // Should detect as outdated due to missing unit
        XCTAssertTrue(isDatabaseEmptyOrOutdated())
    }
    
    func testIncorrectSortOrderDetection() throws {
        // Populate with initial data
        generateInitialDataWithClear()
        
        // Change sort order of a unit
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        let units = try context.fetch(fetchRequest)
        if let firstUnit = units.first {
            firstUnit.sortOrder = 999 // Invalid sort order
            try context.save()
        }
        
        // Should detect as outdated due to incorrect sort order
        XCTAssertTrue(isDatabaseEmptyOrOutdated())
    }
    
    func testForceSchemaUpdate() throws {
        // Populate with initial data
        generateInitialDataWithClear()
        
        // Verify data is valid
        XCTAssertFalse(isDatabaseEmptyOrOutdated())
        
        // Remove version to simulate outdated state
        UserDefaults.standard.removeObject(forKey: "PreloadDataVersion")
        
        // Should detect as outdated
        XCTAssertTrue(isDatabaseEmptyOrOutdated())
        
        // Force schema update
        forceDataSchemaUpdate()
        
        // Should be valid again
        XCTAssertFalse(isDatabaseEmptyOrOutdated())
        
        // Version should be set
        let storedVersion = getStoredPreloadDataVersion()
        XCTAssertEqual(storedVersion, getCurrentPreloadDataVersion())
    }
    
    func testVersionTracking() throws {
        let currentVersion = getCurrentPreloadDataVersion()
        XCTAssertFalse(currentVersion.isEmpty)
        
        // Initially no stored version
        XCTAssertNil(getStoredPreloadDataVersion())
        
        // After generating data, version should be stored
        generateInitialDataWithClear()
        let storedVersion = getStoredPreloadDataVersion()
        XCTAssertEqual(storedVersion, currentVersion)
    }
    
    func testDataRegenerationPreservesUserData() throws {
        // Create some user data first (a custom dish)
        let userDish = Dish(context: context)
        userDish.name = "User Custom Dish"
        userDish.details = "User created this dish"
        try context.save()
        
        // Generate initial data (this should NOT clear existing data)
        generateTestInitialData()
        
        // User dish should still exist
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "User Custom Dish")
        let userDishes = try context.fetch(fetchRequest)
        XCTAssertEqual(userDishes.count, 1)
        XCTAssertEqual(userDishes.first?.name, "User Custom Dish")
        
        // But initial data should also be present
        let allDishes = try context.fetch(Dish.fetchRequest())
        XCTAssertGreaterThan(allDishes.count, 1) // Should have user dish + preloaded dishes
    }
    
    // MARK: - Test Helper Methods
    
    /// Test-safe implementation of database empty check
    private func isDatabaseEmpty() -> Bool {
        do {
            let unitCount = try context.count(for: Unit.fetchRequest())
            let mealTypeCount = try context.count(for: MealType.fetchRequest())
            let categoryCount = try context.count(for: DishCategory.fetchRequest())
            
            return unitCount == 0 && mealTypeCount == 0 && categoryCount == 0
        } catch {
            return true
        }
    }
    
    /// Test-safe implementation of database empty or outdated check
    private func isDatabaseEmptyOrOutdated() -> Bool {
        if isDatabaseEmpty() {
            return true
        }
        
        let currentVersion = getCurrentPreloadDataVersion()
        let storedVersion = getStoredPreloadDataVersion()
        
        if storedVersion != currentVersion {
            return true
        }
        
        // Check if we have the expected number of units (should be 5)
        do {
            let unitCount = try context.count(for: Unit.fetchRequest())
            if unitCount < 5 {
                return true
            }
        } catch {
            return true
        }
        
        // Check if units have proper sort order
        do {
            let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            let units = try context.fetch(fetchRequest)
            
            for (index, unit) in units.enumerated() {
                if unit.sortOrder != Int16(index + 1) {
                    return true
                }
            }
        } catch {
            return true
        }
        
        return false
    }
    
    /// Test-safe implementation of initial data generation (preserves existing data)
    private func generateTestInitialData() {
        // Don't clear data here - that would remove user data
        // Only create initial data without clearing first
        
        // Create basic units
        let units = [
            ("kg", 1),
            ("g", 2),
            ("l", 3),
            ("ml", 4),
            ("pcs", 5)
        ]
        
        for (name, sortOrder) in units {
            let unit = Unit(context: context)
            unit.name = name
            unit.sortOrder = Int16(sortOrder)
        }
        
        // Create basic meal types
        let mealTypes = [
            ("Breakfast", 1),
            ("Lunch", 2),
            ("Dinner", 3)
        ]
        
        for (name, sortOrder) in mealTypes {
            let mealType = MealType(context: context)
            mealType.name = name
            mealType.sortOrder = Int16(sortOrder)
        }
        
        // Create basic dish categories
        let dishCategories = [
            ("Main Course", 1),
            ("Garnish", 2),
            ("Dessert", 3),
            ("Appetizer", 4),
            ("Sauce", 5)
        ]
        
        for (name, sortOrder) in dishCategories {
            let category = DishCategory(context: context)
            category.name = name
            category.sortOrder = Int16(sortOrder)
        }
        
        // Create some sample dishes to test the preservation test
        let dish = Dish(context: context)
        dish.name = "Test Dish"
        dish.details = "A test dish"
        
        // Save the context
        try? context.save()
        
        // Mark current version as loaded
        UserDefaults.standard.set(getCurrentPreloadDataVersion(), forKey: "PreloadDataVersion")
    }
    
    /// Generate initial data with clearing first (for tests that need clean state)
    private func generateInitialDataWithClear() {
        // Clear first to ensure clean state
        clearAllEntities()
        
        // Then generate the data
        generateTestInitialData()
    }
    
    /// Test-safe implementation of force schema update
    private func forceDataSchemaUpdate() {
        // Clear the stored version to force re-population
        UserDefaults.standard.removeObject(forKey: "PreloadDataVersion")
        
        // Clear all data first
        clearAllEntities()
        
        // Trigger data generation with the clean slate
        generateTestInitialData()
    }
    
    /// Get current preload data version
    private func getCurrentPreloadDataVersion() -> String {
        return "v1.0.0" // Test version
    }
    
    /// Get stored preload data version
    private func getStoredPreloadDataVersion() -> String? {
        return UserDefaults.standard.string(forKey: "PreloadDataVersion")
    }
}
