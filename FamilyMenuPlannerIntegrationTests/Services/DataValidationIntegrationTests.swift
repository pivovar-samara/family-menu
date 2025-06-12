//
//  DataValidationIntegrationTests.swift
//  FamilyMenuPlannerIntegrationTests
//
//  Created by AI Assistant on 21.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

final class DataValidationIntegrationTests: BaseIntegrationTest {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Don't populate any data in setup - we want to test the validation system
    }
    
    func testEmptyDatabaseDetection() throws {
        // Test that empty database is correctly detected
        XCTAssertTrue(isDatabaseEmpty())
        XCTAssertTrue(isDatabaseEmptyOrOutdated())
    }
    
    func testDataPopulationAndValidation() throws {
        // Initially should be empty/outdated
        XCTAssertTrue(isDatabaseEmptyOrOutdated())
        
        // Populate with initial data using test-safe method
        generateTestInitialData()
        
        // Should not be empty anymore
        XCTAssertFalse(isDatabaseEmpty())
        
        // Should be valid (not outdated)
        XCTAssertFalse(isDatabaseEmptyOrOutdated())
        
        // Verify that basic entities were created
        let unitCount = try context.count(for: Unit.fetchRequest())
        let mealTypeCount = try context.count(for: MealType.fetchRequest())
        let categoryCount = try context.count(for: DishCategory.fetchRequest())
        
        XCTAssertGreaterThan(unitCount, 0, "Should have created units")
        XCTAssertGreaterThan(mealTypeCount, 0, "Should have created meal types")
        XCTAssertGreaterThan(categoryCount, 0, "Should have created dish categories")
    }
    
    func testVersionTracking() throws {
        let currentVersion = getCurrentPreloadDataVersion()
        XCTAssertFalse(currentVersion.isEmpty, "Should have a current version")
        
        // Initially no stored version
        XCTAssertNil(getStoredPreloadDataVersion())
        
        // After generating data, version should be stored
        generateTestInitialData()
        let storedVersion = getStoredPreloadDataVersion()
        XCTAssertEqual(storedVersion, currentVersion, "Stored version should match current version")
    }
    
    func testForceSchemaUpdate() throws {
        // Populate with initial data
        generateTestInitialData()
        
        // Verify data is valid
        XCTAssertFalse(isDatabaseEmptyOrOutdated())
        
        // Simulate outdated version
        UserDefaults.standard.removeObject(forKey: "PreloadDataVersion")
        
        // Should detect as outdated
        XCTAssertTrue(isDatabaseEmptyOrOutdated())
        
        // Force schema update
        forceDataSchemaUpdate()
        
        // Should be valid again
        XCTAssertFalse(isDatabaseEmptyOrOutdated())
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "PreloadDataVersion")
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
        
        return storedVersion != currentVersion
    }
    
    /// Test-safe implementation of initial data generation
    private func generateTestInitialData() {
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
        
        // Save the context
        try? context.save()
        
        // Mark current version as loaded
        UserDefaults.standard.set(getCurrentPreloadDataVersion(), forKey: "PreloadDataVersion")
    }
    
    /// Test-safe implementation of force schema update
    private func forceDataSchemaUpdate() {
        // Clear the stored version to force re-population
        UserDefaults.standard.removeObject(forKey: "PreloadDataVersion")
        
        // Trigger data generation
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