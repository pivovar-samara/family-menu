//
//  BaseIntegrationTest.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 03.06.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

// MARK: - Base Test Class
class BaseIntegrationTest: XCTestCase {
    var context: NSManagedObjectContext!
    var testDataFactory: TestDataFactory!
    
    override func setUp() {
        super.setUp()
        context = TestCoreDataStack.shared.viewContext
        testDataFactory = TestDataFactory(context: context)
        
        // Initialize the shared cache manager with the test context
        StaticDataCacheManager.shared.initialize(with: context)
        
        // Clear cache before each test to ensure test isolation
        StaticDataCacheManager.shared.invalidateCacheSync()
        cleanUpTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        // Clear cache after each test to prevent interference with other tests
        StaticDataCacheManager.shared.invalidateCacheSync()
        testDataFactory = nil
        context = nil
        super.tearDown()
    }
    
    func cleanUpTestData(entities: [String] = ["Dish", "MealType", "DishCategory", "Menu", "Product", "Unit", "IngredientDetail"]) {
        guard let context = context else { 
            print("Context is nil, skipping cleanup")
            return 
        }
        
        for entityName in entities {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: entityName)
            do {
                let objects = try context.fetch(fetchRequest)
                for object in objects {
                    context.delete(object)
                }
            } catch {
                print("Error cleaning up \(entityName): \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving context after cleanup: \(error)")
        }
    }
    
    func saveContext() {
        guard let context = context, context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
            context.rollback()
        }
    }
    
    func testEmpty() {
        XCTAssertTrue(true)
    }
}

// MARK: - Test Data Creation Helpers (using TestDataFactory)
extension BaseIntegrationTest {
    func createMealType(name: String, sortOrder: Int16 = 0) -> MealType {
        return testDataFactory.createMealType(name: name, sortOrder: sortOrder)
    }
    
    func createDishCategory(name: String, sortOrder: Int16 = 0) -> DishCategory {
        return testDataFactory.createDishCategory(name: name, sortOrder: sortOrder)
    }
    
    func createUnit(name: String, sortOrder: Int16 = 0) -> Unit {
        return testDataFactory.createUnit(name: name, sortOrder: sortOrder)
    }
    
    func createProduct(name: String, unit: Unit) -> Product {
        return testDataFactory.createProduct(name: name, unit: unit)
    }
    
    func createDish(name: String, details: String? = nil, mealTypes: Set<MealType> = [], category: DishCategory? = nil) -> Dish {
        return testDataFactory.createDish(name: name, details: details, mealTypes: mealTypes, category: category)
    }
    
    func createBulkProducts(count: Int, namePrefix: String = "Product") -> [Product] {
        return testDataFactory.createBulkProducts(count: count, namePrefix: namePrefix)
    }
}
