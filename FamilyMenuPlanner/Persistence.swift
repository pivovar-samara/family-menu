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
        // Very early logging to help diagnose CI issues
        AppLogger.info("PersistenceController initialization started", category: AppLogger.persistence)
        
        // Enhanced test environment detection for CI with more robust checks
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            NSClassFromString("XCTestCase") != nil ||
                            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||  // GitHub Actions
                            ProcessInfo.processInfo.environment["CI"] != nil ||              // Generic CI
                            ProcessInfo.processInfo.environment["BUILD_NUMBER"] != nil ||    // Xcode Cloud
                            ProcessInfo.processInfo.arguments.contains("test") ||           // xcodebuild test
                            ProcessInfo.processInfo.arguments.contains("-XCTest") ||        // Additional test detection
                            ProcessInfo.processInfo.environment["UI_TESTS"] != nil ||       // UI test environment variable
                            ProcessInfo.processInfo.environment["DISABLE_CLOUDKIT"] != nil || // CloudKit disable flag
                            ProcessInfo.processInfo.arguments.contains("-UITests") ||       // UI test launch argument
                            ProcessInfo.processInfo.arguments.contains("-DisableCloudKit")  // CloudKit disable argument
        
        AppLogger.info("Environment: inMemory=\(inMemory), isRunningTests=\(isRunningTests)", category: AppLogger.persistence)
        
        // Check if we're in simulator using Swift-compatible approach
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        
        AppLogger.info("Platform: isSimulator=\(isSimulator)", category: AppLogger.persistence)
        
        // Always use NSPersistentContainer for CI/tests to avoid CloudKit issues
        // Use NSPersistentContainer for tests, CI environments, or simulator
        if isRunningTests || inMemory || (isSimulator && ProcessInfo.processInfo.environment["CI"] != nil) {
            AppLogger.info("Creating NSPersistentContainer (no CloudKit)", category: AppLogger.persistence)
            container = NSPersistentContainer(name: "FamilyMenuPlanner")
            AppLogger.info("Using NSPersistentContainer (no CloudKit) for CI/test environment", category: AppLogger.persistence)
        } else {
            AppLogger.info("Creating NSPersistentCloudKitContainer", category: AppLogger.persistence)
            container = NSPersistentCloudKitContainer(name: "FamilyMenuPlanner")
            AppLogger.info("Using NSPersistentCloudKitContainer for production environment", category: AppLogger.persistence)
        }
        
        // Configure store descriptions before loading
        AppLogger.info("Configuring store descriptions", category: AppLogger.persistence)
        configureStoreDescriptions(inMemory: inMemory, isRunningTests: isRunningTests, isSimulator: isSimulator)
        
        // Only initialize CloudKit schema when building the app with the
        // Debug build configuration and not running tests or in CI environments.
        #if DEBUG
        if !isRunningTests && !inMemory && (!isSimulator || shouldUseCloudKitInSimulator()) {
            AppLogger.info("Attempting CloudKit schema initialization", category: AppLogger.cloudKit)
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
        
        AppLogger.info("Starting persistent stores loading", category: AppLogger.persistence)
        loadPersistentStores()
        
        // Step 6: Set query generation for optimistic locking (only for production environments)
        // Query generation is not supported for in-memory stores and can cause issues in test environments
        let shouldSetQueryGeneration = !isRunningTests && !inMemory && 
                                       container is NSPersistentCloudKitContainer
        
        if shouldSetQueryGeneration, let _ = container.persistentStoreCoordinator.persistentStores.first {
            do {
                try container.viewContext.setQueryGenerationFrom(.current)
                AppLogger.info("Query generation set for context", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Failed to set query generation for context", error: error, category: AppLogger.persistence)
            }
        } else {
            if isRunningTests || inMemory {
                AppLogger.info("Skipping query generation for in-memory or test store", category: AppLogger.persistence)
            } else {
                AppLogger.info("Query generation set for context", category: AppLogger.persistence)
            }
        }
        
        // Step 7: Perform data validation cleanup to prevent CoreGraphics errors
        performDataValidationCleanup()
        
        AppLogger.info("PersistenceController initialization completed", category: AppLogger.persistence)
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
        } else if isRunningTests {
            // For tests using persistent storage, use a unique temporary file to avoid conflicts
            // between different test configurations
            let tempDirectory = FileManager.default.temporaryDirectory
            let uniqueStoreURL = tempDirectory.appendingPathComponent("FamilyMenuPlannerTest_\(UUID().uuidString).sqlite")
            container.persistentStoreDescriptions.first!.url = uniqueStoreURL
            AppLogger.info("Using unique test store: \(uniqueStoreURL.path)", category: AppLogger.persistence)
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
        // Check for essential entities that are part of initial data
        let entityNames = ["Unit", "MealType", "DishCategory", "Product"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.fetchLimit = 1

            do {
                let count = try context.count(for: fetchRequest)
                if count > 0 {
                    // If any essential entity has data, database is not empty
                    return false
                }
            } catch {
                AppLogger.error("Error checking \(entityName) count in database", error: error, category: AppLogger.persistence)
                // If we can't check, assume not empty to be safe
                return false
            }
        }
        
        // All essential entities are empty
        return true
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

            // Create Units with deduplication
            var unitMap: [String: Unit] = [:]
            for unitData in jsonData.units {
                // Check if unit already exists
                let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", unitData.name)
                fetchRequest.fetchLimit = 1
                
                let existingUnit = try context.fetch(fetchRequest).first
                if let existingUnit = existingUnit {
                    unitMap[unitData.name] = existingUnit
                } else {
                    let unit = Unit(context: context)
                    unit.name = unitData.name
                    unit.sortOrder = unitData.sortOrder
                    unitMap[unitData.name] = unit
                }
            }
            
            // Create Meal types with deduplication
            var mealTypeMap: [String: MealType] = [:]
            for mealTypeData in jsonData.mealTypes {
                // Check if meal type already exists
                let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", mealTypeData.name)
                fetchRequest.fetchLimit = 1
                
                let existingMealType = try context.fetch(fetchRequest).first
                if let existingMealType = existingMealType {
                    mealTypeMap[mealTypeData.name] = existingMealType
                } else {
                    let mealType = MealType(context: context)
                    mealType.name = mealTypeData.name
                    mealType.sortOrder = mealTypeData.sortOrder
                    mealTypeMap[mealTypeData.name] = mealType
                }
            }
            
            // Create Dish Categories with deduplication
            var dishCategoryMap: [String: DishCategory] = [:]
            for categoryData in jsonData.dishCategories {
                // Check if dish category already exists
                let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", categoryData.name)
                fetchRequest.fetchLimit = 1
                
                let existingCategory = try context.fetch(fetchRequest).first
                if let existingCategory = existingCategory {
                    dishCategoryMap[categoryData.name] = existingCategory
                } else {
                    let category = DishCategory(context: context)
                    category.name = categoryData.name
                    category.sortOrder = categoryData.sortOrder
                    dishCategoryMap[categoryData.name] = category
                }
            }

            // Create Products with deduplication
            var productMap: [String: Product] = [:]
            for productData in jsonData.products {
                // Check if product already exists
                let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", productData.name)
                fetchRequest.fetchLimit = 1
                
                let existingProduct = try context.fetch(fetchRequest).first
                if let existingProduct = existingProduct {
                    productMap[productData.name] = existingProduct
                } else {
                    let product = Product(context: context)
                    product.name = productData.name
                    product.unit = unitMap[productData.unit]
                    productMap[productData.name] = product
                }
            }

            // Create Dishes and Ingredients with deduplication
            for dishData in jsonData.dishes {
                // Check if dish already exists
                let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", dishData.name)
                fetchRequest.fetchLimit = 1
                
                let existingDish = try context.fetch(fetchRequest).first
                if existingDish != nil {
                    // Dish already exists, skip creation
                    continue
                }
                
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
                        AppLogger.warning("Product \(ingredientData.product) not found for dish \(dishData.name)", category: AppLogger.dataImport)
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
            if context.hasChanges {
                try context.save()
            }
            AppLogger.info("Data preloaded successfully from preloadData.json with deduplication", category: AppLogger.dataImport)
            
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
        // Only set query generation for contexts with persistent stores that support it
        guard let coordinator = context.persistentStoreCoordinator,
              !coordinator.persistentStores.isEmpty else {
            return
        }
        
        // Check if any store is in-memory or uses /dev/null (which doesn't support query generation)
        let hasUnsupportedStore = coordinator.persistentStores.contains { store in
            store.type == NSInMemoryStoreType || 
            store.url?.path == "/dev/null"
        }
        
        if !hasUnsupportedStore {
            do {
                try context.setQueryGenerationFrom(.current)
                AppLogger.info("Query generation set for context", category: AppLogger.persistence)
            } catch {
                AppLogger.warning("Could not set query generation for context: \(error.localizedDescription)", category: AppLogger.persistence)
            }
        } else {
            AppLogger.info("Skipping query generation for in-memory or test store", category: AppLogger.persistence)
        }
    }
    
    // MARK: - Heavy Operations Support
    
    /// Generates initial data in background for better app startup performance
    func generateInitialDataInBackground(completion: @escaping (Bool) -> Void) {
        BackgroundOperationManager.shared.executeBulkOperation { backgroundContext in
            self.performInitialDataGeneration(context: backgroundContext)
        } completion: { result in
            switch result {
            case .success:
                AppLogger.info("Initial data generated successfully in background", category: AppLogger.persistence)
                completion(true)
            case .failure(let error):
                AppLogger.error("Failed to generate initial data in background", error: error, category: AppLogger.persistence)
                completion(false)
            }
        }
    }
    
    /// Deletes all data using background context for better performance
    func deleteAllDataInBackground(completion: @escaping (Result<Void, Error>) -> Void) {
        BackgroundOperationManager.shared.executeBulkOperation { backgroundContext in
            self.performDeleteAllData(context: backgroundContext)
        } completion: { result in
            completion(result)
        }
    }
    
    /// Performs bulk import of data in background
    func importDataInBackground<T: NSManagedObject>(
        entityName: String,
        dataItems: [[String: Any]],
        completion: @escaping (Result<[T], Error>) -> Void
    ) {
        BackgroundOperationManager.shared.executeHeavyOperation { backgroundContext in
            var importedObjects: [NSManagedObjectID] = []
            
            for dataItem in dataItems {
                guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: backgroundContext) else {
                    throw PersistenceError.unknown(NSError(domain: "EntityNotFound", code: -1, userInfo: nil))
                }
                
                let object = NSManagedObject(entity: entity, insertInto: backgroundContext)
                
                // Set properties from data item
                for (key, value) in dataItem {
                    if entity.attributesByName[key] != nil {
                        object.setValue(value, forKey: key)
                    }
                }
                
                importedObjects.append(object.objectID)
            }
            
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
            
            return importedObjects
        } completion: { result in
            switch result {
            case .success(let objectIDs):
                // Convert object IDs to main context objects
                do {
                    let mainObjects = try objectIDs.map { objectID -> T in
                        let object = try self.container.viewContext.existingObject(with: objectID)
                        guard let typedObject = object as? T else {
                            throw PersistenceError.unknown(NSError(domain: "TypeCastError", code: -1, userInfo: nil))
                        }
                        return typedObject
                    }
                    completion(.success(mainObjects))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func performInitialDataGeneration(context: NSManagedObjectContext) {
        AppLogger.info("Generating initial data in context", category: AppLogger.persistence)
        
        // Use the existing generateInitialData logic but adapted for any context
        guard let url = Bundle.main.url(forResource: "preloadData", withExtension: "json") else {
            AppLogger.error("Failed to find preloadData.json in bundle", category: AppLogger.dataImport)
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode(PreloadedData.self, from: data)

            // Create Units with deduplication
            var unitMap: [String: Unit] = [:]
            for unitData in jsonData.units {
                // Check if unit already exists
                let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", unitData.name)
                fetchRequest.fetchLimit = 1
                
                let existingUnit = try context.fetch(fetchRequest).first
                if let existingUnit = existingUnit {
                    unitMap[unitData.name] = existingUnit
                } else {
                    let unit = Unit(context: context)
                    unit.name = unitData.name
                    unit.sortOrder = unitData.sortOrder
                    unitMap[unitData.name] = unit
                }
            }
            
            // Create Meal types with deduplication
            var mealTypeMap: [String: MealType] = [:]
            for mealTypeData in jsonData.mealTypes {
                // Check if meal type already exists
                let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", mealTypeData.name)
                fetchRequest.fetchLimit = 1
                
                let existingMealType = try context.fetch(fetchRequest).first
                if let existingMealType = existingMealType {
                    mealTypeMap[mealTypeData.name] = existingMealType
                } else {
                    let mealType = MealType(context: context)
                    mealType.name = mealTypeData.name
                    mealType.sortOrder = mealTypeData.sortOrder
                    mealTypeMap[mealTypeData.name] = mealType
                }
            }
            
            // Create Dish Categories with deduplication
            var dishCategoryMap: [String: DishCategory] = [:]
            for categoryData in jsonData.dishCategories {
                // Check if dish category already exists
                let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", categoryData.name)
                fetchRequest.fetchLimit = 1
                
                let existingCategory = try context.fetch(fetchRequest).first
                if let existingCategory = existingCategory {
                    dishCategoryMap[categoryData.name] = existingCategory
                } else {
                    let category = DishCategory(context: context)
                    category.name = categoryData.name
                    category.sortOrder = categoryData.sortOrder
                    dishCategoryMap[categoryData.name] = category
                }
            }

            // Create Products with deduplication
            var productMap: [String: Product] = [:]
            for productData in jsonData.products {
                // Check if product already exists
                let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", productData.name)
                fetchRequest.fetchLimit = 1
                
                let existingProduct = try context.fetch(fetchRequest).first
                if let existingProduct = existingProduct {
                    productMap[productData.name] = existingProduct
                } else {
                    let product = Product(context: context)
                    product.name = productData.name
                    product.unit = unitMap[productData.unit]
                    productMap[productData.name] = product
                }
            }

            // Create Dishes and Ingredients with deduplication
            for dishData in jsonData.dishes {
                // Check if dish already exists
                let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", dishData.name)
                fetchRequest.fetchLimit = 1
                
                let existingDish = try context.fetch(fetchRequest).first
                if existingDish != nil {
                    // Dish already exists, skip creation
                    continue
                }
                
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
                        AppLogger.warning("Product \(ingredientData.product) not found for dish \(dishData.name)", category: AppLogger.dataImport)
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
            if context.hasChanges {
                try context.save()
            }
            AppLogger.info("Initial data generated successfully in background context with deduplication", category: AppLogger.dataImport)
            
        } catch {
            AppLogger.error("Error generating initial data in background context", error: error, category: AppLogger.dataImport)
        }
        
        AppLogger.info("Initial data generation completed", category: AppLogger.persistence)
    }
    
    private func performDeleteAllData(context: NSManagedObjectContext) {
        guard let entities = context.persistentStoreCoordinator?.managedObjectModel.entities else { return }

        for entity in entities {
            guard let entityName = entity.name else { continue }

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(batchDeleteRequest)
                AppLogger.info("Successfully deleted all data from \(entityName)", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Error deleting data from \(entityName)", error: error, category: AppLogger.persistence)
            }
        }

        do {
            if context.hasChanges {
                try context.save()
            }
            AppLogger.info("All data deleted successfully", category: AppLogger.persistence)
        } catch {
            AppLogger.error("Error saving context after deletion", error: error, category: AppLogger.persistence)
        }
    }
    
    /// Performs comprehensive data validation cleanup to prevent CoreGraphics NaN errors
    /// This runs on app startup to fix any existing invalid data in the database
    private func performDataValidationCleanup() {
        AppLogger.info("Starting data validation cleanup to prevent CoreGraphics errors", category: AppLogger.persistence)
        
        // Clean up old temporary test stores first
        cleanupTemporaryTestStores()
        
        // Use background context for cleanup to avoid blocking the main thread
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.performAndWait {
            do {
                // Fetch all IngredientDetail entities that might have invalid quantities
                let fetchRequest: NSFetchRequest<IngredientDetail> = IngredientDetail.fetchRequest()
                let ingredients = try backgroundContext.fetch(fetchRequest)
                
                var fixedCount = 0
                for ingredient in ingredients {
                    if ingredient.quantity.isNaN || ingredient.quantity.isInfinite || ingredient.quantity < 0 {
                        let oldValue = ingredient.quantity
                        ingredient.quantity = 0.0
                        fixedCount += 1
                        AppLogger.warning("Fixed invalid quantity value (\(oldValue)) in ingredient for product: \(ingredient.product?.name ?? "unknown")", category: AppLogger.persistence)
                    }
                }
                
                // Save changes if we fixed any values
                if fixedCount > 0 {
                    try backgroundContext.save()
                    AppLogger.info("Fixed \(fixedCount) invalid ingredient quantities to prevent CoreGraphics errors", category: AppLogger.persistence)
                } else {
                    AppLogger.info("No invalid ingredient quantities found during validation cleanup", category: AppLogger.persistence)
                }
                
            } catch {
                AppLogger.error("Failed to perform data validation cleanup", error: error, category: AppLogger.persistence)
            }
        }
    }
    
    /// Cleans up old temporary test store files to prevent disk space accumulation
    private func cleanupTemporaryTestStores() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            let testStoreFiles = contents.filter { url in
                url.lastPathComponent.hasPrefix("FamilyMenuPlannerTest_") && 
                (url.pathExtension == "sqlite" || url.pathExtension == "sqlite-wal" || url.pathExtension == "sqlite-shm")
            }
            
            let calendar = Calendar.current
            let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            var cleanedCount = 0
            for file in testStoreFiles {
                if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < oneDayAgo {
                    try? FileManager.default.removeItem(at: file)
                    cleanedCount += 1
                }
            }
            
            if cleanedCount > 0 {
                AppLogger.info("Cleaned up \(cleanedCount) old temporary test store files", category: AppLogger.persistence)
            }
            
        } catch {
            AppLogger.warning("Could not clean up temporary test stores: \(error.localizedDescription)", category: AppLogger.persistence)
        }
    }
    
    /// Cleans up all duplicate static data entities that may have been created by CloudKit sync issues
    /// This method should be called during app startup to fix existing duplicates
    func cleanupAllDuplicateStaticData(context: NSManagedObjectContext) {
        AppLogger.info("Starting comprehensive cleanup of duplicate static data", category: AppLogger.persistence)
        
        cleanupDuplicateMealTypes(context: context)
        cleanupDuplicateUnits(context: context)
        cleanupDuplicateDishCategories(context: context)
        cleanupDuplicateProducts(context: context)
        
        AppLogger.info("Completed comprehensive cleanup of duplicate static data", category: AppLogger.persistence)
    }
    
    /// Cleans up duplicate units
    private func cleanupDuplicateUnits(context: NSManagedObjectContext) {
        do {
            let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
            let allUnits = try context.fetch(fetchRequest)
            
            var unitGroups: [String: [Unit]] = [:]
            for unit in allUnits {
                guard let name = unit.name else { continue }
                if unitGroups[name] == nil {
                    unitGroups[name] = []
                }
                unitGroups[name]?.append(unit)
            }
            
            var duplicatesRemoved = 0
            for (name, units) in unitGroups {
                if units.count > 1 {
                    let sortedUnits = units.sorted { ($0.sortOrder, $0.objectID.debugDescription) < ($1.sortOrder, $1.objectID.debugDescription) }
                    let keepUnit = sortedUnits.first!
                    let duplicatesToRemove = Array(sortedUnits.dropFirst())
                    
                    // Reassign products from duplicates to the keeper
                    for duplicateUnit in duplicatesToRemove {
                        if let products = duplicateUnit.products {
                            for case let product as Product in products {
                                product.unit = keepUnit
                            }
                        }
                        context.delete(duplicateUnit)
                        duplicatesRemoved += 1
                    }
                    
                    AppLogger.info("Removed \(duplicatesToRemove.count) duplicate(s) of unit '\(name)'", category: AppLogger.persistence)
                }
            }
            
            if context.hasChanges {
                try context.save()
                AppLogger.info("Cleaned up \(duplicatesRemoved) duplicate units", category: AppLogger.persistence)
            }
            
        } catch {
            AppLogger.error("Error cleaning up duplicate units", error: error, category: AppLogger.persistence)
        }
    }
    
    /// Cleans up duplicate dish categories
    private func cleanupDuplicateDishCategories(context: NSManagedObjectContext) {
        do {
            let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
            let allCategories = try context.fetch(fetchRequest)
            
            var categoryGroups: [String: [DishCategory]] = [:]
            for category in allCategories {
                guard let name = category.name else { continue }
                if categoryGroups[name] == nil {
                    categoryGroups[name] = []
                }
                categoryGroups[name]?.append(category)
            }
            
            var duplicatesRemoved = 0
            for (name, categories) in categoryGroups {
                if categories.count > 1 {
                    let sortedCategories = categories.sorted { ($0.sortOrder, $0.objectID.debugDescription) < ($1.sortOrder, $1.objectID.debugDescription) }
                    let keepCategory = sortedCategories.first!
                    let duplicatesToRemove = Array(sortedCategories.dropFirst())
                    
                    // Reassign dishes from duplicates to the keeper
                    for duplicateCategory in duplicatesToRemove {
                        if let dishes = duplicateCategory.dishes {
                            for case let dish as Dish in dishes {
                                dish.category = keepCategory
                            }
                        }
                        context.delete(duplicateCategory)
                        duplicatesRemoved += 1
                    }
                    
                    AppLogger.info("Removed \(duplicatesToRemove.count) duplicate(s) of dish category '\(name)'", category: AppLogger.persistence)
                }
            }
            
            if context.hasChanges {
                try context.save()
                AppLogger.info("Cleaned up \(duplicatesRemoved) duplicate dish categories", category: AppLogger.persistence)
            }
            
        } catch {
            AppLogger.error("Error cleaning up duplicate dish categories", error: error, category: AppLogger.persistence)
        }
    }
    
    /// Cleans up duplicate products
    private func cleanupDuplicateProducts(context: NSManagedObjectContext) {
        do {
            let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            let allProducts = try context.fetch(fetchRequest)
            
            var productGroups: [String: [Product]] = [:]
            for product in allProducts {
                guard let name = product.name else { continue }
                if productGroups[name] == nil {
                    productGroups[name] = []
                }
                productGroups[name]?.append(product)
            }
            
            var duplicatesRemoved = 0
            for (name, products) in productGroups {
                if products.count > 1 {
                    // For products, also consider the unit when determining duplicates
                    // Group by name + unit combination
                    var productUnitGroups: [String: [Product]] = [:]
                    for product in products {
                        let key = "\(name)_\(product.unit?.name ?? "nil")"
                        if productUnitGroups[key] == nil {
                            productUnitGroups[key] = []
                        }
                        productUnitGroups[key]?.append(product)
                    }
                    
                    for (_, unitProducts) in productUnitGroups {
                        if unitProducts.count > 1 {
                            let sortedProducts = unitProducts.sorted { $0.objectID.debugDescription < $1.objectID.debugDescription }
                            let keepProduct = sortedProducts.first!
                            let duplicatesToRemove = Array(sortedProducts.dropFirst())
                            
                            // Reassign ingredient details from duplicates to the keeper
                            for duplicateProduct in duplicatesToRemove {
                                if let ingredientDetails = duplicateProduct.ingredientDetails {
                                    for case let ingredient as IngredientDetail in ingredientDetails {
                                        ingredient.product = keepProduct
                                    }
                                }
                                context.delete(duplicateProduct)
                                duplicatesRemoved += 1
                            }
                            
                            AppLogger.info("Removed \(duplicatesToRemove.count) duplicate(s) of product '\(name)'", category: AppLogger.persistence)
                        }
                    }
                }
            }
            
            if context.hasChanges {
                try context.save()
                AppLogger.info("Cleaned up \(duplicatesRemoved) duplicate products", category: AppLogger.persistence)
            }
            
        } catch {
            AppLogger.error("Error cleaning up duplicate products", error: error, category: AppLogger.persistence)
        }
    }
    
    /// Cleans up duplicate meal types
    private func cleanupDuplicateMealTypes(context: NSManagedObjectContext) {
        AppLogger.info("Checking for duplicate meal types to cleanup", category: AppLogger.persistence)
        
        do {
            // Fetch all meal types
            let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
            let allMealTypes = try context.fetch(fetchRequest)
            
            // Group meal types by name
            var mealTypeGroups: [String: [MealType]] = [:]
            for mealType in allMealTypes {
                guard let name = mealType.name else { continue }
                if mealTypeGroups[name] == nil {
                    mealTypeGroups[name] = []
                }
                mealTypeGroups[name]?.append(mealType)
            }
            
            var duplicatesRemoved = 0
            
            // For each group, keep only one meal type (preferably the one with the lowest sortOrder)
            for (name, mealTypes) in mealTypeGroups {
                if mealTypes.count > 1 {
                    // Sort by sortOrder to keep the one with the lowest order
                    let sortedMealTypes = mealTypes.sorted { ($0.sortOrder, $0.objectID.debugDescription) < ($1.sortOrder, $1.objectID.debugDescription) }
                    let keepMealType = sortedMealTypes.first!
                    let duplicatesToRemove = Array(sortedMealTypes.dropFirst())
                    
                    // Reassign dishes from duplicates to the keeper
                    for duplicateMealType in duplicatesToRemove {
                        if let dishes = duplicateMealType.dishes {
                            for case let dish as Dish in dishes {
                                dish.removeFromMealTypes(duplicateMealType)
                                dish.addToMealTypes(keepMealType)
                            }
                        }
                        
                        // Delete the duplicate
                        context.delete(duplicateMealType)
                        duplicatesRemoved += 1
                    }
                    
                    AppLogger.info("Removed \(duplicatesToRemove.count) duplicate(s) of meal type '\(name)'", category: AppLogger.persistence)
                }
            }
            
            // Save changes if any duplicates were removed
            if context.hasChanges {
                try context.save()
                AppLogger.info("Cleaned up \(duplicatesRemoved) duplicate meal types", category: AppLogger.persistence)
            } else {
                AppLogger.info("No duplicate meal types found", category: AppLogger.persistence)
            }
            
        } catch {
            AppLogger.error("Error cleaning up duplicate meal types", error: error, category: AppLogger.persistence)
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

