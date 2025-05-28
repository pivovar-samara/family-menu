import XCTest
import CoreData
@testable import FamilyMenuPlanner

// MARK: - Core Data Test Stack
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
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
}

// MARK: - Base Test Class
class BaseIntegrationTest: XCTestCase {
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = TestCoreDataStack.shared.viewContext
        cleanUpTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        context = nil
        super.tearDown()
    }
    
    func cleanUpTestData(entities: [String] = ["Dish", "MealType", "Menu", "Product", "Unit", "IngredientDetail"]) {
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
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
            context.rollback()
        }
    }
}

// MARK: - Test Data Creation Helpers
extension BaseIntegrationTest {
    func createMealType(name: String, sortOrder: Int16 = 0) -> MealType {
        let mealType = MealType(context: context)
        mealType.name = name
        mealType.sortOrder = sortOrder
        saveContext()
        return mealType
    }
    
    func createUnit(name: String, sortOrder: Int16 = 0) -> Unit {
        let unit = Unit(context: context)
        unit.name = name
        unit.sortOrder = sortOrder
        saveContext()
        return unit
    }
    
    func createProduct(name: String, unit: Unit) -> Product {
        let product = Product(context: context)
        product.name = name
        product.unit = unit
        saveContext()
        return product
    }
    
    func createDish(name: String, details: String? = nil, mealTypes: Set<MealType> = []) -> Dish {
        let dish = Dish(context: context)
        dish.name = name
        dish.details = details
        dish.mealTypes = mealTypes as NSSet
        saveContext()
        return dish
    }
} 