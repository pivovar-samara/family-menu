//
//  Persistence.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        result.generateInitialData(context: viewContext)
        
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "FamilyMenuPlanner")
        
        // Only initialize the schema when building the app with the
        // Debug build configuration.
        #if DEBUG
        do {
            // Use the container to initialize the development schema.
            try container.initializeCloudKitSchema(options: [])
        } catch {
            // Handle any errors.
        }
        #endif
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func isDatabaseEmpty(context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        fetchRequest.fetchLimit = 1

        do {
            let count = try context.count(for: fetchRequest)
            return count == 0
        } catch {
            print("Error checking database: \(error)")
            return true
        }
    }
    
    func generateInitialData(context: NSManagedObjectContext) {
        guard let url = Bundle.main.url(forResource: "preloadData", withExtension: "json") else {
            print("Failed to find preloadData.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode(PreloadedData.self, from: data)

            // Create Units
            var unitMap: [String: Unit] = [:]
            for unitData in jsonData.units {
                let unit = Unit(context: context)
                unit.name = unitData.name
                unit.sortOrder = unitData.sortOrder
                unitMap[unitData.name] = unit
            }
            
            // Create Meal types
            var mealTypeMap: [String: MealType] = [:]
            for mealTypeData in jsonData.mealTypes {
                let mealType = MealType(context: context)
                mealType.name = mealTypeData.name
                mealType.sortOrder = mealTypeData.sortOrder
                mealTypeMap[mealTypeData.name] = mealType
            }

            // Create Products
            var productMap: [String: Product] = [:]
            for productData in jsonData.products {
                let product = Product(context: context)
                product.name = productData.name
                product.unit = unitMap[productData.unit]
                productMap[productData.name] = product
            }

            // Create Dishes and Ingredients
            for dishData in jsonData.dishes {
                let dish = Dish(context: context)
                dish.name = dishData.name
                dish.details = dishData.details

                for ingredientData in dishData.ingredients {
                    if let product = productMap[ingredientData.product] {
                        let ingredient = IngredientDetail(context: context)
                        ingredient.dish = dish
                        ingredient.product = product
                        ingredient.quantity = ingredientData.quantity
                    } else {
                        print("Product \(ingredientData.product) not found for dish \(dishData.name).")
                    }
                }
                
                if let mealTypeNames = dishData.mealTypes {
                    for mealTypeName in mealTypeNames {
                        if let mealType = mealTypeMap[mealTypeName] {
                            dish.addToMealTypes(mealType)
                        }
                    }
                }
            }

            // Save all data
            try context.save()
            print("Data preloaded successfully from preloadData.json.")
        } catch {
            print("Error preloading data: \(error)")
        }
    }
    
    func deleteAllData(context: NSManagedObjectContext) {
        guard let entities = context.persistentStoreCoordinator?.managedObjectModel.entities else { return }

        for entity in entities {
            guard let entityName = entity.name else { continue }

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(batchDeleteRequest)
                print("✅ Successfully deleted all data from \(entityName)")
            } catch {
                print("❌ Error deleting data from \(entityName): \(error)")
            }
        }

        do {
            try context.save()
            print("✅ All data deleted successfully.")
        } catch {
            print("❌ Error saving context after deletion: \(error)")
        }
    }
}

// MARK: - Codable Structures for JSON
struct PreloadedData: Codable {
    let units: [UnitData]
    let products: [ProductData]
    let dishes: [DishData]
    let mealTypes: [MealTypeData]
}

struct UnitData: Codable {
    let name: String
    let sortOrder: Int16
}

struct ProductData: Codable {
    let name: String
    let unit: String
}

struct DishData: Codable {
    let name: String
    let details: String
    let ingredients: [IngredientData]
    let mealTypes: [String]?
}

struct IngredientData: Codable {
    let product: String
    let quantity: Double
}

struct MealTypeData: Codable {
    let name: String
    let sortOrder: Int16
}

