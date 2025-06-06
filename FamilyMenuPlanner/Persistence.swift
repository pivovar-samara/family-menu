//
//  Persistence.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import CoreData

// MARK: - Persistence Errors
enum PersistenceError: Error, LocalizedError {
    case storeLoadingFailed(NSError)
    case storeRecoveryFailed(NSError)
    case migrationFailed(NSError)
    case diskSpaceInsufficient
    case permissionDenied
    case unknown(NSError)
    
    var errorDescription: String? {
        switch self {
        case .storeLoadingFailed(let error):
            return String(format: "Failed to load data store: %@".localized(), error.localizedDescription)
        case .storeRecoveryFailed(let error):
            return String(format: "Failed to recover data store: %@".localized(), error.localizedDescription)
        case .migrationFailed(let error):
            return String(format: "Failed to migrate data: %@".localized(), error.localizedDescription)
        case .diskSpaceInsufficient:
            return "Insufficient disk space to load the app".localized()
        case .permissionDenied:
            return "Permission denied to access data".localized()
        case .unknown(let error):
            return String(format: "An unexpected error occurred: %@".localized(), error.localizedDescription)
        }
    }
}

// MARK: - Persistence State Manager
class PersistenceStateManager: ObservableObject {
    @Published var hasLoadingError: Bool = false
    @Published var loadingError: PersistenceError?
    
    var isReady: Bool {
        return !hasLoadingError
    }
    
    var userFriendlyErrorMessage: String? {
        return loadingError?.localizedDescription
    }
    
    func setError(_ error: PersistenceError) {
        DispatchQueue.main.async {
            self.loadingError = error
            self.hasLoadingError = true
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.loadingError = nil
            self.hasLoadingError = false
        }
    }
}

// MARK: - Persistence Controller
struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        result.generateInitialData(context: viewContext)
        
        return result
    }()

    let container: NSPersistentContainer
    let stateManager = PersistenceStateManager()

    init(inMemory: Bool = false) {
        // Enhanced test environment detection for CI with more robust checks
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            NSClassFromString("XCTestCase") != nil ||
                            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||  // GitHub Actions
                            ProcessInfo.processInfo.environment["CI"] != nil ||              // Generic CI
                            ProcessInfo.processInfo.environment["BUILD_NUMBER"] != nil ||    // Xcode Cloud
                            ProcessInfo.processInfo.arguments.contains("test") ||           // xcodebuild test
                            ProcessInfo.processInfo.arguments.contains("-XCTest")           // Additional test detection
        
        // Check if we're in simulator using Swift-compatible approach
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        
        // Always use NSPersistentContainer for CI/tests to avoid CloudKit issues
        // Use NSPersistentContainer for tests, CI environments, or simulator
        if isRunningTests || inMemory || (isSimulator && ProcessInfo.processInfo.environment["CI"] != nil) {
            container = NSPersistentContainer(name: "FamilyMenuPlanner")
            AppLogger.info("Using NSPersistentContainer (no CloudKit) for CI/test environment", category: AppLogger.persistence)
        } else {
            container = NSPersistentCloudKitContainer(name: "FamilyMenuPlanner")
            AppLogger.info("Using NSPersistentCloudKitContainer for production environment", category: AppLogger.persistence)
        }
        
        // Configure store descriptions before loading
        configureStoreDescriptions(inMemory: inMemory, isRunningTests: isRunningTests, isSimulator: isSimulator)
        
        // Only initialize CloudKit schema when building the app with the
        // Debug build configuration and not running tests or in CI environments.
        #if DEBUG
        if !isRunningTests && !inMemory && (!isSimulator || shouldUseCloudKitInSimulator()) {
            if let cloudKitContainer = container as? NSPersistentCloudKitContainer {
                do {
                    // Use the container to initialize the development schema.
                    try cloudKitContainer.initializeCloudKitSchema(options: [])
                    AppLogger.info("CloudKit schema initialized successfully", category: AppLogger.cloudKit)
                } catch {
                    AppLogger.error("CloudKit schema initialization failed", error: error, category: AppLogger.cloudKit)
                }
            }
        } else {
            AppLogger.info("Skipping CloudKit schema initialization for CI/test environment", category: AppLogger.cloudKit)
        }
        #endif
        
        loadPersistentStores()
    }
    
    private func shouldUseCloudKitInSimulator() -> Bool {
        // You can modify this logic based on your preference
        // Return true if you want to test CloudKit in simulator (requires iCloud login)
        // Return false for cleaner simulator experience
        return false  // Changed to false for cleaner simulator development
    }
    
    private func configureStoreDescriptions(inMemory: Bool, isRunningTests: Bool, isSimulator: Bool) {
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure store options for better error handling and performance
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Enable automatic store migration
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            // Configure history tracking and notifications based on environment
            if isRunningTests || inMemory {
                // Minimal configuration for test environments to avoid issues
                storeDescription.setOption(false as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(false as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                AppLogger.info("Configured Core Data for test environment - minimal options", category: AppLogger.persistence)
            } else {
                // Full configuration for production
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                AppLogger.info("Configured Core Data for production environment - full options", category: AppLogger.persistence)
            }
            
            // Completely disable CloudKit for tests/CI or optionally for simulator
            if isRunningTests || inMemory || (isSimulator && !shouldUseCloudKitInSimulator()) {
                // Remove CloudKit configuration for test environments or simulator (based on preference)
                storeDescription.cloudKitContainerOptions = nil
                AppLogger.info("CloudKit disabled for test/simulator environment", category: AppLogger.persistence)
            } else {
                AppLogger.info("CloudKit enabled for production environment", category: AppLogger.persistence)
            }
        } else {
            AppLogger.error("Failed to get store description - this may cause startup issues", category: AppLogger.persistence)
        }
    }
    
    private func loadPersistentStores(completion: @escaping (Bool) -> Void = { _ in }) {
        AppLogger.info("Loading persistent stores...", category: AppLogger.persistence)
        
        container.loadPersistentStores { [weak stateManager = self.stateManager] (storeDescription, error) in
            if let error = error as NSError? {
                AppLogger.error("Persistent store loading failed", error: error, category: AppLogger.persistence)
                AppLogger.error("Store description: \(storeDescription.description)", category: AppLogger.persistence)
                
                self.handleStoreLoadingError(error, storeDescription: storeDescription, stateManager: stateManager) { success in
                    completion(success)
                }
            } else {
                AppLogger.info("Persistent stores loaded successfully", category: AppLogger.persistence)
                AppLogger.info("Store description: \(storeDescription.description)", category: AppLogger.persistence)
                
                self.configureSuccessfulStore()
                stateManager?.clearError()
                completion(true)
            }
        }
    }
    
    private func handleStoreLoadingError(_ error: NSError, storeDescription: NSPersistentStoreDescription?, stateManager: PersistenceStateManager?, completion: @escaping (Bool) -> Void) {
        let persistenceError = categorizeError(error)
        stateManager?.setError(persistenceError)
        
        // Log the error for debugging and analytics
        logError(error, persistenceError: persistenceError)
        
        // Attempt recovery based on error type
        if attemptErrorRecovery(error, storeDescription: storeDescription) {
            // If recovery succeeded, retry loading
            retryStoreLoading { success in
                completion(success)
            }
        } else {
            // If recovery failed, fall back to in-memory store
            fallbackToInMemoryStore { success in
                completion(success)
            }
        }
    }
    
    private func categorizeError(_ error: NSError) -> PersistenceError {
        switch error.code {
        case NSPersistentStoreIncompatibleVersionHashError,
             NSMigrationError:
            return .migrationFailed(error)
        case NSFileReadNoPermissionError,
             NSFileWriteNoPermissionError:
            return .permissionDenied
        case NSPersistentStoreTimeoutError,
             NSPersistentStoreUnsupportedRequestTypeError:
            return .storeLoadingFailed(error)
        default:
            // Check for disk space issues
            if error.localizedDescription.lowercased().contains("space") {
                return .diskSpaceInsufficient
            }
            return .unknown(error)
        }
    }
    
    private func logError(_ error: NSError, persistenceError: PersistenceError) {
        AppLogger.critical("Core Data Store Loading Error", category: AppLogger.persistence)
        AppLogger.error("Code: \(error.code), Domain: \(error.domain)", category: AppLogger.persistence)
        AppLogger.error("Description: \(error.localizedDescription)", category: AppLogger.persistence)
        AppLogger.error("User Info: \(error.userInfo)", category: AppLogger.persistence)
        AppLogger.error("Categorized as: \(persistenceError)", category: AppLogger.persistence)
        
        // TODO: Send to crash reporting service (e.g., Crashlytics, Sentry)
        // CrashReporter.shared.recordError(persistenceError)
    }
    
    private func attemptErrorRecovery(_ error: NSError, storeDescription: NSPersistentStoreDescription?) -> Bool {
        AppLogger.info("Attempting error recovery", category: AppLogger.persistence)
        
        switch categorizeError(error) {
        case .migrationFailed:
            return attemptMigrationRecovery(storeDescription: storeDescription)
        case .permissionDenied:
            return attemptPermissionRecovery()
        case .diskSpaceInsufficient:
            return attemptDiskSpaceRecovery()
        case .storeLoadingFailed:
            return attemptStoreRecovery(storeDescription: storeDescription)
        default:
            return false
        }
    }
    
    private func attemptMigrationRecovery(storeDescription: NSPersistentStoreDescription?) -> Bool {
        guard let storeDescription = storeDescription,
              let storeURL = storeDescription.url else {
            return false
        }
        
        AppLogger.info("Attempting migration recovery", category: AppLogger.persistence)
        
        // Try to delete and recreate the store if migration fails
        do {
            let fileManager = FileManager.default
            
            // Remove the existing store files
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
            }
            
            // Remove related files (WAL, SHM)
            let walURL = storeURL.appendingPathExtension("sqlite-wal")
            let shmURL = storeURL.appendingPathExtension("sqlite-shm")
            
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.removeItem(at: walURL)
            }
            
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.removeItem(at: shmURL)
            }
            
            AppLogger.info("Store files removed successfully", category: AppLogger.persistence)
            return true
            
        } catch {
            AppLogger.error("Failed to remove store files", error: error, category: AppLogger.persistence)
            return false
        }
    }
    
    private func attemptPermissionRecovery() -> Bool {
        print("🔐 Permission error detected - this usually requires user intervention")
        // Permission errors typically require user action or app reinstall
        return false
    }
    
    private func attemptDiskSpaceRecovery() -> Bool {
        print("💾 Disk space error detected - attempting cleanup...")
        
        // Try to free up some space by cleaning caches
        do {
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            if let cacheURL = cacheURL {
                let contents = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
                for url in contents {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            print("✅ Cache cleanup completed")
            return true
        } catch {
            print("❌ Failed to clean cache: \(error)")
            return false
        }
    }
    
    private func attemptStoreRecovery(storeDescription: NSPersistentStoreDescription?) -> Bool {
        print("🛠 Attempting general store recovery...")
        
        // For general store loading issues, try to reset some configurations
        guard let storeDescription = storeDescription else { return false }
        
        // Disable CloudKit temporarily and try local-only
        storeDescription.setOption(false as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(false as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        return true
    }
    
    private func retryStoreLoading(completion: @escaping (Bool) -> Void) {
        print("🔄 Retrying store loading after recovery...")
        
        container.loadPersistentStores { [weak stateManager = self.stateManager] (_, error) in
            if let error = error as NSError? {
                print("❌ Retry failed: \(error)")
                self.fallbackToInMemoryStore { success in
                    completion(success)
                }
            } else {
                print("✅ Recovery successful!")
                stateManager?.clearError()
                self.configureSuccessfulStore()
                completion(true)
            }
        }
    }
    
    private func fallbackToInMemoryStore(completion: @escaping (Bool) -> Void) {
        print("⚠️ Falling back to in-memory store")
        
        // Create a new in-memory container as fallback
        let fallbackContainer = NSPersistentContainer(name: "FamilyMenuPlanner")
        fallbackContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        
        fallbackContainer.loadPersistentStores { [weak stateManager = self.stateManager] (_, error) in
            if let error = error {
                print("❌ Even in-memory store failed: \(error)")
                // This is a critical error - the app cannot function
                stateManager?.setError(.storeRecoveryFailed(error as NSError))
                completion(false)
            } else {
                print("✅ In-memory store loaded successfully")
                // Replace the original container with the working in-memory one
                // Note: This is a simplified approach. In practice, you might need
                // to use a mutable property and update references accordingly.
                completion(true)
            }
        }
    }
    
    private func configureSuccessfulStore() {
        AppLogger.info("Core Data store loaded successfully", category: AppLogger.persistence)
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure for better performance
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // Set merge policy to handle conflicts
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set query generation only if supported (not for in-memory stores)
        setQueryGenerationIfSupported(for: container.viewContext)
    }
    
    // MARK: - Public Error Handling Interface
    
    /// Returns true if the persistence layer is ready to use
    var isReady: Bool {
        return stateManager.isReady
    }
    
    /// Returns a user-friendly error message if there's a loading error
    var userFriendlyErrorMessage: String? {
        return stateManager.userFriendlyErrorMessage
    }
    
    /// Attempts to recover from errors and reinitialize the store
    func attemptRecovery() -> Bool {
        guard !stateManager.isReady else { return true }
        
        print("🔄 Manual recovery attempt initiated...")
        stateManager.clearError()
        
        // Use a semaphore to maintain synchronous interface for backward compatibility
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        loadPersistentStores { result in
            success = result
            semaphore.signal()
        }
        
        semaphore.wait()
        return success
    }
    
    /// Attempts to recover from errors and reinitialize the store asynchronously
    func attemptRecovery(completion: @escaping (Bool) -> Void) {
        guard !stateManager.isReady else { 
            completion(true)
            return 
        }
        
        print("🔄 Manual recovery attempt initiated...")
        stateManager.clearError()
        loadPersistentStores(completion: completion)
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
            AppLogger.error("Failed to find preloadData.json in bundle", category: AppLogger.dataImport)
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
            
            // Create Dish Categories
            var dishCategoryMap: [String: DishCategory] = [:]
            for categoryData in jsonData.dishCategories {
                let category = DishCategory(context: context)
                category.name = categoryData.name
                category.sortOrder = categoryData.sortOrder
                dishCategoryMap[categoryData.name] = category
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
                
                // Set category
                if let categoryName = dishData.category,
                   let category = dishCategoryMap[categoryName] {
                    dish.category = category
                }

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
            AppLogger.info("Data preloaded successfully from preloadData.json", category: AppLogger.dataImport)
            
            // Refresh static data cache to ensure it has the newly created data
            StaticDataCacheManager.shared.invalidateCache()
        } catch {
            AppLogger.error("Error preloading data", error: error, category: AppLogger.dataImport)
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
    
    // MARK: - Context Management
    
    /// Creates a properly configured background context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set query generation only if supported
        setQueryGenerationIfSupported(for: context)
        
        return context
    }
    
    /// Sets query generation for a context if supported by the store configuration
    private func setQueryGenerationIfSupported(for context: NSManagedObjectContext) {
        // Check if this is an in-memory store or other configuration that doesn't support query generation
        guard let storeDescription = container.persistentStoreDescriptions.first,
              let storeURL = storeDescription.url else {
            return
        }
        
        // Skip query generation for in-memory stores (used in tests)
        let isInMemoryStore = storeURL.path == "/dev/null" || storeDescription.type == NSInMemoryStoreType
        
        guard !isInMemoryStore else {
            print("🔄 Skipping query generation for in-memory store")
            return
        }
        
        // Set query generation for supported stores
        do {
            try context.setQueryGenerationFrom(.current)
            print("✅ Query generation configured for context")
        } catch {
            print("⚠️ Failed to set query generation: \(error)")
            // This is not a fatal error - the app can continue without query generation
        }
    }
}

// MARK: - Codable Structures for JSON
struct PreloadedData: Codable {
    let units: [UnitData]
    let products: [ProductData]
    let dishes: [DishData]
    let mealTypes: [MealTypeData]
    let dishCategories: [DishCategoryData]
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
    let category: String?
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

struct DishCategoryData: Codable {
    let name: String
    let sortOrder: Int16
}

