//
//  TestUtilities.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

// MARK: - Shared Test Core Data Stack
class TestCoreDataStack {
    static let shared = TestCoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let modelName = "FamilyMenuPlanner"
        
        guard let modelURL = Bundle(for: type(of: self)).url(forResource: modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model")
        }
        
        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        description.cloudKitContainerOptions = nil
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
}

// MARK: - Shared Test Data Factory
class TestDataFactory {
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func createUnit(name: String, sortOrder: Int16 = 0) -> Unit {
        let unit = Unit(context: context)
        unit.name = name
        unit.sortOrder = sortOrder
        saveContext()
        return unit
    }
    
    func createMealType(name: String, sortOrder: Int16 = 0) -> MealType {
        let mealType = MealType(context: context)
        mealType.name = name
        mealType.sortOrder = sortOrder
        saveContext()
        return mealType
    }
    
    func createDishCategory(name: String, sortOrder: Int16 = 0) -> DishCategory {
        let category = DishCategory(context: context)
        category.name = name
        category.sortOrder = sortOrder
        saveContext()
        return category
    }
    
    func createProduct(name: String, unit: Unit) -> Product {
        let product = Product(context: context)
        product.name = name
        product.unit = unit
        saveContext()
        return product
    }
    
    func createDish(name: String, details: String? = nil, mealTypes: [MealType] = [], category: DishCategory? = nil) -> Dish {
        let dish = Dish(context: context)
        dish.name = name
        dish.details = details
        dish.mealTypes = NSSet(array: mealTypes)
        dish.category = category
        saveContext()
        return dish
    }
    
    func createIngredientDetail(dish: Dish, product: Product, quantity: Double, unit: Unit) -> IngredientDetail {
        let ingredient = IngredientDetail(context: context)
        ingredient.dish = dish
        ingredient.product = product
        ingredient.quantity = quantity
        ingredient.sortOrder = 0
        saveContext()
        return ingredient
    }
    
    func createMenu(weekStartDate: Date, dish: Dish, mealType: MealType) -> Menu {
        let calendar = Calendar.current
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStartDate)
        let encodedWeek = (weekComponents.yearForWeekOfYear ?? 0) * 100 + (weekComponents.weekOfYear ?? 0)
        
        let menu = Menu(context: context)
        menu.day = "Monday" // Default day for testing
        menu.mealType = mealType.name // mealType property is a String, not MealType object
        menu.calendarWeek = Int32(encodedWeek)
        menu.addToDishes(dish)
        saveContext()
        return menu
    }
    
    func cleanUpTestData() {
        let entities = ["IngredientDetail", "Dish", "Product", "Unit", "MealType", "DishCategory", "Menu"]
        for entityName in entities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let objects = try context.fetch(request)
                for object in objects {
                    context.delete(object)
                }
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save context after cleanup: \(error)")
        }
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

// MARK: - Mock Classes for Unit Tests
class MockMealType: Hashable {
    let name: String
    let sortOrder: Int16
    init(name: String, sortOrder: Int16 = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }
    static func == (lhs: MockMealType, rhs: MockMealType) -> Bool {
        lhs.name == rhs.name && lhs.sortOrder == rhs.sortOrder
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(sortOrder)
    }
}

class MockDishCategory: Hashable {
    let name: String
    let sortOrder: Int16
    init(name: String, sortOrder: Int16 = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }
    static func == (lhs: MockDishCategory, rhs: MockDishCategory) -> Bool {
        lhs.name == rhs.name && lhs.sortOrder == rhs.sortOrder
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(sortOrder)
    }
}

class MockDish: Hashable {
    let name: String?
    let details: String?
    var mealTypes: Set<MockMealType>
    var category: MockDishCategory?
    init(name: String?, details: String? = nil, mealTypes: Set<MockMealType> = [], category: MockDishCategory? = nil) {
        self.name = name
        self.details = details
        self.mealTypes = mealTypes
        self.category = category
    }
    static func == (lhs: MockDish, rhs: MockDish) -> Bool {
        lhs.name == rhs.name && lhs.mealTypes == rhs.mealTypes && lhs.category == rhs.category
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(mealTypes)
        hasher.combine(category)
    }
}

class MockUnit: Hashable {
    let name: String
    let sortOrder: Int16
    
    init(name: String, sortOrder: Int16) {
        self.name = name
        self.sortOrder = sortOrder
    }
    
    static func == (lhs: MockUnit, rhs: MockUnit) -> Bool {
        lhs.name == rhs.name && lhs.sortOrder == rhs.sortOrder
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(sortOrder)
    }
}

class MockProduct: Hashable {
    var name: String?
    var unit: MockUnit?
    
    init(name: String?, unit: MockUnit?) {
        self.name = name
        self.unit = unit
    }
    
    static func == (lhs: MockProduct, rhs: MockProduct) -> Bool {
        lhs.name == rhs.name && lhs.unit == rhs.unit
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(unit)
    }
}

class MockIngredientDetail {
    var dish: MockDish?
    var product: MockProduct?
    var quantity: Double = 0.0
    var sortOrder: Int16 = 0
}
