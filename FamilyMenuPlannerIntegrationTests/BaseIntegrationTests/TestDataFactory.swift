import Foundation
import CoreData
@testable import FamilyMenuPlanner

/// Factory for creating test data with consistent patterns
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
        product.isDraft = false  // Test products are complete
        saveContext()
        return product
    }
    
    func createDish(name: String, details: String? = nil, mealTypes: Set<MealType> = [], category: DishCategory? = nil) -> Dish {
        let dish = Dish(context: context)
        dish.name = name
        dish.details = details
        dish.mealTypes = mealTypes as NSSet
        dish.category = category
        dish.isDraft = false  // Test dishes are complete
        saveContext()
        return dish
    }
    
    func createBulkProducts(count: Int, namePrefix: String = "Product") -> [Product] {
        let unit = createUnit(name: "pcs")
        var products: [Product] = []
        
        context.performAndWait {
            for i in 1...count {
                let product = Product(context: context)
                product.name = "\(namePrefix) \(i)"
                product.unit = unit
                product.isDraft = false  // Test products are complete
                products.append(product)
            }
            saveContext()
        }
        
        return products
    }
    
    func createBulkDishes(count: Int, namePrefix: String = "Dish", category: DishCategory? = nil, mealTypes: Set<MealType> = []) -> [Dish] {
        var dishes: [Dish] = []
        
        context.performAndWait {
            for i in 1...count {
                let dish = Dish(context: context)
                dish.name = "\(namePrefix) \(i)"
                dish.details = "Test details for \(namePrefix) \(i)"
                dish.category = category
                dish.mealTypes = mealTypes as NSSet
                dish.isDraft = false  // Test dishes are complete
                dishes.append(dish)
            }
            saveContext()
        }
        
        return dishes
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
    
    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
            context.rollback()
        }
    }
} 