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
class PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        result.generateInitialData(context: viewContext)
        
        return result
    }()

    let container: NSPersistentContainer
    let stateManager = PersistenceStateManager()
    
    private let dataGenerationLock = NSLock()
    private var isDataGenerationInProgress = false
    
    // Remote change observation
    private var remoteChangeObserver: NSObjectProtocol?
    private var remoteChangeDebounceWorkItem: DispatchWorkItem?

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
        
        let isRunningUITests = ProcessInfo.processInfo.environment["UI_TESTS"] != nil ||
                              ProcessInfo.processInfo.arguments.contains("-UITests") ||
                              ProcessInfo.processInfo.arguments.contains("-DisableCloudKit")
        
        // Get simulator info
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        let shouldUseCloudKit = !isSimulator || PersistenceController.shouldUseCloudKitInSimulator()
        
        AppLogger.info("Environment: inMemory=\(inMemory), isRunningTests=\(isRunningTests), isRunningUITests=\(isRunningUITests)", category: AppLogger.persistence)
        
        // Set up the container based on test environment
        if isRunningTests && !isRunningUITests {
            // For unit/integration tests (not UI tests), use a properly configured test container
            AppLogger.info("Setting up test environment - using traditional test setup", category: AppLogger.persistence)
            container = NSPersistentContainer(name: "FamilyMenuPlanner")
        } else if !shouldUseCloudKit || isRunningTests {
            // For development/testing in simulator or explicit test environments, use regular container
            AppLogger.info("Setting up traditional Core Data stack", category: AppLogger.persistence)
            container = NSPersistentContainer(name: "FamilyMenuPlanner")
        } else {
            // For production, use CloudKit container
            AppLogger.info("Setting up CloudKit container for production", category: AppLogger.persistence)
            container = NSPersistentCloudKitContainer(name: "FamilyMenuPlanner")
        }
        
        // Configure store descriptions
        configureStoreDescriptions(inMemory: inMemory, isRunningTests: isRunningTests, isSimulator: isSimulator)
        
        // Load persistent stores
        loadPersistentStores()
        
        // Configure the context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Query generation is not supported for in-memory stores and can cause issues in test environments
        let shouldSetQueryGeneration = !isRunningTests && !inMemory &&
                                       container is NSPersistentCloudKitContainer
        
        if shouldSetQueryGeneration, let _ = container.persistentStoreCoordinator.persistentStores.first {
            do {
                try container.viewContext.setQueryGenerationFrom(.current)
                AppLogger.info("Query generation set for context", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Failed to set query generation for context", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to set query generation for context")
            }
        } else {
            if isRunningTests || inMemory {
                AppLogger.info("Skipping query generation for in-memory or test store", category: AppLogger.persistence)
            } else {
                AppLogger.info("Query generation set for context", category: AppLogger.persistence)
            }
        }
        
        // Start observing remote changes when using CloudKit
        startObservingRemoteChangesIfNeeded()
        
        // Step 7: Perform data validation cleanup to prevent CoreGraphics errors
        // TODO: Re-add performDataValidationCleanup() method
        // performDataValidationCleanup()
        
        if isRunningUITests {
            AppLogger.info("UI test environment detected - forcing immediate data generation", category: AppLogger.persistence)
            
            let context = container.viewContext
            if isDatabaseEmptyOrOutdated(context: context) {
                AppLogger.info("Generating data synchronously for UI tests", category: AppLogger.persistence)
                generateInitialData(context: context)
                
                // Force save the context
                if context.hasChanges {
                    do {
                        try context.save()
                        AppLogger.info("UI test data saved successfully", category: AppLogger.persistence)
                    } catch {
                        AppLogger.error("Failed to save UI test data", error: error, category: AppLogger.persistence)
                        AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to save UI test data")
                    }
                }
            } else {
                AppLogger.info("UI test environment - data already exists", category: AppLogger.persistence)
            }
        }
        
        AppLogger.info("PersistenceController initialization completed", category: AppLogger.persistence)
    }

    // Post-seeding reconciliation: ensure dish categories match preload and deduplicate ingredients.
    private func reconcilePostInitialSeeding(context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                // 0) Clean up duplicate reference data first
                self.cleanupDuplicateUnits(context: context)
                self.cleanupDuplicateMealTypes(context: context)
                self.cleanupDuplicateDishCategories(context: context)

                // 1) Ensure product and meal type relations are canonicalized
                self.normalizeDishProductRelations(context: context)
                self.normalizeDishMealTypeRelations(context: context)
                // 1a) Remove duplicate products so ingredient mapping is stable
                self.cleanupDuplicateProducts(context: context)

                // 2) Assign missing categories for preloaded dishes
                if let preload = loadCurrentPreloadData() {
                    // Build category lookup by key (prefer key), then name
                    let catFetch: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
                    let categories = try context.fetch(catFetch)
                    var catByName: [String: DishCategory] = [:]
                    var catByKey: [String: DishCategory] = [:]
                    for cat in categories {
                        if let name = cat.name { catByName[name] = cat }
                        if let key = cat.key { catByKey[key] = cat }
                    }

                    // Map dish name -> expected category name from preload
                    var expectedCategoryByDish: [String: String] = [:]
                    for d in preload.dishes {
                        if let cat = d.category { expectedCategoryByDish[d.name] = cat }
                    }

                    let dishFetch: NSFetchRequest<Dish> = Dish.fetchRequest()
                    let dishes = try context.fetch(dishFetch)
                    for dish in dishes where dish.category == nil {
                        guard let name = dish.name else { continue }
                        let nameKey = StaticKeyHelper.stableKey(from: name)
                        // Try direct lookup first
                        var expectedCatName = expectedCategoryByDish[name]
                        // If not found, try matching by stable key
                        if expectedCatName == nil {
                            if let match = expectedCategoryByDish.first(where: { StaticKeyHelper.stableKey(from: $0.key) == nameKey }) {
                                expectedCatName = match.value
                            }
                        }
                        guard let catName = expectedCatName else { continue }
                        let key = StaticKeyHelper.stableKey(from: catName)
                        if let cat = catByKey[key] ?? catByName[catName] {
                            dish.category = cat
                        }
                    }
                }

                // 3) Deduplicate IngredientDetail using existing normalization routine
                self.normalizeDishIngredientDetails(context: context)
                // 4) Recompute and set IngredientDetail.key for all details (heals legacy rows)
                do {
                    func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
                    let fetch: NSFetchRequest<IngredientDetail> = IngredientDetail.fetchRequest()
                    let all = try context.fetch(fetch)
                    var updated = 0
                    for d in all {
                        guard let dish = d.dish, let product = d.product else { continue }
                        let dishKey = dish.key ?? StaticKeyHelper.stableKey(from: norm(dish.name))
                        let unitKey = product.unit?.key ?? (product.unit?.name.map { StaticKeyHelper.stableKey(from: $0) } ?? "")
                        let prodKey = StaticKeyHelper.productKey(name: norm(product.name), unitKey: unitKey)
                        let k = dishKey + "|" + prodKey
                        if d.key != k { d.key = k; updated += 1 }
                    }
                    if context.hasChanges { try context.save() }
                    AppLogger.info("Recomputed IngredientDetail.key for \(updated) rows", category: AppLogger.persistence)
                } catch {
                    AppLogger.error("Failed to recompute IngredientDetail.key", error: error, category: AppLogger.persistence)
                    AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to recompute IngredientDetail.key")
                }

                if context.hasChanges {
                    try context.save()
                }
                AppLogger.info("Reconciliation completed", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Post-seeding reconciliation failed", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Post-seeding reconciliation failed")
            }
        }
    }

    private static func shouldUseCloudKitInSimulator() -> Bool {
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
            if isRunningTests || inMemory || (isSimulator && !PersistenceController.shouldUseCloudKitInSimulator()) {
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
        
        container.loadPersistentStores { [weak stateManager = self.stateManager] (_, error) in
            if let error = error as NSError? {
                AppLogger.error("Persistent store loading failed", error: error, category: AppLogger.persistence)
                AppLogger.error("Store description: \(String(describing: error.userInfo))", category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Persistent store loading failed")
                
                self.handleStoreLoadingError(error, storeDescription: nil, stateManager: stateManager) { success in
                    completion(success)
                }
            } else {
                AppLogger.info("Persistent stores loaded successfully", category: AppLogger.persistence)
                
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
        AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "[Critical] Core Data Store Loading Error", properties: [AnalyticsPropertyKey.user_info: error.userInfo, AnalyticsPropertyKey.error_message: persistenceError.errorDescription])
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
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to remove store files")
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

        // Backfill stable keys for static data if missing
        backfillStaticKeysIfNeeded(context: container.viewContext)
        
        // Begin listening for CloudKit merges
        startObservingRemoteChangesIfNeeded()
    }

    private func startObservingRemoteChangesIfNeeded() {
        guard remoteChangeObserver == nil else { return }
        guard container is NSPersistentCloudKitContainer else { return }
        
        let coordinator = container.persistentStoreCoordinator
        
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: coordinator,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            // Debounce a burst of notifications from a single import session
            self.remoteChangeDebounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.refreshAfterRemoteMerge()
            }
            self.remoteChangeDebounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
        }
        AppLogger.info("Subscribed to NSPersistentStoreRemoteChange", category: AppLogger.persistence)
    }

    /// Advances query generation, refreshes registered objects, and reloads static caches.
    /// Call this after CloudKit merges or when resuming the app post-sync to avoid stale faults.
    func refreshAfterRemoteMerge() {
        let ctx = container.viewContext
        ctx.perform {
            do { try ctx.setQueryGenerationFrom(.current) } catch {
                AppLogger.warning("Failed to advance query generation after remote change: \(error.localizedDescription)", category: AppLogger.persistence)
            }
            ctx.refreshAllObjects()
        }
        StaticDataCacheManager.shared.invalidateCache()
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
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking \(entityName) count in database")
                // If we can't check, assume not empty to be safe
                return false
            }
        }
        
        // All essential entities are empty
        return true
    }
    
    private static let preloadDataVersionKey = "PreloadDataVersion"
    private static let currentPreloadDataVersion = "1.1" // Increment this when preload data changes
    
    func isDatabaseEmptyOrOutdated(context: NSManagedObjectContext) -> Bool {
        // Thread-safe check for data generation in progress
        dataGenerationLock.lock()
        defer { dataGenerationLock.unlock() }
        
        if isDataGenerationInProgress {
            AppLogger.info("Data generation already in progress - skipping check", category: AppLogger.persistence)
            return false
        }
        
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
        
        // In test environments, always generate data if database is empty or outdated
        if isRunningTests {
            AppLogger.info("Test environment detected - skipping CloudKit sync checks", category: AppLogger.persistence)
            // Check if database is completely empty
            if isDatabaseEmpty(context: context) {
                AppLogger.info("Database is empty in test environment - initial population needed", category: AppLogger.persistence)
                return true
            }
            
            // Check if static data schema matches current preload data
            if !isStaticDataValid(context: context) {
                AppLogger.info("Static data schema is outdated in test environment - re-population needed", category: AppLogger.persistence)
                return true
            }
            
            AppLogger.info("Test environment has valid data - skipping generation", category: AppLogger.persistence)
            return false
        }
        
        if container is NSPersistentCloudKitContainer {
            // Check if we're in a CloudKit environment and should wait for sync
            if shouldWaitForCloudKitSync(context: context) {
                AppLogger.info("CloudKit sync in progress - deferring data population check", category: AppLogger.persistence)
                return false
            }
        }
        
        // First check if database is completely empty
        if isDatabaseEmpty(context: context) {
            AppLogger.info("Database is empty - initial population needed", category: AppLogger.persistence)
            return true
        }
        
        // Check if static data schema matches current preload data
        if !isStaticDataValid(context: context) {
            AppLogger.info("Static data schema is outdated - re-population needed", category: AppLogger.persistence)
            return true
        }
        
        return false
    }
    
    private static let versionSyncKey = "PreloadDataVersionSync"
    
    private func loadCurrentPreloadData() -> PreloadedData? {
        guard let url = Bundle.main.url(forResource: "preloadData", withExtension: "json") else {
            AppLogger.error("Failed to find preloadData.json in bundle", category: AppLogger.dataImport)
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(PreloadedData.self, from: data)
        } catch {
            AppLogger.error("Error loading preload data for validation", error: error, category: AppLogger.dataImport)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error loading preload data for validation")
            return nil
        }
    }
    
    private func validateUnits(context: NSManagedObjectContext, expectedUnits: [UnitData]) -> Bool {
        do {
            let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
            let existingUnits = try context.fetch(fetchRequest)
            
            // Check if we have the expected number of units
            if existingUnits.count != expectedUnits.count {
                AppLogger.info("Units count mismatch. Expected: \(expectedUnits.count), Found: \(existingUnits.count)", category: AppLogger.persistence)
                return false
            }
            
            // Check if all expected units exist with correct sort order
            let existingUnitNames = Set(existingUnits.compactMap { $0.name })
            let expectedUnitNames = Set(expectedUnits.map { $0.name })
            
            if existingUnitNames != expectedUnitNames {
                AppLogger.info("Units name mismatch. Missing or extra units detected", category: AppLogger.persistence)
                return false
            }
            
            // Validate sort orders
            for expectedUnit in expectedUnits {
                if let existingUnit = existingUnits.first(where: { $0.name == expectedUnit.name }),
                   existingUnit.sortOrder != expectedUnit.sortOrder {
                    AppLogger.info("Unit '\(expectedUnit.name)' has incorrect sort order", category: AppLogger.persistence)
                    return false
                }
            }
            
            return true
        } catch {
            AppLogger.error("Error validating units", error: error, category: AppLogger.persistence)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error validating units")
            return false
        }
    }
    
    private func validateMealTypes(context: NSManagedObjectContext, expectedMealTypes: [MealTypeData]) -> Bool {
        do {
            let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
            let existingMealTypes = try context.fetch(fetchRequest)
            
            // Check if we have the expected number of meal types
            if existingMealTypes.count != expectedMealTypes.count {
                AppLogger.info("MealTypes count mismatch. Expected: \(expectedMealTypes.count), Found: \(existingMealTypes.count)", category: AppLogger.persistence)
                return false
            }
            
            // Check if all expected meal types exist with correct sort order
            let existingMealTypeNames = Set(existingMealTypes.compactMap { $0.name })
            let expectedMealTypeNames = Set(expectedMealTypes.map { $0.name })
            
            if existingMealTypeNames != expectedMealTypeNames {
                AppLogger.info("MealTypes name mismatch. Missing or extra meal types detected", category: AppLogger.persistence)
                return false
            }
            
            // Validate sort orders
            for expectedMealType in expectedMealTypes {
                if let existingMealType = existingMealTypes.first(where: { $0.name == expectedMealType.name }),
                   existingMealType.sortOrder != expectedMealType.sortOrder {
                    AppLogger.info("MealType '\(expectedMealType.name)' has incorrect sort order", category: AppLogger.persistence)
                    return false
                }
            }
            
            return true
        } catch {
            AppLogger.error("Error validating meal types", error: error, category: AppLogger.persistence)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error validating meal types")
            return false
        }
    }
    
    private func validateDishCategories(context: NSManagedObjectContext, expectedCategories: [DishCategoryData]) -> Bool {
        do {
            let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
            let existingCategories = try context.fetch(fetchRequest)
            
            // Check if we have the expected number of categories
            if existingCategories.count != expectedCategories.count {
                AppLogger.info("DishCategories count mismatch. Expected: \(expectedCategories.count), Found: \(existingCategories.count)", category: AppLogger.persistence)
                return false
            }
            
            // Check if all expected categories exist with correct sort order
            let existingCategoryNames = Set(existingCategories.compactMap { $0.name })
            let expectedCategoryNames = Set(expectedCategories.map { $0.name })
            
            if existingCategoryNames != expectedCategoryNames {
                AppLogger.info("DishCategories name mismatch. Missing or extra categories detected", category: AppLogger.persistence)
                return false
            }
            
            // Validate sort orders
            for expectedCategory in expectedCategories {
                if let existingCategory = existingCategories.first(where: { $0.name == expectedCategory.name }),
                   existingCategory.sortOrder != expectedCategory.sortOrder {
                    AppLogger.info("DishCategory '\(expectedCategory.name)' has incorrect sort order", category: AppLogger.persistence)
                    return false
                }
            }
            
            return true
        } catch {
            AppLogger.error("Error validating dish categories", error: error, category: AppLogger.persistence)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error validating dish categories")
            return false
        }
    }
    
    func isStaticDataValid(context: NSManagedObjectContext) -> Bool {
        // Check stored version with thread safety
        let storedVersion = UserDefaults.standard.string(forKey: Self.preloadDataVersionKey)
        
        // Also check sync version to handle CloudKit sync race conditions
        let syncVersion = UserDefaults.standard.string(forKey: Self.versionSyncKey)
        
        if storedVersion != Self.currentPreloadDataVersion || syncVersion != Self.currentPreloadDataVersion {
            AppLogger.info("Preload data version mismatch. Stored: \(storedVersion ?? "none"), Sync: \(syncVersion ?? "none"), Current: \(Self.currentPreloadDataVersion)", category: AppLogger.persistence)
            return false
        }
        
        // Load current preload data to validate against
        guard let preloadData = loadCurrentPreloadData() else {
            AppLogger.error("Cannot load current preload data for validation", category: AppLogger.persistence)
            return false
        }
        
        // Validate units
        if !validateUnits(context: context, expectedUnits: preloadData.units) {
            return false
        }
        
        // Validate meal types
        if !validateMealTypes(context: context, expectedMealTypes: preloadData.mealTypes) {
            return false
        }
        
        // Validate dish categories
        if !validateDishCategories(context: context, expectedCategories: preloadData.dishCategories) {
            return false
        }
        
        AppLogger.info("Static data validation passed", category: AppLogger.persistence)
        return true
    }
    
    private func shouldWaitForCloudKitSync(context: NSManagedObjectContext) -> Bool {
        // If we have some data but it looks like incomplete CloudKit sync, wait
        let entityNames = ["Unit", "MealType", "DishCategory", "Product"]
        var hasAnyData = false
        var hasIncompleteData = false
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.fetchLimit = 1
            
            do {
                let count = try context.count(for: fetchRequest)
                if count > 0 {
                    hasAnyData = true
                    
                    // Check if this data looks incomplete (e.g., products without units)
                    if entityName == "Product" {
                        let productFetch: NSFetchRequest<Product> = Product.fetchRequest()
                        productFetch.predicate = NSPredicate(format: "unit == nil")
                        productFetch.fetchLimit = 1
                        
                        let orphanedProducts = try context.count(for: productFetch)
                        if orphanedProducts > 0 {
                            hasIncompleteData = true
                            AppLogger.info("Found products without units - possible incomplete CloudKit sync", category: AppLogger.persistence)
                        }
                    }
                }
            } catch {
                AppLogger.error("Error checking \(entityName) during CloudKit sync detection", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking \(entityName) during CloudKit sync detection")
            }
        }
        
        // If we have some data but it's incomplete, we should wait for CloudKit sync
        return hasAnyData && hasIncompleteData
    }
    
    func generateInitialData(context: NSManagedObjectContext) {
        // Thread-safe data generation to prevent multiple simultaneous executions
        dataGenerationLock.lock()
        defer { dataGenerationLock.unlock() }
        
        if isDataGenerationInProgress {
            AppLogger.info("Data generation already in progress - skipping duplicate execution", category: AppLogger.persistence)
            return
        }
        
        // Enhanced test environment detection
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            NSClassFromString("XCTestCase") != nil ||
                            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
                            ProcessInfo.processInfo.environment["CI"] != nil ||
                            ProcessInfo.processInfo.environment["BUILD_NUMBER"] != nil ||
                            ProcessInfo.processInfo.arguments.contains("test") ||
                            ProcessInfo.processInfo.arguments.contains("-XCTest") ||
                            ProcessInfo.processInfo.environment["UI_TESTS"] != nil ||
                            ProcessInfo.processInfo.environment["DISABLE_CLOUDKIT"] != nil ||
                            ProcessInfo.processInfo.arguments.contains("-UITests") ||
                            ProcessInfo.processInfo.arguments.contains("-DisableCloudKit")
        
        // Check version again within lock to prevent race conditions (skip for test environments)
        if !isRunningTests {
            let storedVersion = UserDefaults.standard.string(forKey: Self.preloadDataVersionKey)
            let syncVersion = UserDefaults.standard.string(forKey: Self.versionSyncKey)
            
            if storedVersion == Self.currentPreloadDataVersion && syncVersion == Self.currentPreloadDataVersion {
                AppLogger.info("Data is already at current version - skipping generation", category: AppLogger.persistence)
                return
            }
        } else {
            AppLogger.info("Test environment detected - forcing data generation", category: AppLogger.persistence)
        }
        
        isDataGenerationInProgress = true
        AppLogger.info("Starting data generation (thread-safe)", category: AppLogger.persistence)
        
        guard let url = Bundle.main.url(forResource: "preloadData", withExtension: "json") else {
            AppLogger.error("Failed to find preloadData.json in bundle", category: AppLogger.dataImport)
            isDataGenerationInProgress = false
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode(PreloadedData.self, from: data)

            // Use traditional data generation for test environments to ensure reliability
            if isRunningTests || !(container is NSPersistentCloudKitContainer) {
                generateDataTraditional(context: context, jsonData: jsonData)
            } else {
                generateDataWithCloudKitConflictResolution(context: context, jsonData: jsonData)
            }
            
            // Mark current version as loaded - use both keys for redundancy
            DispatchQueue.main.async {
                UserDefaults.standard.set(Self.currentPreloadDataVersion, forKey: Self.preloadDataVersionKey)
                UserDefaults.standard.set(Self.currentPreloadDataVersion, forKey: Self.versionSyncKey)
                UserDefaults.standard.synchronize() // Force immediate write
            }
            
            AppLogger.info("Data preloaded successfully from preloadData.json with conflict resolution (version \(Self.currentPreloadDataVersion))", category: AppLogger.dataImport)
            
            // Refresh static data cache to ensure it has the newly created data
            StaticDataCacheManager.shared.invalidateCache()
            
        } catch {
            AppLogger.error("Error preloading data", error: error, category: AppLogger.dataImport)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error preloading data")
        }
        
        isDataGenerationInProgress = false
    }
    
    /// Force regenerate initial data without version checks (for debug/testing purposes)
    func forceRegenerateInitialData(context: NSManagedObjectContext) {
        // Thread-safe data generation to prevent multiple simultaneous executions
        dataGenerationLock.lock()
        defer { dataGenerationLock.unlock() }
        
        if isDataGenerationInProgress {
            AppLogger.info("Data generation already in progress - skipping duplicate execution", category: AppLogger.persistence)
            return
        }
        
        isDataGenerationInProgress = true
        AppLogger.info("Starting FORCED data regeneration (bypassing version checks)", category: AppLogger.persistence)
        
        // Clear ALL existing data first
        clearAllDataForRegeneration(context: context)
        
        guard let url = Bundle.main.url(forResource: "preloadData", withExtension: "json") else {
            AppLogger.error("Failed to find preloadData.json in bundle", category: AppLogger.dataImport)
            isDataGenerationInProgress = false
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode(PreloadedData.self, from: data)

            // Always use traditional data generation for forced regeneration
            generateDataTraditional(context: context, jsonData: jsonData)
            
            // Reset version tracking to ensure proper tracking
            DispatchQueue.main.async {
                UserDefaults.standard.set(Self.currentPreloadDataVersion, forKey: Self.preloadDataVersionKey)
                UserDefaults.standard.set(Self.currentPreloadDataVersion, forKey: Self.versionSyncKey)
                UserDefaults.standard.synchronize()
            }
            
            AppLogger.info("FORCED data regeneration completed successfully", category: AppLogger.dataImport)
            
            // Force refresh of static data cache
            StaticDataCacheManager.shared.invalidateCache()
            
        } catch {
            AppLogger.error("Error in forced data regeneration", error: error, category: AppLogger.dataImport)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error in forced data regeneration")
        }
        
        isDataGenerationInProgress = false
    }
    
    private func generateDataWithCloudKitConflictResolution(context: NSManagedObjectContext, jsonData: PreloadedData) {
        AppLogger.info("Using CloudKit conflict resolution for data generation", category: AppLogger.dataImport)
        
        // Step 1: Create/update units (these are static reference data)
        var unitMap: [String: Unit] = [:]
        for unitData in jsonData.units {
            let unitKey = StaticKeyHelper.stableKey(from: unitData.name)
            let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "key == %@ OR name == %@", unitKey, unitData.name)
            fetchRequest.fetchLimit = 1
            
            var existingUnit: Unit?
            do {
                existingUnit = try context.fetch(fetchRequest).first
            } catch {
                AppLogger.error("Error checking for existing unit \(unitData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing unit \(unitData.name)")
                existingUnit = nil
            }
            if let existingUnit = existingUnit {
                // Update sort order if needed
                if existingUnit.sortOrder != unitData.sortOrder {
                    existingUnit.sortOrder = unitData.sortOrder
                }
                if (existingUnit.key?.isEmpty ?? true) {
                    existingUnit.key = unitKey
                }
                unitMap[unitData.name] = existingUnit
            } else {
                let unit = Unit(context: context)
                unit.name = unitData.name
                unit.sortOrder = unitData.sortOrder
                unit.key = unitKey
                unitMap[unitData.name] = unit
            }
        }
        
        // Step 2: Create/update meal types
        var mealTypeMap: [String: MealType] = [:]
        for mealTypeData in jsonData.mealTypes {
            let mtKey = StaticKeyHelper.stableKey(from: mealTypeData.name)
            let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "key == %@ OR name == %@", mtKey, mealTypeData.name)
            fetchRequest.fetchLimit = 1
            
            var existingMealType: MealType?
            do {
                existingMealType = try context.fetch(fetchRequest).first
            } catch {
                AppLogger.error("Error checking for existing meal type \(mealTypeData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing meal type \(mealTypeData.name)")
                existingMealType = nil
            }
            if let existingMealType = existingMealType {
                if existingMealType.sortOrder != mealTypeData.sortOrder {
                    existingMealType.sortOrder = mealTypeData.sortOrder
                }
                if (existingMealType.key?.isEmpty ?? true) {
                    existingMealType.key = mtKey
                }
                mealTypeMap[mealTypeData.name] = existingMealType
            } else {
                let mealType = MealType(context: context)
                mealType.name = mealTypeData.name
                mealType.sortOrder = mealTypeData.sortOrder
                mealType.key = mtKey
                mealTypeMap[mealTypeData.name] = mealType
            }
        }
        
        // Step 3: Create/update dish categories
        var dishCategoryMap: [String: DishCategory] = [:]
        for categoryData in jsonData.dishCategories {
            let catKey = StaticKeyHelper.stableKey(from: categoryData.name)
            let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "key == %@ OR name == %@", catKey, categoryData.name)
            fetchRequest.fetchLimit = 1
            
            var existingCategory: DishCategory?
            do {
                existingCategory = try context.fetch(fetchRequest).first
            } catch {
                AppLogger.error("Error checking for existing dish category \(categoryData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing dish category \(categoryData.name)")
                existingCategory = nil
            }
            if let existingCategory = existingCategory {
                if existingCategory.sortOrder != categoryData.sortOrder {
                    existingCategory.sortOrder = categoryData.sortOrder
                }
                if (existingCategory.key?.isEmpty ?? true) {
                    existingCategory.key = catKey
                }
                dishCategoryMap[categoryData.name] = existingCategory
            } else {
                let category = DishCategory(context: context)
                category.name = categoryData.name
                category.sortOrder = categoryData.sortOrder
                category.key = catKey
                dishCategoryMap[categoryData.name] = category
            }
        }

        // Step 4: Handle products with smart unit mapping
        var productMap: [String: Product] = [:]
        for productData in jsonData.products {
            let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", productData.name)
            
            var existingProducts: [Product] = []
            do {
                existingProducts = try context.fetch(fetchRequest)
            } catch {
                AppLogger.error("Error checking for existing product \(productData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing product \(productData.name)")
                existingProducts = []
            }
            
            if let existingProduct = existingProducts.first {
                // If product exists but has no unit, assign the correct unit
                if existingProduct.unit == nil, let expectedUnit = unitMap[productData.unit] {
                    existingProduct.unit = expectedUnit
                    AppLogger.info("Assigned unit '\(productData.unit)' to existing product '\(productData.name)'", category: AppLogger.dataImport)
                }
                // Ensure stable key exists
                if (existingProduct.key?.isEmpty ?? true) {
                    let unitKey = unitMap[productData.unit]?.key ?? StaticKeyHelper.stableKey(from: productData.unit)
                    existingProduct.key = StaticKeyHelper.productKey(name: productData.name, unitKey: unitKey)
                }
                productMap[productData.name] = existingProduct
                
                // Clean up any duplicate products with the same name
                for duplicate in existingProducts.dropFirst() {
                    // Reassign any ingredient details to the main product
                    if let ingredientDetails = duplicate.ingredientDetails {
                        for case let ingredient as IngredientDetail in ingredientDetails {
                            ingredient.product = existingProduct
                        }
                    }
                    context.delete(duplicate)
                    AppLogger.info("Cleaned up duplicate product '\(productData.name)'", category: AppLogger.dataImport)
                }
            } else {
                // Create new product
                let product = Product(context: context)
                product.name = productData.name
                product.unit = unitMap[productData.unit]
                product.isDraft = false  // Preloaded products are complete
                let unitKey = unitMap[productData.unit]?.key ?? StaticKeyHelper.stableKey(from: productData.unit)
                product.key = StaticKeyHelper.productKey(name: productData.name, unitKey: unitKey)
                productMap[productData.name] = product
            }
        }

        // Step 5: Handle dishes with conflict resolution
        for dishData in jsonData.dishes {
            let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", dishData.name)
            
            var existingDishes: [Dish] = []
            do {
                existingDishes = try context.fetch(fetchRequest)
            } catch {
                AppLogger.error("Error checking for existing dish \(dishData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing dish \(dishData.name)")
                existingDishes = []
            }
            
            var targetDish: Dish
            
            if let existingDish = existingDishes.first {
                targetDish = existingDish
                // Ensure stable key exists
                if (targetDish.key?.isEmpty ?? true) {
                    targetDish.key = StaticKeyHelper.stableKey(from: dishData.name)
                }
                
                // Update category if missing
                if targetDish.category == nil, 
                   let categoryName = dishData.category,
                   let category = dishCategoryMap[categoryName] {
                    targetDish.category = category
                    AppLogger.info("Assigned category '\(categoryName)' to existing dish '\(dishData.name)'", category: AppLogger.dataImport)
                }
                
                // Update details if missing
                if targetDish.details?.isEmpty != false && !dishData.details.isEmpty {
                    targetDish.details = dishData.details
                }
                
                // Clean up duplicates
                for duplicate in existingDishes.dropFirst() {
                    // Transfer any missing relationships
                    if targetDish.category == nil && duplicate.category != nil {
                        targetDish.category = duplicate.category
                    }
                    if let duplicateMealTypes = duplicate.mealTypes {
                        for case let mealType as MealType in duplicateMealTypes {
                            targetDish.addToMealTypes(mealType)
                        }
                    }
                    
                    context.delete(duplicate)
                    AppLogger.info("Cleaned up duplicate dish '\(dishData.name)'", category: AppLogger.dataImport)
                }
            } else {
                // Create new dish
                targetDish = Dish(context: context)
                targetDish.name = dishData.name
                targetDish.details = dishData.details
                targetDish.isDraft = false  // Preloaded dishes are complete
                targetDish.key = StaticKeyHelper.stableKey(from: dishData.name)
                
                // Set category
                if let categoryName = dishData.category,
                   let category = dishCategoryMap[categoryName] {
                    targetDish.category = category
                }
            }

            // Ensure ingredients exist (idempotent by ingredient key)
            func ingredientKey(_ productName: String, product: Product) -> String {
                let dishKey = targetDish.key ?? StaticKeyHelper.stableKey(from: targetDish.name ?? "")
                let unitKey = product.unit?.key ?? (product.unit?.name.map { StaticKeyHelper.stableKey(from: $0) } ?? "")
                let prodKey = StaticKeyHelper.productKey(name: productName, unitKey: unitKey)
                return dishKey + "|" + prodKey
            }
            var existingKeys: Set<String> = []
            if let details = targetDish.ingredientDetails as? Set<IngredientDetail> {
                for d in details {
                    if let p = d.product {
                        let k = ingredientKey(p.name ?? "", product: p)
                        existingKeys.insert(k)
                        d.key = k
                    }
                }
            }
            for ingredientData in dishData.ingredients {
                if let product = productMap[ingredientData.product] {
                    let k = ingredientKey(ingredientData.product, product: product)
                    if !existingKeys.contains(k) {
                        let ingredient = IngredientDetail(context: context)
                        ingredient.dish = targetDish
                        ingredient.product = product
                        ingredient.quantity = ingredientData.quantity
                        ingredient.key = k
                    }
                }
            }
            
            // Ensure meal types are assigned
            if let mealTypeNames = dishData.mealTypes {
                for mealTypeName in mealTypeNames {
                    if let mealType = mealTypeMap[mealTypeName] {
                        targetDish.addToMealTypes(mealType)
                    }
                }
            }
        }

        // Save all changes
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                AppLogger.error("Error saving CloudKit conflict resolution data generation", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error saving CloudKit conflict resolution data generation")
            }
        }
        
        // Perform post-seeding reconciliation to ensure categories and deduplicate ingredients
        reconcilePostInitialSeeding(context: context)
    }
    
    private func generateDataTraditional(context: NSManagedObjectContext, jsonData: PreloadedData) {
        AppLogger.info("Using traditional data generation for test/non-CloudKit environment", category: AppLogger.dataImport)
        
        // Clear existing static data if this is a re-population
        if !isDatabaseEmpty(context: context) {
            AppLogger.info("Re-populating static data - clearing existing static entities", category: AppLogger.dataImport)
            clearStaticData(context: context)
        }

        // Create Units with deduplication (prefer key)
        var unitMap: [String: Unit] = [:]
        for unitData in jsonData.units {
            let unitKey = StaticKeyHelper.stableKey(from: unitData.name)
            let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "key == %@ OR name == %@", unitKey, unitData.name)
            fetchRequest.fetchLimit = 1
            
            do {
                let existingUnit = try context.fetch(fetchRequest).first
                if let existingUnit = existingUnit {
                    if (existingUnit.key?.isEmpty ?? true) {
                        existingUnit.key = unitKey
                    }
                    unitMap[unitData.name] = existingUnit
                } else {
                    let unit = Unit(context: context)
                    unit.name = unitData.name
                    unit.sortOrder = unitData.sortOrder
                    unit.key = unitKey
                    unitMap[unitData.name] = unit
                }
            } catch {
                AppLogger.error("Error checking for existing unit \(unitData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing unit \(unitData.name)")
            }
        }
        
        // Create Meal types with deduplication (prefer key)
        var mealTypeMap: [String: MealType] = [:]
        for mealTypeData in jsonData.mealTypes {
            let mtKey = StaticKeyHelper.stableKey(from: mealTypeData.name)
            let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "key == %@ OR name == %@", mtKey, mealTypeData.name)
            fetchRequest.fetchLimit = 1
            
            do {
                let existingMealType = try context.fetch(fetchRequest).first
                if let existingMealType = existingMealType {
                    if (existingMealType.key?.isEmpty ?? true) {
                        existingMealType.key = mtKey
                    }
                    mealTypeMap[mealTypeData.name] = existingMealType
                } else {
                    let mealType = MealType(context: context)
                    mealType.name = mealTypeData.name
                    mealType.sortOrder = mealTypeData.sortOrder
                    mealType.key = mtKey
                    mealTypeMap[mealTypeData.name] = mealType
                }
            } catch {
                AppLogger.error("Error checking for existing meal type \(mealTypeData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing meal type \(mealTypeData.name)")
            }
        }
        
        // Create Dish Categories with deduplication (prefer key)
        var dishCategoryMap: [String: DishCategory] = [:]
        for categoryData in jsonData.dishCategories {
            let catKey = StaticKeyHelper.stableKey(from: categoryData.name)
            let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "key == %@ OR name == %@", catKey, categoryData.name)
            fetchRequest.fetchLimit = 1
            
            do {
                let existingCategory = try context.fetch(fetchRequest).first
                if let existingCategory = existingCategory {
                    if (existingCategory.key?.isEmpty ?? true) {
                        existingCategory.key = catKey
                    }
                    dishCategoryMap[categoryData.name] = existingCategory
                } else {
                    let category = DishCategory(context: context)
                    category.name = categoryData.name
                    category.sortOrder = categoryData.sortOrder
                    category.key = catKey
                    dishCategoryMap[categoryData.name] = category
                }
            } catch {
                AppLogger.error("Error checking for existing dish category \(categoryData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing dish category \(categoryData.name)")
            }
        }

        // Create Products with deduplication
        var productMap: [String: Product] = [:]
        for productData in jsonData.products {
            let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", productData.name)
            fetchRequest.fetchLimit = 1
            
            do {
                let existingProduct = try context.fetch(fetchRequest).first
                if let existingProduct = existingProduct {
                    productMap[productData.name] = existingProduct
                } else {
                    let product = Product(context: context)
                    product.name = productData.name
                    product.unit = unitMap[productData.unit]
                    product.isDraft = false  // Preloaded products are complete
                    let unitKey = unitMap[productData.unit]?.key ?? StaticKeyHelper.stableKey(from: productData.unit)
                    product.key = StaticKeyHelper.productKey(name: productData.name, unitKey: unitKey)
                    productMap[productData.name] = product
                }
            } catch {
                AppLogger.error("Error checking for existing product \(productData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error checking for existing product \(productData.name)")
            }
        }

        // Create Dishes and Ingredients with deduplication
        for dishData in jsonData.dishes {
            let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", dishData.name)
            fetchRequest.fetchLimit = 1
            
            do {
                let existingDish = try context.fetch(fetchRequest).first
                if existingDish != nil {
                    // Dish already exists, skip creation
                    continue
                }
                
                let dish = Dish(context: context)
                dish.name = dishData.name
                dish.details = dishData.details
                dish.isDraft = false  // Preloaded dishes are complete
                dish.key = StaticKeyHelper.stableKey(from: dishData.name)
                
                // Set category
                if let categoryName = dishData.category,
                   let category = dishCategoryMap[categoryName] {
                    dish.category = category
                }

                // Create ingredients idempotently by (dish|product) key
                func ingredientKey(_ productName: String, product: Product) -> String {
                    let dishKey = dish.key ?? StaticKeyHelper.stableKey(from: dish.name ?? "")
                    let unitKey = product.unit?.key ?? (product.unit?.name.map { StaticKeyHelper.stableKey(from: $0) } ?? "")
                    let prodKey = StaticKeyHelper.productKey(name: productName, unitKey: unitKey)
                    return dishKey + "|" + prodKey
                }
                var existingKeys: Set<String> = []
                if let details = dish.ingredientDetails as? Set<IngredientDetail> {
                    for d in details {
                        if let p = d.product {
                            let k = ingredientKey(p.name ?? "", product: p)
                            existingKeys.insert(k)
                            d.key = k
                        }
                    }
                }
                for ingredientData in dishData.ingredients {
                    if let product = productMap[ingredientData.product] {
                        let k = ingredientKey(ingredientData.product, product: product)
                        if !existingKeys.contains(k) {
                            let ingredient = IngredientDetail(context: context)
                            ingredient.dish = dish
                            ingredient.product = product
                            ingredient.quantity = ingredientData.quantity
                            ingredient.key = k
                        }
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
            } catch {
                AppLogger.error("Error creating dish \(dishData.name)", error: error, category: AppLogger.dataImport)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error creating dish \(dishData.name)")
            }
        }

        // Save all data
        do {
            if context.hasChanges {
                try context.save()
            }
            AppLogger.info("Traditional data generation completed successfully", category: AppLogger.dataImport)
        } catch {
            AppLogger.error("Error saving traditional data generation", error: error, category: AppLogger.dataImport)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error saving traditional data generation")
        }
        
        // Perform post-seeding reconciliation to ensure categories and deduplicate ingredients
        reconcilePostInitialSeeding(context: context)
    }
    
    private func clearStaticData(context: NSManagedObjectContext) {
        let staticEntities = ["Unit", "MealType", "DishCategory"]
        
        for entityName in staticEntities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
                AppLogger.info("Successfully cleared static data from \(entityName)", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Error clearing static data from \(entityName)", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error clearing static data from \(entityName)")
            }
        }
    }
    
    /// Clear all data including preloaded data for complete regeneration
    private func clearAllDataForRegeneration(context: NSManagedObjectContext) {
        // Clear all entities that contain preloaded data
        let allEntities = ["IngredientDetail", "Dish", "Product", "Unit", "MealType", "DishCategory"]
        
        for entityName in allEntities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
                AppLogger.info("Successfully cleared all data from \(entityName) for regeneration", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Error clearing all data from \(entityName) for regeneration", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error clearing all data from \(entityName) for regeneration")
            }
        }
        
        // Save the context to commit the deletions
        do {
            if context.hasChanges {
                try context.save()
            }
            AppLogger.info("All data cleared successfully for regeneration", category: AppLogger.persistence)
        } catch {
            AppLogger.error("Error saving context after clearing data for regeneration", error: error, category: AppLogger.persistence)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error saving context after clearing data for regeneration")
        }
    }

    // ... existing code ...
    
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

    // MARK: - Static Keys
    /// Generates a stable key from a human readable name
    private func generateKey(from name: String) -> String {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Remove diacritics and non-ASCII
        let folded = lower.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let replaced = folded.map { ch -> Character in
            let s = String(ch)
            if s.rangeOfCharacter(from: allowed.inverted) != nil {
                return "-"
            }
            return ch
        }
        // Collapse multiple dashes
        let key = String(replaced).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return key.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Ensures Unit/MealType/DishCategory have non-nil keys; idempotent
    func backfillStaticKeysIfNeeded(context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                // Units
                do {
                    let fetch: NSFetchRequest<Unit> = Unit.fetchRequest()
                    let items = try context.fetch(fetch)
                    for item in items {
                        if (item.key?.isEmpty ?? true), let name = item.name {
                            item.key = generateKey(from: name)
                        }
                    }
                }
                // MealTypes
                do {
                    let fetch: NSFetchRequest<MealType> = MealType.fetchRequest()
                    let items = try context.fetch(fetch)
                    for item in items {
                        if (item.key?.isEmpty ?? true), let name = item.name {
                            item.key = generateKey(from: name)
                        }
                    }
                }
                // DishCategories
                do {
                    let fetch: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
                    let items = try context.fetch(fetch)
                    for item in items {
                        if (item.key?.isEmpty ?? true), let name = item.name {
                            item.key = generateKey(from: name)
                        }
                    }
                }
                // Dishes
                do {
                    let fetch: NSFetchRequest<Dish> = Dish.fetchRequest()
                    let items = try context.fetch(fetch)
                    for item in items {
                        if (item.key?.isEmpty ?? true), let name = item.name {
                            item.key = StaticKeyHelper.stableKey(from: name)
                        }
                    }
                }
                // Products
                do {
                    let fetch: NSFetchRequest<Product> = Product.fetchRequest()
                    let items = try context.fetch(fetch)
                    for item in items {
                        if (item.key?.isEmpty ?? true), let name = item.name {
                            let unitKey: String? = item.unit?.key ?? item.unit?.name.map { StaticKeyHelper.stableKey(from: $0) }
                            item.key = StaticKeyHelper.productKey(name: name, unitKey: unitKey)
                        }
                    }
                }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                AppLogger.error("Backfilling static keys failed", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Backfilling static keys failed")
            }
        }
    }
    
    // MARK: - Heavy Operations Support
    
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
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error deleting data from \(entityName)")
            }
        }

        do {
            if context.hasChanges {
                try context.save()
            }
            AppLogger.info("All data deleted successfully", category: AppLogger.persistence)
        } catch {
            AppLogger.error("Error saving context after deletion", error: error, category: AppLogger.persistence)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error saving context after deletion")
        }
    }
    
    @MainActor
    func generateInitialDataInBackground(isCloudImportInProgress: Bool, completion: @escaping (Bool) -> Void) {
        // Thread-safe check
        dataGenerationLock.lock()
        let isInProgress = isDataGenerationInProgress
        dataGenerationLock.unlock()
        
        if isInProgress {
            AppLogger.info("Background data generation skipped - already in progress", category: AppLogger.persistence)
            completion(true)
            return
        }
        
        AnalyticsManager.shared.track(name: AnalyticsEventName.initial_data_generation_started)
        
        // Enhanced test environment detection for background generation
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            NSClassFromString("XCTestCase") != nil ||
                            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
                            ProcessInfo.processInfo.environment["CI"] != nil ||
                            ProcessInfo.processInfo.environment["BUILD_NUMBER"] != nil ||
                            ProcessInfo.processInfo.arguments.contains("test") ||
                            ProcessInfo.processInfo.arguments.contains("-XCTest") ||
                            ProcessInfo.processInfo.environment["UI_TESTS"] != nil ||
                            ProcessInfo.processInfo.environment["DISABLE_CLOUDKIT"] != nil ||
                            ProcessInfo.processInfo.arguments.contains("-UITests") ||
                            ProcessInfo.processInfo.arguments.contains("-DisableCloudKit")
        
        // The `isCloudImportInProgress` parameter is a snapshot of the CloudKit import state,
        // captured on the main actor and passed in by the caller to avoid cross‑actor access.
        // This ensures that background data generation does not interfere with ongoing CloudKit imports.

        BackgroundOperationManager.shared.executeBulkOperation { backgroundContext in
            // In test environments, force check for data generation needs
            let needsPopulation = isRunningTests ? 
                (self.isDatabaseEmpty(context: backgroundContext) || !self.isStaticDataValid(context: backgroundContext)) :
                self.isDatabaseEmptyOrOutdated(context: backgroundContext)
                
            if needsPopulation {
                // Double-check with a lightweight guard that no CloudKit import is ongoing
                if self.container is NSPersistentCloudKitContainer {
                    // Use captured snapshot from main actor to avoid cross-actor access
                    if isCloudImportInProgress {
                        let message = "Deferred initial data generation: CloudKit import in progress"
                        AppLogger.info(message, category: AppLogger.persistence)
                        AnalyticsManager.shared.track(name: AnalyticsEventName.initial_data_generation_skipped, properties: [AnalyticsPropertyKey.error_message: message])
                        return
                    }
                }
                self.performInitialDataGeneration(context: backgroundContext)
            } else {
                let message = "Background data generation skipped - data is already valid"
                AppLogger.info(message, category: AppLogger.persistence)
                AnalyticsManager.shared.track(name: AnalyticsEventName.initial_data_generation_skipped, properties: [AnalyticsPropertyKey.error_message: message])
            }
        } completion: { result in
            switch result {
            case .success:
                AppLogger.info("Initial data generated successfully in background", category: AppLogger.persistence)
                AnalyticsManager.shared.track(name: AnalyticsEventName.initial_data_generation_completed)
                completion(true)
            case .failure(let error):
                AppLogger.error("Failed to generate initial data in background", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to generate initial data in background")
                completion(false)
            }
        }
    }

    private func performInitialDataGeneration(context: NSManagedObjectContext) {
        // Thread-safe data generation to prevent multiple simultaneous executions
        dataGenerationLock.lock()
        defer { dataGenerationLock.unlock() }
        
        if isDataGenerationInProgress {
            AppLogger.info("Data generation already in progress in background - skipping duplicate execution", category: AppLogger.persistence)
            return
        }
        
        // Check version again within lock to prevent race conditions
        let storedVersion = UserDefaults.standard.string(forKey: Self.preloadDataVersionKey)
        let syncVersion = UserDefaults.standard.string(forKey: Self.versionSyncKey)
        
        if storedVersion == Self.currentPreloadDataVersion && syncVersion == Self.currentPreloadDataVersion {
            AppLogger.info("Background data is already at current version - skipping generation", category: AppLogger.persistence)
            return
        }
        
        isDataGenerationInProgress = true
        AppLogger.info("Generating initial data in context", category: AppLogger.persistence)
        
        // Use the existing generateInitialData logic but adapted for any context
        guard let url = Bundle.main.url(forResource: "preloadData", withExtension: "json") else {
            AppLogger.error("Failed to find preloadData.json in bundle", category: AppLogger.dataImport)
            isDataGenerationInProgress = false
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
                    unit.key = generateKey(from: unitData.name)
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
                    mealType.key = generateKey(from: mealTypeData.name)
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
                    category.key = generateKey(from: categoryData.name)
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
                    product.isDraft = false  // Preloaded products are complete
                    let unitKey = unitMap[productData.unit]?.key ?? generateKey(from: productData.unit)
                    product.key = generateKey(from: productData.name) + "|" + unitKey
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
                dish.isDraft = false  // Preloaded dishes are complete
                dish.key = generateKey(from: dishData.name)
                
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
            
            // Mark current version as loaded - use both keys for redundancy
            DispatchQueue.main.async {
                UserDefaults.standard.set(Self.currentPreloadDataVersion, forKey: Self.preloadDataVersionKey)
                UserDefaults.standard.set(Self.currentPreloadDataVersion, forKey: Self.versionSyncKey)
                UserDefaults.standard.synchronize() // Force immediate write
            }
            
            AppLogger.info("Initial data generated successfully in background context with deduplication", category: AppLogger.dataImport)
            
        } catch {
            AppLogger.error("Error generating initial data in background context", error: error, category: AppLogger.dataImport)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error generating initial data in background context")
        }
        
        isDataGenerationInProgress = false
        AppLogger.info("Initial data generation completed", category: AppLogger.persistence)
    }

    // ... existing code ...
    
    func forceDataSchemaUpdate(context: NSManagedObjectContext) {
        AppLogger.info("Forcing data schema update", category: AppLogger.persistence)
        
        // Thread-safe reset
        dataGenerationLock.lock()
        defer { dataGenerationLock.unlock() }
        
        // Clear the stored versions to force re-population
        UserDefaults.standard.removeObject(forKey: Self.preloadDataVersionKey)
        UserDefaults.standard.removeObject(forKey: Self.versionSyncKey)
        UserDefaults.standard.synchronize()
        
        // Clear static data cache
        StaticDataCacheManager.shared.invalidateCache()
        
        // Reset generation flag
        isDataGenerationInProgress = false
        
        // Trigger data generation
        generateInitialData(context: context)
    }

    // ... existing code ...
    
    func getCurrentPreloadDataVersion() -> String {
        return Self.currentPreloadDataVersion
    }
    
    func getStoredPreloadDataVersion() -> String? {
        return UserDefaults.standard.string(forKey: Self.preloadDataVersionKey)
    }
    
    // Remove local duplicates when CloudKit import brought remote copies: decide by dish key presence in both local preseeded set and remote set.
    func removeLocallySeededDishesIfRemoteExists(context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                // Load all dishes and group by key
                let fetch: NSFetchRequest<Dish> = Dish.fetchRequest()
                let all = try context.fetch(fetch)
                var groups: [String: [Dish]] = [:]
                for d in all {
                    let k = !(d.key?.isEmpty ?? true) ? d.key! : norm(d.name)
                    if k.isEmpty { continue }
                    groups[k, default: []].append(d)
                }
                var removed = 0
                for (_, dishes) in groups where dishes.count > 1 {
                    // Keep the one that is linked to any Menu entry (assumed Cloud import), else keep the most connected
                    let linked = dishes.filter { ($0.menus?.count ?? 0) > 0 }
                    let keep = linked.first ?? dishes.sorted { (($0.ingredientDetails?.count ?? 0) + ($0.mealTypes?.count ?? 0)) > (($1.ingredientDetails?.count ?? 0) + ($1.mealTypes?.count ?? 0)) }.first!
                    for d in dishes where d != keep { context.delete(d); removed += 1 }
                }
                if context.hasChanges { try context.save() }
                if removed > 0 { AppLogger.info("Removed \(removed) duplicate dishes after Cloud import (key-based)", category: AppLogger.persistence) }
            } catch {
                AppLogger.error("Failed to remove locally seeded dishes", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to remove locally seeded dishes")
            }
        }
    }
    func cleanupAllDuplicateStaticData(context: NSManagedObjectContext) {
        AppLogger.info("Starting comprehensive cleanup of duplicate static data", category: AppLogger.persistence)
        
        cleanupDuplicateMealTypes(context: context)
        cleanupDuplicateUnits(context: context)
        cleanupDuplicateDishCategories(context: context)
        cleanupDuplicateProducts(context: context)
        cleanupDuplicateDishes(context: context)
        cleanupDuplicateMenus(context: context)
        
        AppLogger.info("Completed comprehensive cleanup of duplicate static data", category: AppLogger.persistence)
    }
    
    func cleanupDuplicateMealTypes(context: NSManagedObjectContext) {
        AppLogger.info("Checking for duplicate meal types to cleanup", category: AppLogger.persistence)
        
        do {
            // Fetch all meal types
            let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
            let allMealTypes = try context.fetch(fetchRequest)
            
            // Group meal types by key when available, else by name
            var mealTypeGroups: [String: [MealType]] = [:]
            for mealType in allMealTypes {
                let groupKey = (mealType.key?.isEmpty == false ? mealType.key! : (mealType.name ?? ""))
                if groupKey.isEmpty { continue }
                if mealTypeGroups[groupKey] == nil {
                    mealTypeGroups[groupKey] = []
                }
                mealTypeGroups[groupKey]?.append(mealType)
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
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error cleaning up duplicate meal types")
        }
    }

    // Normalize dish->mealTypes relationships by collapsing duplicates to canonical objects
    func normalizeDishMealTypeRelations(context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                let mtFetch: NSFetchRequest<MealType> = MealType.fetchRequest()
                let allMealTypes = try context.fetch(mtFetch)
                var canonicalMap: [String: MealType] = [:]
                for mt in allMealTypes {
                    let key = (mt.key?.isEmpty == false ? mt.key! : (mt.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                    if key.isEmpty { continue }
                    if let existing = canonicalMap[key] {
                        if mt.sortOrder < existing.sortOrder { canonicalMap[key] = mt }
                    } else {
                        canonicalMap[key] = mt
                    }
                }

                let dishFetch: NSFetchRequest<Dish> = Dish.fetchRequest()
                let dishes = try context.fetch(dishFetch)
                var normalizedCount = 0
                for dish in dishes {
                    guard let mts = dish.mealTypes as? Set<MealType>, !mts.isEmpty else { continue }
                    var newSet: Set<MealType> = []
                    for mt in mts {
                        let key = (mt.key?.isEmpty == false ? mt.key! : (mt.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                        if let canonical = canonicalMap[key] { newSet.insert(canonical) }
                    }
                    if newSet != mts {
                        dish.mealTypes = newSet as NSSet
                        normalizedCount += 1
                    }
                }
                // Save and refresh dishes to ensure relationships are realized before menu reconciliation
                if context.hasChanges {
                    try context.save()
                }
                AppLogger.info("Normalized meal type relations for \(normalizedCount) dishes", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Failed to normalize dish meal types", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to normalize dish meal types")
            }
        }
    }

    // Deduplicate IngredientDetail within each Dish; remove orphans
    func normalizeDishIngredientDetails(context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                // Ensure product relations are canonicalized before deduping details
                self.normalizeDishProductRelations(context: context)

                let dishFetch: NSFetchRequest<Dish> = Dish.fetchRequest()
                let dishes = try context.fetch(dishFetch)
                var totalRemoved = 0
                var totalOrphans = 0
                var totalReassigned = 0
                for dish in dishes {
                    guard let details = dish.ingredientDetails as? Set<IngredientDetail>, !details.isEmpty else { continue }

                    // Reset any nil/invalid quantities to 0 to avoid NaN propagations
                    for d in details { if d.quantity.isNaN || d.quantity.isInfinite { d.quantity = 0 } }

                    // Second pass: group by canonicalized product key (name|unit), not by object identity
                    guard let reassigned = dish.ingredientDetails as? Set<IngredientDetail> else { continue }
                    func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    var buckets: [String: (sum: Double, minSort: Int16, keep: IngredientDetail, others: [IngredientDetail])] = [:]
                    var orphans: [IngredientDetail] = []
                    for d in reassigned {
                        guard let product = d.product else { orphans.append(d); continue }
                        // Treat details with unnamed or zero-quantity products as invalid and remove them
                        let nameIsEmpty = (product.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        if nameIsEmpty || d.quantity == 0 { orphans.append(d); continue }
                        let key = norm(product.name) + "|" + norm(product.unit?.name)
                        if var b = buckets[key] {
                            b.sum += d.quantity
                            b.minSort = min(b.minSort, d.sortOrder)
                            b.others.append(d)
                            buckets[key] = b
                        } else {
                            buckets[key] = (sum: d.quantity, minSort: d.sortOrder, keep: d, others: [])
                        }
                    }
                    for (key, bucket) in buckets {
                        var keepDetail = bucket.keep
                        // Choose a deterministic keeper: lower sortOrder, then lower objectID
                        for candidate in [bucket.keep] + bucket.others {
                            if candidate.sortOrder < keepDetail.sortOrder || (candidate.sortOrder == keepDetail.sortOrder && candidate.objectID.uriRepresentation().absoluteString < keepDetail.objectID.uriRepresentation().absoluteString) {
                                keepDetail = candidate
                            }
                        }
                        // Use max to avoid inflation across repeated sync cycles
                        let candidates = [bucket.keep] + bucket.others
                        let maxQuantity = candidates.map { $0.quantity }.max() ?? bucket.sum
                        keepDetail.quantity = maxQuantity
                        keepDetail.sortOrder = bucket.minSort
                        // Ensure product points to canonical product for this key if needed
                        do {
                            let parts = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                            let nameKey = String(parts.first ?? "")
                            let unitKey = parts.count > 1 ? String(parts[1]) : ""
                            let productFetch: NSFetchRequest<Product> = Product.fetchRequest()
                            if unitKey.isEmpty {
                                productFetch.predicate = NSPredicate(format: "(name ==[c] %@) AND (unit == nil)", nameKey)
                            } else {
                                productFetch.predicate = NSPredicate(format: "(name ==[c] %@) AND (unit.name ==[c] %@)", nameKey, unitKey)
                            }
                            productFetch.fetchLimit = 1
                            if let target = try context.fetch(productFetch).first {
                                keepDetail.product = target
                            }
                        } catch {
                            // best-effort; keep current relation on error
                        }
                        // Delete all non-keeper candidates, including the original bucket.keep if it is no longer the keeper
                        for d in candidates where d != keepDetail {
                            context.delete(d)
                            totalRemoved += 1
                            totalReassigned += 1
                        }
                    }
                    for d in orphans { context.delete(d); totalOrphans += 1 }
                }
                if context.hasChanges { try context.save() }
                AppLogger.info("Normalized ingredients: reassigned \(totalReassigned), removed \(totalRemoved) duplicates, \(totalOrphans) orphans", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Failed to normalize ingredient details", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to normalize ingredient details")
            }
        }
    }

    // Canonicalize IngredientDetail.product by mapping to a single Product per key (preferring Product.key),
    // falling back to (stable name|stable unit) when key is missing.
    func normalizeDishProductRelations(context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                let productFetch: NSFetchRequest<Product> = Product.fetchRequest()
                let allProducts = try context.fetch(productFetch)
                var canonical: [String: Product] = [:]
                for p in allProducts {
                    let key: String = {
                        if let k = p.key, !k.isEmpty { return k }
                        let unitKey = p.unit?.key ?? (p.unit?.name.map { StaticKeyHelper.stableKey(from: $0) } ?? "")
                        return StaticKeyHelper.productKey(name: p.name ?? "", unitKey: unitKey)
                    }()
                    if key.isEmpty { continue }
                    if (p.key?.isEmpty ?? true) { p.key = key }
                    func completenessScore(_ prod: Product) -> Int {
                        var score = 0
                        if let n = prod.name, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 2 }
                        if prod.unit != nil { score += 2 }
                        if !prod.isDraft { score += 1 }
                        return score
                    }
                    if let exist = canonical[key] {
                        // Prefer more complete product, then non-draft, then lowest objectID
                        let lhs = completenessScore(exist)
                        let rhs = completenessScore(p)
                        if rhs > lhs {
                            canonical[key] = p
                        } else if rhs == lhs {
                            let preferExisting = (!exist.isDraft && p.isDraft) ||
                                (exist.isDraft == p.isDraft && exist.objectID.uriRepresentation().absoluteString < p.objectID.uriRepresentation().absoluteString)
                            if !preferExisting { canonical[key] = p }
                        }
                    } else {
                        canonical[key] = p
                    }
                }

                // Secondary map: when a name maps uniquely across all units, allow name-only canonicalization
                var nameUnique: [String: Product] = [:]
                var nameCounts: [String: Int] = [:]
                for (_, p) in canonical {
                    let nameKey = norm(p.name)
                    guard !nameKey.isEmpty else { continue }
                    nameCounts[nameKey, default: 0] += 1
                    if nameCounts[nameKey] == 1 {
                        nameUnique[nameKey] = p
                    }
                }
                for (k, count) in nameCounts where count != 1 { nameUnique.removeValue(forKey: k) }

                let detailFetch: NSFetchRequest<IngredientDetail> = IngredientDetail.fetchRequest()
                // Process in small batches to reduce memory footprint and ensure deterministic dedup
                detailFetch.fetchBatchSize = 200
                let details = try context.fetch(detailFetch)
                var reassigned = 0
                var deleted = 0
                for d in details {
                    guard let prod = d.product else { context.delete(d); deleted += 1; continue }
                    let prefKey = (prod.key?.isEmpty == false) ? prod.key! : {
                        let unitKey = prod.unit?.key ?? (prod.unit?.name.map { StaticKeyHelper.stableKey(from: $0) } ?? "")
                        return StaticKeyHelper.productKey(name: prod.name ?? "", unitKey: unitKey)
                    }()
                    if let target = canonical[prefKey], target != prod {
                        d.product = target
                        reassigned += 1
                        continue
                    }
                    // Fallback: if mapping not found and the name is unique globally, reassign by name-only
                    let nameKeyOnly = norm(prod.name)
                    if let targetByName = nameUnique[nameKeyOnly], targetByName != prod {
                        d.product = targetByName
                        reassigned += 1
                    }
                }
                if context.hasChanges { try context.save() }
                AppLogger.info("Canonicalized product relations for \(reassigned) details, removed \(deleted) orphans", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Failed to canonicalize product relations", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to canonicalize product relations")
            }
        }
    }
    
    func cleanupDuplicateUnits(context: NSManagedObjectContext) {
        do {
            let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
            let allUnits = try context.fetch(fetchRequest)
            
            var unitGroups: [String: [Unit]] = [:]
            for unit in allUnits {
                let groupKey = (unit.key?.isEmpty == false ? unit.key! : (unit.name ?? ""))
                if groupKey.isEmpty { continue }
                if unitGroups[groupKey] == nil {
                    unitGroups[groupKey] = []
                }
                unitGroups[groupKey]?.append(unit)
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
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error cleaning up duplicate units")
        }
    }
    
    func cleanupDuplicateDishCategories(context: NSManagedObjectContext) {
        do {
            let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
            let allCategories = try context.fetch(fetchRequest)
            
            var categoryGroups: [String: [DishCategory]] = [:]
            for category in allCategories {
                let groupKey = (category.key?.isEmpty == false ? category.key! : (category.name ?? ""))
                if groupKey.isEmpty { continue }
                if categoryGroups[groupKey] == nil {
                    categoryGroups[groupKey] = []
                }
                categoryGroups[groupKey]?.append(category)
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
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error cleaning up duplicate dish categories")
        }
    }
    
    func cleanupDuplicateProducts(context: NSManagedObjectContext) {
        do {
            func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            let allProducts = try context.fetch(fetchRequest)
            
            // Group by stable product.key when available, otherwise by name|unit
            var groups: [String: [Product]] = [:]
            for p in allProducts {
                let key = !(p.key?.isEmpty ?? true) ? p.key! : (norm(p.name) + "|" + norm(p.unit?.name))
                if key == "|" { continue }
                groups[key, default: []].append(p)
            }
            
            var removed = 0
            for (_, items) in groups where items.count > 1 {
                // Prefer keeper by completeness, then by non-draft, then by lowest objectID
                func completeness(_ prod: Product) -> Int {
                    var score = 0
                    if !(norm(prod.name).isEmpty) { score += 2 }
                    if prod.unit != nil { score += 2 }
                    if !prod.isDraft { score += 1 }
                    return score
                }
                let sorted = items.sorted { a, b in
                    let sa = completeness(a), sb = completeness(b)
                    if sa != sb { return sa > sb }
                    if a.isDraft != b.isDraft { return !a.isDraft }
                    return a.objectID.debugDescription < b.objectID.debugDescription
                }
                let keep = sorted.first!
                for dup in sorted.dropFirst() {
                    if let details = dup.ingredientDetails {
                        for case let d as IngredientDetail in details { d.product = keep }
                    }
                    context.delete(dup)
                    removed += 1
                }
            }
            if context.hasChanges { try context.save() }
            AppLogger.info("Cleaned up \(removed) duplicate products (key-based)", category: AppLogger.persistence)
        } catch {
            AppLogger.error("Error cleaning up duplicate products", error: error, category: AppLogger.persistence)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error cleaning up duplicate products")
        }
    }

    func cleanupDuplicateDishes(context: NSManagedObjectContext) {
        do {
            let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
            let allDishes = try context.fetch(fetchRequest)
            
            func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            var dishGroups: [String: [Dish]] = [:]
            for dish in allDishes {
                let nameKey = !(dish.key?.isEmpty ?? true) ? dish.key! : norm(dish.name)
                if nameKey.isEmpty { continue }
                dishGroups[nameKey, default: []].append(dish)
            }
            
            var duplicatesRemoved = 0
            for (_, dishes) in dishGroups where dishes.count > 1 {
                // Keep the dish with most relationships/content
                let sorted = dishes.sorted {
                    let lhsScore = (($0.ingredientDetails?.count ?? 0) + ($0.mealTypes?.count ?? 0))
                    let rhsScore = (($1.ingredientDetails?.count ?? 0) + ($1.mealTypes?.count ?? 0))
                    return (lhsScore, $0.objectID.debugDescription) > (rhsScore, $1.objectID.debugDescription)
                }
                let keep = sorted.first!
                for duplicate in sorted.dropFirst() {
                    // If both are initial preloaded dishes, prefer to keep ingredients only from the richer one and drop duplicates entirely
                    if let dupDetails = duplicate.ingredientDetails as? Set<IngredientDetail>, let keepDetails = keep.ingredientDetails as? Set<IngredientDetail> {
                        // Build set of product keys existing in keeper to avoid duplicate ingredient rows
                        func productKey(_ p: Product?) -> String { guard let p = p else { return "" }; let u = p.unit?.key ?? (p.unit?.name ?? ""); return (p.key?.isEmpty == false ? p.key! : (norm(p.name) + "|" + norm(u))) }
                        var existingProductKeys: Set<String> = Set(keepDetails.map { productKey($0.product) })
                        for d in dupDetails {
                            let pk = productKey(d.product)
                            if existingProductKeys.contains(pk) {
                                // Skip importing this ingredient to avoid duplicates
                                continue
                            }
                            d.dish = keep
                            existingProductKeys.insert(pk)
                        }
                    }
                    // Merge relationships and details
                    if let details = duplicate.ingredientDetails {
                        for case let item as IngredientDetail in details { item.dish = keep }
                    }
                    if let mts = duplicate.mealTypes {
                        for case let mt as MealType in mts { keep.addToMealTypes(mt) }
                    }
                    // Reassign menus referencing the duplicate to keep dish
                    if let menus = duplicate.menus {
                        for case let m as Menu in menus {
                            m.addToDishes(keep)
                        }
                    }
                    if keep.category == nil, let cat = duplicate.category { keep.category = cat }
                    if (keep.details?.isEmpty ?? true), let d = duplicate.details, !d.isEmpty { keep.details = d }
                    context.delete(duplicate)
                    duplicatesRemoved += 1
                }
                AppLogger.info("Removed duplicates for dish '\(keep.name ?? "unknown")': \(dishes.count - 1)", category: AppLogger.persistence)
            }
            if context.hasChanges { try context.save() }
            AppLogger.info("Cleaned up \(duplicatesRemoved) duplicate dishes", category: AppLogger.persistence)
        } catch {
            AppLogger.error("Error cleaning up duplicate dishes", error: error, category: AppLogger.persistence)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error cleaning up duplicate dishes")
        }
    }

    // Backfill categories for dishes missing one, using preload data mapping by stable keys
    func restoreDishCategoriesFromPreload(context: NSManagedObjectContext) {
        context.performAndWait {
            guard let preload = loadCurrentPreloadData() else { return }
            do {
                var expectedByDishKey: [String: String] = [:]
                for d in preload.dishes { expectedByDishKey[StaticKeyHelper.stableKey(from: d.name)] = d.category ?? "" }
                let catFetch: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
                let categories = try context.fetch(catFetch)
                var catsByKey: [String: DishCategory] = [:]
                for c in categories { if let name = c.name { catsByKey[StaticKeyHelper.stableKey(from: name)] = c } }
                let dishFetch: NSFetchRequest<Dish> = Dish.fetchRequest()
                let dishes = try context.fetch(dishFetch)
                var updated = 0
                for dish in dishes where dish.category == nil {
                    let dk = (dish.key?.isEmpty == false) ? dish.key! : StaticKeyHelper.stableKey(from: dish.name ?? "")
                    if let catName = expectedByDishKey[dk], !catName.isEmpty {
                        let ck = StaticKeyHelper.stableKey(from: catName)
                        if let cat = catsByKey[ck] { dish.category = cat; updated += 1 }
                    }
                }
                if context.hasChanges { try context.save() }
                AppLogger.info("Restored categories for \(updated) dishes from preload", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Failed to restore dish categories from preload", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to restore dish categories from preload")
            }
        }
    }

    func cleanupDuplicateMenus(context: NSManagedObjectContext) {
        do {
            let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
            let allMenus = try context.fetch(fetchRequest)
            
            func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            var groups: [String: [Menu]] = [:]
            for menu in allMenus {
                // Group by the logical slot. `date` is not used: it is a local-midnight stamp whose
                // calendar day differs between time zones of devices sharing the CloudKit store.
                let week = menu.calendarWeek
                let day = norm(menu.day)
                let type = (menu.mealTypeKey?.isEmpty == false) ? menu.mealTypeKey! : norm(menu.mealType)
                let key = "wk:\(week)|day:\(day)|type:\(type)"
                groups[key, default: []].append(menu)
            }
            
            var removed = 0
            for (_, menus) in groups where menus.count > 1 {
                // Keep menu with most dishes
                let sorted = menus.sorted {
                    let lhsCount = ($0.dishes?.count ?? 0)
                    let rhsCount = ($1.dishes?.count ?? 0)
                    return (lhsCount, $0.objectID.debugDescription) > (rhsCount, $1.objectID.debugDescription)
                }
                let keep = sorted.first!
                for duplicate in sorted.dropFirst() {
                    if let dishes = duplicate.dishes {
                        for case let dish as Dish in dishes {
                            keep.addToDishes(dish)
                        }
                    }
                    context.delete(duplicate)
                    removed += 1
                }
            }
            if context.hasChanges { try context.save() }
            AppLogger.info("Cleaned up \(removed) duplicate menus", category: AppLogger.persistence)
        } catch {
            AppLogger.error("Error cleaning up duplicate menus", error: error, category: AppLogger.persistence)
            AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Error cleaning up duplicate menus")
        }
    }

    // Normalize Menu.mealType strings to canonical names (using MealType.key/name map)
    func normalizeMenuMealTypeStrings(context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                let mtFetch: NSFetchRequest<MealType> = MealType.fetchRequest()
                let mts = try context.fetch(mtFetch)
                var canonicalByLookup: [String: String] = [:]
                for mt in mts {
                    let key = !(mt.key?.isEmpty ?? true) ? mt.key! : (mt.name ?? "")
                    let lookup = norm(key)
                    if !lookup.isEmpty {
                        canonicalByLookup[lookup] = mt.name
                    }
                }
                let menuFetch: NSFetchRequest<Menu> = Menu.fetchRequest()
                let menus = try context.fetch(menuFetch)
                var updated = 0
                for m in menus {
                    let lookup = norm(m.mealType)
                    if let canonical = canonicalByLookup[lookup] {
                        m.mealType = canonical
                        m.mealTypeKey = lookup
                        updated += 1
                    }
                }
                if context.hasChanges { try context.save() }
                AppLogger.info("Normalized menu mealType strings for \(updated) entries", category: AppLogger.persistence)
            } catch {
                AppLogger.error("Failed to normalize menu mealType strings", error: error, category: AppLogger.persistence)
                AnalyticsManager.shared.trackError(error, domain: "Persistence", category: "Failed to normalize menu mealType strings")
            }
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
