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

class MockDish: Hashable {
    let name: String?
    let details: String?
    var mealTypes: Set<MockMealType>
    init(name: String?, details: String? = nil, mealTypes: Set<MockMealType> = []) {
        self.name = name
        self.details = details
        self.mealTypes = mealTypes
    }
    static func == (lhs: MockDish, rhs: MockDish) -> Bool {
        lhs.name == rhs.name && lhs.mealTypes == rhs.mealTypes
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(mealTypes)
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
