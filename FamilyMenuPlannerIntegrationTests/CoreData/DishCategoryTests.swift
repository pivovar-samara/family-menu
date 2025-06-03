//
//  DishCategoryTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Test Generator
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class DishCategoryTests: BaseIntegrationTest {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Core Data Model Tests
    
    func testCreateDishCategory() {
        // Create a dish category
        let category = DishCategory(context: context)
        category.name = "Main Course"
        category.sortOrder = 1
        
        // Save context
        saveContext()
        
        // Verify category was created
        XCTAssertNotNil(category.name)
        XCTAssertEqual(category.name, "Main Course")
        XCTAssertEqual(category.sortOrder, 1)
    }
    
    func testDishCategoryRelationship() {
        // Create category and dish
        let category = createDishCategory(name: "Dessert", sortOrder: 3)
        let dish = createDish(name: "Chocolate Cake", category: category)
        
        // Verify relationship
        XCTAssertEqual(dish.category?.name, "Dessert")
        XCTAssertTrue(category.dishes?.contains(dish) ?? false)
    }
    
    func testMultipleDishesToCategory() {
        // Create category
        let category = createDishCategory(name: "Main Course", sortOrder: 1)
        
        // Create multiple dishes
        let dish1 = createDish(name: "Chicken Breast", category: category)
        let dish2 = createDish(name: "Beef Steak", category: category)
        let dish3 = createDish(name: "Fish Fillet", category: category)
        
        // Verify relationships
        XCTAssertEqual(category.dishes?.count, 3)
        XCTAssertTrue(category.dishes?.contains(dish1) ?? false)
        XCTAssertTrue(category.dishes?.contains(dish2) ?? false)
        XCTAssertTrue(category.dishes?.contains(dish3) ?? false)
    }
    
    func testDishWithoutCategory() {
        // Create dish without category
        let dish = createDish(name: "Uncategorized Dish")
        
        // Verify no category is assigned
        XCTAssertNil(dish.category)
    }
    
    func testDeleteCategory() {
        // Create category with dishes
        let category = createDishCategory(name: "Appetizer", sortOrder: 4)
        let dish = createDish(name: "Spring Rolls", category: category)
        
        // Verify relationship exists
        XCTAssertNotNil(dish.category)
        
        // Delete category
        context.delete(category)
        saveContext()
        
        // Verify dish's category is nil (cascade delete behavior)
        context.refreshAllObjects()
        XCTAssertNil(dish.category)
    }
    
    // MARK: - Preload Data Tests
    
    func testPreloadDataStructure() {
        // Create test preload data structure
        let categoryData = DishCategoryData(name: "Test Category", sortOrder: 1)
        
        // Verify structure
        XCTAssertEqual(categoryData.name, "Test Category")
        XCTAssertEqual(categoryData.sortOrder, 1)
    }
    
    func testCreateCategoryFromPreloadData() {
        // Create category data
        let categoryData = DishCategoryData(name: "Sauce", sortOrder: 5)
        
        // Create category from data
        let category = DishCategory(context: context)
        category.name = categoryData.name
        category.sortOrder = categoryData.sortOrder
        
        saveContext()
        
        // Verify category was created correctly
        XCTAssertEqual(category.name, "Sauce")
        XCTAssertEqual(category.sortOrder, 5)
    }
    
    // MARK: - Fetch Tests
    
    func testFetchAllCategories() {
        // Create multiple categories
        let _ = createDishCategory(name: "Main Course", sortOrder: 1)
        let _ = createDishCategory(name: "Garnish", sortOrder: 2)
        let _ = createDishCategory(name: "Dessert", sortOrder: 3)
        
        // Fetch all categories
        let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DishCategory.sortOrder, ascending: true)]
        
        do {
            let categories = try context.fetch(fetchRequest)
            
            // Verify categories were fetched in correct order
            XCTAssertEqual(categories.count, 3)
            XCTAssertEqual(categories[0].name, "Main Course")
            XCTAssertEqual(categories[1].name, "Garnish")
            XCTAssertEqual(categories[2].name, "Dessert")
        } catch {
            XCTFail("Failed to fetch categories: \(error)")
        }
    }
    
    func testFetchDishesByCategory() {
        // Create categories
        let mainCourse = createDishCategory(name: "Main Course", sortOrder: 1)
        let dessert = createDishCategory(name: "Dessert", sortOrder: 3)
        
        // Create dishes
        let _ = createDish(name: "Chicken", category: mainCourse)
        let _ = createDish(name: "Beef", category: mainCourse)
        let _ = createDish(name: "Ice Cream", category: dessert)
        
        // Fetch dishes by category
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "category.name == %@", "Main Course")
        
        do {
            let dishes = try context.fetch(fetchRequest)
            
            // Verify only main course dishes were fetched
            XCTAssertEqual(dishes.count, 2)
            XCTAssertTrue(dishes.contains { $0.name == "Chicken" })
            XCTAssertTrue(dishes.contains { $0.name == "Beef" })
            XCTAssertFalse(dishes.contains { $0.name == "Ice Cream" })
        } catch {
            XCTFail("Failed to fetch dishes by category: \(error)")
        }
    }
    
    // MARK: - Service Integration Tests
    
    func testDishDetailsServiceFetchCategories() {
        // Create test categories
        let _ = createDishCategory(name: "Main Course", sortOrder: 1)
        let _ = createDishCategory(name: "Garnish", sortOrder: 2)
        
        // Create service
        let service = DishDetailsService(context: context)
        
        // Fetch categories
        let categories = service.fetchAllDishCategories()
        
        // Verify categories were fetched
        XCTAssertEqual(categories.count, 2)
        XCTAssertTrue(categories.contains { $0.name == "Main Course" })
        XCTAssertTrue(categories.contains { $0.name == "Garnish" })
    }
    
    // MARK: - Edge Cases
    
    func testCategoryWithEmptyName() {
        // Create category with empty name
        let category = DishCategory(context: context)
        category.name = ""
        category.sortOrder = 1
        
        saveContext()
        
        // Verify category was created (empty name is allowed)
        XCTAssertEqual(category.name, "")
    }
    
    func testCategoryWithNilName() {
        // Create category with nil name
        let category = DishCategory(context: context)
        category.name = nil
        category.sortOrder = 1
        
        saveContext()
        
        // Verify category was created (nil name is allowed)
        XCTAssertNil(category.name)
    }
    
    func testDuplicateCategoryNames() {
        // Create categories with same name but different sort orders
        let category1 = createDishCategory(name: "Main Course", sortOrder: 1)
        let category2 = createDishCategory(name: "Main Course", sortOrder: 2)
        
        // Verify both categories exist (duplicates are allowed)
        XCTAssertEqual(category1.name, category2.name)
        XCTAssertNotEqual(category1.sortOrder, category2.sortOrder)
        
        // Fetch all categories with same name
        let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Main Course")
        
        do {
            let categories = try context.fetch(fetchRequest)
            XCTAssertEqual(categories.count, 2)
        } catch {
            XCTFail("Failed to fetch duplicate categories: \(error)")
        }
    }
} 