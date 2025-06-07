//
//  MenuServiceUnitTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class MenuServiceUnitTests: XCTestCase {
    var menuService: MenuService!
    var testStack: TestCoreDataStack!
    var context: NSManagedObjectContext!
    var testDataFactory: TestDataFactory!
    
    override func setUp() {
        super.setUp()
        testStack = TestCoreDataStack.shared
        context = testStack.viewContext
        testDataFactory = TestDataFactory(context: context)
        
        // Create MenuService with test context
        menuService = MenuService(context: context)
        
        // Clean slate for each test
        cleanUpTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        menuService = nil
        testDataFactory = nil
        context = nil
        testStack = nil
        super.tearDown()
    }
    
    private func cleanUpTestData() {
        testDataFactory?.cleanUpTestData()
    }
    
    // MARK: - Test Menu Fetching
    
    func testFetchMenuForWeek() {
        // Create test data
        let mealType = testDataFactory.createMealType(name: "Breakfast", sortOrder: 1)
        let category = testDataFactory.createDishCategory(name: "Main Course", sortOrder: 1)
        let dish = testDataFactory.createDish(name: "Pancakes", details: "Delicious", mealTypes: [mealType], category: category)
        
        // Create weekly menu data
        let today = Date()
        
        createMenuEntry(day: "Monday", mealType: "Breakfast", dishes: [dish], weekDate: today)
        
        // Test fetching menu
        let menu = menuService.fetchMenu(for: 0)
        
        XCTAssertFalse(menu.isEmpty, "Menu should not be empty")
        let mondayMenu = menu.first { $0.day == "Monday" }
        XCTAssertNotNil(mondayMenu, "Monday menu should exist")
        
        let breakfastMeal = mondayMenu?.dailyMeals.first { $0.meal == "Breakfast" }
        XCTAssertNotNil(breakfastMeal, "Breakfast meal should exist")
        XCTAssertEqual(breakfastMeal?.dishes.count, 1, "Should have one dish")
        XCTAssertEqual(breakfastMeal?.dishes.first?.name, "Pancakes")
    }
    
    func testFetchMenuWithNoDishes() {
        // Test with empty menu
        let menu = menuService.fetchMenu(for: 0)
        
        // Should return 7 days with empty meals
        XCTAssertEqual(menu.count, 7, "Should return 7 days")
        for dailyMenu in menu {
            XCTAssertTrue(dailyMenu.dailyMeals.allSatisfy { $0.dishes.isEmpty }, "All meals should be empty")
        }
    }
    
    func testFetchMenuForDifferentWeeks() {
        // Create data for current week
        let calendar = Calendar.current
        let today = Date()
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!
        
        let mealType = testDataFactory.createMealType(name: "Dinner", sortOrder: 1)
        let category = testDataFactory.createDishCategory(name: "Main Course", sortOrder: 1)
        let currentWeekDish = testDataFactory.createDish(name: "Current Week Dish", mealTypes: [mealType], category: category)
        let nextWeekDish = testDataFactory.createDish(name: "Next Week Dish", mealTypes: [mealType], category: category)
        
        createMenuEntry(day: "Monday", mealType: "Dinner", dishes: [currentWeekDish], weekDate: currentWeekStart)
        createMenuEntry(day: "Monday", mealType: "Dinner", dishes: [nextWeekDish], weekDate: nextWeekStart)
        
        // Test current week
        let currentWeekMenu = menuService.fetchMenu(for: 0)
        let currentMondayDinner = currentWeekMenu.first { $0.day == "Monday" }?.dailyMeals.first { $0.meal == "Dinner" }
        XCTAssertEqual(currentMondayDinner?.dishes.first?.name, "Current Week Dish")
        
        // Test next week
        let nextWeekMenu = menuService.fetchMenu(for: 1)
        let nextMondayDinner = nextWeekMenu.first { $0.day == "Monday" }?.dailyMeals.first { $0.meal == "Dinner" }
        XCTAssertEqual(nextMondayDinner?.dishes.first?.name, "Next Week Dish")
    }
    
    // MARK: - Test Menu Generation
    
    func testGenerateMenu() {
        // Create test dishes with different meal types
        let breakfast = testDataFactory.createMealType(name: "Breakfast", sortOrder: 1)
        let lunch = testDataFactory.createMealType(name: "Lunch", sortOrder: 2)
        let category = testDataFactory.createDishCategory(name: "Main Course", sortOrder: 1)
        
        _ = testDataFactory.createDish(name: "Pancakes", mealTypes: [breakfast], category: category)
        _ = testDataFactory.createDish(name: "Sandwich", mealTypes: [lunch], category: category)
        
        let today = Date()
        
        // Generate menu
        menuService.generateMenu(for: today)
        
        // Verify menu was created
        let menu = menuService.fetchMenu(for: 0)
        XCTAssertFalse(menu.isEmpty, "Generated menu should not be empty")
        
        // Should have some dishes assigned
        let totalDishes = menu.flatMap { $0.dailyMeals }.flatMap { $0.dishes }.count
        XCTAssertGreaterThan(totalDishes, 0, "Should have assigned some dishes")
    }
    
    // MARK: - Test Dish Replacement
    
    func testReplaceDishes() throws {
        let today = Date()
        
        let mealType = testDataFactory.createMealType(name: "Lunch", sortOrder: 1)
        let category = testDataFactory.createDishCategory(name: "Main Course", sortOrder: 1)
        let oldDish = testDataFactory.createDish(name: "Old Dish", mealTypes: [mealType], category: category)
        let newDish = testDataFactory.createDish(name: "New Dish", mealTypes: [mealType], category: category)
        
        // Create initial menu entry
        createMenuEntry(day: "Tuesday", mealType: "Lunch", dishes: [oldDish], weekDate: today)
        
        // Replace dishes
        try menuService.replaceDishes(for: "Tuesday", mealType: "Lunch", selectedWeekDate: today, with: [newDish])
        
        // Verify replacement
        let menu = menuService.fetchMenu(for: 0)
        let tuesdayLunch = menu.first { $0.day == "Tuesday" }?.dailyMeals.first { $0.meal == "Lunch" }
        XCTAssertEqual(tuesdayLunch?.dishes.count, 1)
        XCTAssertEqual(tuesdayLunch?.dishes.first?.name, "New Dish")
    }
    
    func testClearMealType() throws {
        let today = Date()
        
        let mealType = testDataFactory.createMealType(name: "Dinner", sortOrder: 1)
        let category = testDataFactory.createDishCategory(name: "Main Course", sortOrder: 1)
        let dish = testDataFactory.createDish(name: "Test Dish", mealTypes: [mealType], category: category)
        
        // Create menu entry
        createMenuEntry(day: "Wednesday", mealType: "Dinner", dishes: [dish], weekDate: today)
        
        // Clear meal type
        try menuService.clearMealType(for: "Wednesday", selectedWeekDate: today, mealType: "Dinner")
        
        // Verify clearing
        let menu = menuService.fetchMenu(for: 0)
        let wednesdayDinner = menu.first { $0.day == "Wednesday" }?.dailyMeals.first { $0.meal == "Dinner" }
        XCTAssertTrue(wednesdayDinner?.dishes.isEmpty ?? true, "Dinner should be cleared")
    }
    
    // MARK: - Test Old Week Removal
    
    func testRemoveOldWeeks() {
        let calendar = Calendar.current
        let today = Date()
        let oldWeek = calendar.date(byAdding: .weekOfYear, value: -2, to: today)!
        let currentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        let mealType = testDataFactory.createMealType(name: "Breakfast", sortOrder: 1)
        let category = testDataFactory.createDishCategory(name: "Main Course", sortOrder: 1)
        let dish = testDataFactory.createDish(name: "Old Dish", mealTypes: [mealType], category: category)
        
        // Create old week data
        createMenuEntry(day: "Monday", mealType: "Breakfast", dishes: [dish], weekDate: oldWeek)
        createMenuEntry(day: "Monday", mealType: "Breakfast", dishes: [dish], weekDate: currentWeek)
        
        // Verify both exist initially
        let request: NSFetchRequest<Menu> = Menu.fetchRequest()
        let initialCount = (try? context.fetch(request).count) ?? 0
        XCTAssertEqual(initialCount, 2, "Should have 2 menu entries")
        
        // Remove old weeks
        menuService.removeOldWeeks()
        
        // Verify old week was removed
        let finalCount = (try? context.fetch(request).count) ?? 0
        XCTAssertEqual(finalCount, 1, "Should have 1 menu entry after cleanup")
    }
    
    // MARK: - Helper Methods
    
    private func createMenuEntry(day: String, mealType: String, dishes: [Dish], weekDate: Date) {
        let calendar = Calendar.current
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekDate)
        let encodedWeek = encodeWeek(weekComponents)
        
        let menu = Menu(context: context)
        menu.day = day
        menu.mealType = mealType
        menu.calendarWeek = Int32(encodedWeek)
        menu.dishes = NSSet(array: dishes)
        
        try? context.save()
    }
    
    private func encodeWeek(_ weekComponents: DateComponents) -> Int {
        let year = weekComponents.yearForWeekOfYear ?? 0
        let week = weekComponents.weekOfYear ?? 0
        return year * 100 + week
    }
} 
