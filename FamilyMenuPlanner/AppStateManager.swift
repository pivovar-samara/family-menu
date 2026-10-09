//
//  AppStateManager.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 13.01.25.
//

@preconcurrency import Foundation
import CoreData
import SwiftUI
import CloudKit

@MainActor
final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    private var cloudKitEventObserver: NSObjectProtocol? = nil
    /// Small delay that allows CloudKit merge operations to fully settle
    private static let cloudKitMergeSettleDelay: TimeInterval = 0.5
    
    @Published var isLoading: Bool = true
    @Published var isICloudAvailable: Bool = false
    @Published var isCloudKitSyncing: Bool = false
    @Published var persistenceError: String? = nil
    @Published var showPersistenceErrorAlert: Bool = false
    private var isDatabaseEmpty: Bool = false
    /// When true, we have acquired a CloudKit seeding lease and must bypass the CloudKit gating
    /// to proceed with local initial data generation to avoid an infinite wait loop.
    private var hasCloudKitSeedingLease: Bool = false

    private let seedingService: CloudKitSeedingService
    private let dataStore: StartupDataStore
    private let seedingGateMaxWait: TimeInterval
    /// Pause between gate rounds that ended without a decision, so a quick "keep waiting" does not spin
    private let seedingGateRetryDelay: TimeInterval
    private var startupTask: Task<Void, Never>?
    private var seedingGateTask: Task<Void, Never>?

    private convenience init() {
        self.init(
            seedingService: LiveCloudKitSeedingService(),
            dataStore: PersistenceStartupDataStore(),
            startupMode: .detect()
        )
    }

    init(seedingService: CloudKitSeedingService,
         dataStore: StartupDataStore,
         startupMode: StartupMode,
         seedingGateMaxWait: TimeInterval = CloudKitSeedingGate.defaultMaxWait,
         seedingGateRetryDelay: TimeInterval = 15) {
        self.seedingService = seedingService
        self.dataStore = dataStore
        self.seedingGateMaxWait = seedingGateMaxWait
        self.seedingGateRetryDelay = seedingGateRetryDelay

        switch startupMode {
        case .skipped:
            print("ℹ️ AppStateManager: Running in CI environment")
            // Set safe defaults for CI
            self.isLoading = false
            self.isICloudAvailable = false
        case .localOnly:
            AppLogger.info("AppStateManager initializing...", category: AppLogger.appState)
            AppLogger.debug("Running in test/CI environment - skipping iCloud account status check", category: AppLogger.appState)
            self.isICloudAvailable = false
            checkPersistenceState()
            AppLogger.info("AppStateManager initialized successfully", category: AppLogger.appState)
        case .cloudKitAware:
            AppLogger.info("AppStateManager initializing...", category: AppLogger.appState)
            // The seeding decision depends on iCloud availability, so resolve the account status first
            // and keep the loading screen up meanwhile.
            startupTask = Task { [weak self] in
                await self?.resolveICloudAccountStatus()
                self?.checkPersistenceState()
            }
        }
    }
    
    deinit {
        startupTask?.cancel()
        seedingGateTask?.cancel()
        if let token = cloudKitEventObserver {
            NotificationCenter.default.removeObserver(token)
            cloudKitEventObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkPersistenceState() {
        if !dataStore.isReady {
            // Handle persistence errors
            self.persistenceError = dataStore.userFriendlyErrorMessage
            self.showPersistenceErrorAlert = true
            self.isLoading = false
            return
        }
        
        // If persistence is ready, continue with normal flow
        checkDatabaseState()
    }
    
    func retryPersistenceSetup() {
        self.persistenceError = nil
        self.showPersistenceErrorAlert = false
        self.isLoading = true
        
        // Use the new asynchronous recovery method to avoid blocking the UI
        dataStore.attemptRecovery { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.checkDatabaseState()
                } else {
                    self?.persistenceError = "Unable to recover from the error. Please restart the app or contact support if the problem persists.".localized()
                    self?.showPersistenceErrorAlert = true
                    self?.isLoading = false
                }
            }
        }
    }

    private func resolveICloudAccountStatus() async {
        do {
            let status = try await seedingService.accountStatus()
            self.isICloudAvailable = (status == .available)
            if self.isICloudAvailable {
                // Observe CloudKit events via classic observer to avoid non-sendable Notification in Swift 6
                self.cloudKitEventObserver = NotificationCenter.default.addObserver(
                    forName: NSPersistentCloudKitContainer.eventChangedNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    Task { @MainActor [weak self] in
                        self?.handleCloudKitEvent(notification)
                    }
                }
                AppLogger.info("iCloud is available - CloudKit sync enabled", category: AppLogger.cloudKit)
                AnalyticsManager.shared.setUserProperties([AnalyticsUserPropertyName.icloud_available: true])
                if let mirrorContainer = dataStore.cloudKitContainerIdentifier,
                   mirrorContainer != seedingService.containerIdentifier {
                    AppLogger.error("Core Data mirrors to \(mirrorContainer) but seeding gate uses \(seedingService.containerIdentifier)", category: AppLogger.cloudKit)
                }
            } else {
                AppLogger.info("iCloud is not available (account status \(status.rawValue)) - running in local mode", category: AppLogger.cloudKit)
                AnalyticsManager.shared.setUserProperties([AnalyticsUserPropertyName.icloud_available: false])
            }
        } catch {
            AppLogger.error("iCloud account check failed [\(CloudKitSeedingGate.errorCodeDescription(error)), container \(seedingService.containerIdentifier)]", error: error, category: AppLogger.cloudKit)
            AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "iCloud account check failed")
            AnalyticsManager.shared.setUserProperties([AnalyticsUserPropertyName.icloud_available: false])
            self.isICloudAvailable = false
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
        switch event.type {
        case .import:
            if event.endDate == nil {
                isCloudKitSyncing = true
            } else if event.endDate != nil {
                isCloudKitSyncing = false
                AppLogger.info("iCloud sync completed", category: AppLogger.cloudKit)
                // Slight delay allows final merges to settle to avoid repeated reprocessing
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.cloudKitMergeSettleDelay) {
                    if PersistenceController.shared.isReady {
                        let bg = PersistenceController.shared.newBackgroundContext()
                        bg.perform {
                            // Call helpers on the background context's queue
                            PersistenceController.shared.normalizeDishMealTypeRelations(context: bg)
                            PersistenceController.shared.normalizeDishProductRelations(context: bg)
                            // Remove duplicate reference data first
                            PersistenceController.shared.cleanupDuplicateUnits(context: bg)
                            PersistenceController.shared.cleanupDuplicateMealTypes(context: bg)
                            PersistenceController.shared.cleanupDuplicateDishCategories(context: bg)
                            PersistenceController.shared.cleanupDuplicateProducts(context: bg)
                            // If we detect locally seeded dishes for this version and remote dishes exist, drop the local seeded ones
                            PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: bg)
                            // Merge duplicate dishes and then normalize ingredients
                            PersistenceController.shared.cleanupDuplicateDishes(context: bg)
                            PersistenceController.shared.normalizeDishIngredientDetails(context: bg)
                            // Restore missing categories from preload data (in case keep had nil)
                            PersistenceController.shared.restoreDishCategoriesFromPreload(context: bg)
                            // Re-encode legacy week keys of imported menus, then normalize and deduplicate menus
                            MenuService(context: bg).migrateLegacyWeekKeys()
                            PersistenceController.shared.normalizeMenuMealTypeStrings(context: bg)
                            PersistenceController.shared.cleanupDuplicateMenus(context: bg)
                            DispatchQueue.main.async {
                                // Notify UI layers to refresh after sync
                                NotificationCenter.default.post(name: .appDataDidReconcileAfterCloudKitImport, object: nil)
                                self.checkDatabaseState()
                            }
                        }
                    }
                }
            }
        default:
            break
        }
    }

    private func checkDatabaseState() {
        // Double-check that persistence is ready before proceeding
        guard dataStore.isReady else {
            self.persistenceError = dataStore.userFriendlyErrorMessage
            self.showPersistenceErrorAlert = true
            self.isLoading = false
            return
        }
        
        // If CloudKit is available and the local store is empty, gate seeding conservatively,
        // unless a seeding lease has been acquired which explicitly allows local seeding.
        if AppSeedingGating.shouldGateSeeding(
            isICloudAvailable: isICloudAvailable,
            isCloudKitContainer: dataStore.cloudKitContainerIdentifier != nil,
            isDatabaseEmpty: dataStore.isDatabaseEmpty(),
            hasSeedingLease: hasCloudKitSeedingLease
        ) {
            startSeedingGate()
            return
        }
        // Data arrived by another path (e.g. the import observer) while the gate was still waiting
        cancelSeedingGate()
        
        let needsDataPopulation = dataStore.needsDataPopulation()
        
        // Avoid global cleanup that may over-delete; reconciliation runs after import
        
        // One-time draft migration and cleanup of abandoned drafts
        dataStore.performStartupMaintenance()
        
        if needsDataPopulation {
            // Use background context for initial data generation to avoid blocking UI
            let cloudImportSnapshot = self.isCloudKitSyncing
            dataStore.generateInitialData(isCloudImportInProgress: cloudImportSnapshot) { [weak self] success in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if success {
                        // When seeded successfully in CloudKit environment, mark account seeded.
                        // Generation can be skipped (e.g. import in progress) and still report success, so check the store.
                        if self.isICloudAvailable, self.dataStore.cloudKitContainerIdentifier != nil, !self.dataStore.isDatabaseEmpty() {
                            let service = self.seedingService
                            let version = self.dataStore.preloadDataVersion
                            Task { await service.markAccountSeeded(version: version) }
                        }
                        // Initialize static data cache after database is ready
                        // This will preload all static data to ensure immediate availability
                        self.dataStore.didFinishLoading()
                        // Reset the lease flag now that seeding has completed
                        self.hasCloudKitSeedingLease = false
                        self.isLoading = false
                    } else {
                        self.persistenceError = "Failed to initialize app data. Please restart the app.".localized()
                        self.showPersistenceErrorAlert = true
                        self.isLoading = false
                    }
                }
            }
        } else {
            // Initialize static data cache after database is ready
            // This will preload all static data to ensure immediate availability
            dataStore.didFinishLoading()
            isLoading = false
        }
    }

    /// Waits (keeping the loading screen) until CloudKit data arrives or this device may seed locally.
    private func startSeedingGate() {
        guard seedingGateTask == nil else { return }
        AppLogger.info("CloudKit active and local store empty – gating seeding on import or remote emptiness", category: AppLogger.cloudKit)
        isLoading = true
        let service = seedingService
        let version = dataStore.preloadDataVersion
        let maxWait = seedingGateMaxWait
        let retryDelay = seedingGateRetryDelay
        seedingGateTask = Task { [weak self] in
            while !Task.isCancelled {
                let decision = await AppSeedingGating.runGateRound(service: service, version: version, maxWait: maxWait)
                guard !Task.isCancelled, let self else { return }
                switch decision {
                case .recheckDatabase:
                    self.seedingGateTask = nil
                    self.checkDatabaseState()
                    return
                case .seedLocally:
                    self.hasCloudKitSeedingLease = true
                    self.seedingGateTask = nil
                    self.checkDatabaseState()
                    return
                case .keepWaiting:
                    self.isLoading = true
                }
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
    }

    private func cancelSeedingGate() {
        seedingGateTask?.cancel()
        seedingGateTask = nil
    }
    
    /// One-time draft migration followed by cleanup of abandoned drafts, run on every startup
    static func performDraftMaintenance(context: NSManagedObjectContext) {
        // One-time migration: Restore user data that was incorrectly marked as drafts
        restoreUserDataFromDrafts(context: context)
        // Clean up any abandoned draft entities from incomplete creation flows
        cleanupAbandonedDrafts(context: context)
    }

    /// Cleans up abandoned draft entities that were created but never completed
    /// Uses intelligent cleanup strategy to balance safety with database cleanliness
    private static func cleanupAbandonedDrafts(context: NSManagedObjectContext) {
        // Configuration - can be adjusted based on user feedback or made user-configurable
        let maxDraftDishesToKeep = UserDefaults.standard.object(forKey: "MaxDraftDishesToKeep") as? Int ?? 10
        let maxDraftProductsToKeep = UserDefaults.standard.object(forKey: "MaxDraftProductsToKeep") as? Int ?? 5
        AppLogger.info("Cleaning up abandoned draft entities", category: AppLogger.appState)
        
        context.performAndWait {
            var entitiesDeleted = 0
            
            // Clean up draft dishes using tiered approach
            let dishFetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
            dishFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftDishes = try context.fetch(dishFetchRequest)
                var actuallyDeleted = 0
                let maxDraftsToKeep = maxDraftDishesToKeep
                
                // Separate dishes into categories
                var emptyDishes: [Dish] = []
                var minimalContentDishes: [Dish] = []
                var substantialContentDishes: [Dish] = []
                
                for dish in draftDishes {
                    let hasName = !(dish.name?.isEmpty ?? true)
                    let hasIngredients = (dish.ingredientDetails?.count ?? 0) > 0
                    let hasMealTypes = (dish.mealTypes?.count ?? 0) > 0
                    let hasCategory = dish.category != nil
                    let hasDetails = !(dish.details?.isEmpty ?? true)
                    
                    if !hasName && !hasIngredients && !hasMealTypes && !hasCategory && !hasDetails {
                        // Completely empty - always safe to delete
                        emptyDishes.append(dish)
                    } else if hasIngredients || hasMealTypes || (hasName && (hasDetails || hasCategory)) {
                        // Has substantial content - preserve
                        substantialContentDishes.append(dish)
                    } else {
                        // Minimal content (e.g., just name) - delete if too many
                        minimalContentDishes.append(dish)
                    }
                }
                
                // Always delete completely empty dishes
                for dish in emptyDishes {
                    context.delete(dish)
                    actuallyDeleted += 1
                }
                
                // Delete excess minimal content dishes (keep most recent ones)
                if minimalContentDishes.count > maxDraftsToKeep {
                    let excessCount = minimalContentDishes.count - maxDraftsToKeep
                    // Sort by object ID to get consistent ordering (older objects typically have lower IDs)
                    let sortedMinimal = minimalContentDishes.sorted { $0.objectID.description < $1.objectID.description }
                    
                    for i in 0..<excessCount {
                        context.delete(sortedMinimal[i])
                        actuallyDeleted += 1
                    }
                }
                
                entitiesDeleted += actuallyDeleted
                AppLogger.info("Found \(draftDishes.count) draft dishes: \(emptyDishes.count) empty, \(minimalContentDishes.count) minimal, \(substantialContentDishes.count) substantial. Deleted \(actuallyDeleted) drafts.", category: AppLogger.appState)
            } catch {
                AppLogger.error("Failed to fetch draft dishes for cleanup", error: error, category: AppLogger.appState)
                AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to fetch draft dishes for cleanup")
            }
            
            // Clean up draft products using tiered approach
            let productFetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            productFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftProducts = try context.fetch(productFetchRequest)
                var actuallyDeleted = 0
                let maxProductDraftsToKeep = maxDraftProductsToKeep
                
                // Separate products into categories
                var emptyProducts: [Product] = []
                var minimalContentProducts: [Product] = []
                var substantialContentProducts: [Product] = []
                
                for product in draftProducts {
                    let hasName = !(product.name?.isEmpty ?? true)
                    let hasUnit = product.unit != nil
                    let hasIngredientUsage = (product.ingredientDetails?.count ?? 0) > 0
                    
                    if !hasName && !hasUnit {
                        // Completely empty - always safe to delete
                        emptyProducts.append(product)
                    } else if hasUnit && hasName {
                        // Has both name and unit - preserve
                        substantialContentProducts.append(product)
                    } else if hasIngredientUsage {
                        // Already used in dishes - preserve
                        substantialContentProducts.append(product)
                    } else {
                        // Minimal content (just name OR just unit) - delete if too many
                        minimalContentProducts.append(product)
                    }
                }
                
                // Always delete completely empty products
                for product in emptyProducts {
                    context.delete(product)
                    actuallyDeleted += 1
                }
                
                // Delete excess minimal content products
                if minimalContentProducts.count > maxProductDraftsToKeep {
                    let excessCount = minimalContentProducts.count - maxProductDraftsToKeep
                    let sortedMinimal = minimalContentProducts.sorted { $0.objectID.description < $1.objectID.description }
                    
                    for i in 0..<excessCount {
                        context.delete(sortedMinimal[i])
                        actuallyDeleted += 1
                    }
                }
                
                entitiesDeleted += actuallyDeleted
                AppLogger.info("Found \(draftProducts.count) draft products: \(emptyProducts.count) empty, \(minimalContentProducts.count) minimal, \(substantialContentProducts.count) substantial. Deleted \(actuallyDeleted) drafts.", category: AppLogger.appState)
            } catch {
                AppLogger.error("Failed to fetch draft products for cleanup", error: error, category: AppLogger.appState)
                AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to fetch draft products for cleanup")
            }
            
            // Save changes if any entities were deleted
            if entitiesDeleted > 0 {
                do {
                    try context.save()
                    AppLogger.info("Successfully cleaned up \(entitiesDeleted) truly abandoned draft entities", category: AppLogger.appState)
                } catch {
                    AppLogger.error("Failed to save after cleaning up draft entities", error: error, category: AppLogger.appState)
                    AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to save after cleaning up draft entities")
                }
            } else {
                AppLogger.info("No truly abandoned draft entities found", category: AppLogger.appState)
            }
        }
    }
    
    // MARK: - Draft Cleanup Configuration
    
    /// Updates the maximum number of draft entities to keep during cleanup
    /// - Parameters:
    ///   - maxDishes: Maximum draft dishes to preserve (default: 10)
    ///   - maxProducts: Maximum draft products to preserve (default: 5)
    static func configureDraftCleanupLimits(maxDishes: Int = 10, maxProducts: Int = 5) {
        UserDefaults.standard.set(maxDishes, forKey: "MaxDraftDishesToKeep")
        UserDefaults.standard.set(maxProducts, forKey: "MaxDraftProductsToKeep")
        UserDefaults.standard.synchronize()
        AppLogger.info("Updated draft cleanup limits: dishes=\(maxDishes), products=\(maxProducts)", category: AppLogger.appState)
    }
    
    /// Gets current draft cleanup configuration
    static func getDraftCleanupLimits() -> (dishes: Int, products: Int) {
        let dishes = UserDefaults.standard.object(forKey: "MaxDraftDishesToKeep") as? Int ?? 10
        let products = UserDefaults.standard.object(forKey: "MaxDraftProductsToKeep") as? Int ?? 5
        return (dishes: dishes, products: products)
    }
    
    /// One-time migration: Restores user data that was incorrectly marked as drafts
    /// This fixes the issue where existing entities were marked as drafts during the initial implementation
    private static func restoreUserDataFromDrafts(context: NSManagedObjectContext) {
        // Check if this migration has already been performed
        let migrationKey = "DraftMigrationCompleted_v1"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            AppLogger.info("Draft migration already completed, skipping", category: AppLogger.appState)
            return
        }
        
        AppLogger.info("Performing one-time migration to restore user data from incorrect draft status", category: AppLogger.appState)
        
        context.performAndWait {
            var entitiesRestored = 0
            
            // Restore dishes that have meaningful content
            let dishFetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
            dishFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftDishes = try context.fetch(dishFetchRequest)
                for dish in draftDishes {
                    // If dish has a name and either ingredients or meal types, it's likely user data
                    let hasName = !(dish.name?.isEmpty ?? true)
                    let hasIngredients = (dish.ingredientDetails?.count ?? 0) > 0
                    let hasMealTypes = (dish.mealTypes?.count ?? 0) > 0
                    
                    if hasName && (hasIngredients || hasMealTypes) {
                        dish.isDraft = false
                        entitiesRestored += 1
                        AppLogger.info("Restored dish: \(dish.name ?? "unnamed")", category: AppLogger.appState)
                    }
                }
            } catch {
                AppLogger.error("Failed to fetch draft dishes for migration", error: error, category: AppLogger.appState)
                AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to fetch draft dishes for migration")
            }
            
            // Restore products that have meaningful content
            let productFetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            productFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftProducts = try context.fetch(productFetchRequest)
                for product in draftProducts {
                    // If product has a name and unit, it's likely user data
                    let hasName = !(product.name?.isEmpty ?? true)
                    let hasUnit = product.unit != nil
                    
                    if hasName && hasUnit {
                        product.isDraft = false
                        entitiesRestored += 1
                        AppLogger.info("Restored product: \(product.name ?? "unnamed")", category: AppLogger.appState)
                    }
                }
            } catch {
                AppLogger.error("Failed to fetch draft products for migration", error: error, category: AppLogger.appState)
                AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to fetch draft products for migration")
            }
            
            // Save changes if any entities were restored
            if entitiesRestored > 0 {
                do {
                    try context.save()
                    AppLogger.info("Successfully restored \(entitiesRestored) user entities from incorrect draft status", category: AppLogger.appState)
                } catch {
                    AppLogger.error("Failed to save after restoring entities from draft status", error: error, category: AppLogger.appState)
                    AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to save after restoring entities from draft status")
                    return
                }
            } else {
                AppLogger.info("No user entities found to restore from draft status", category: AppLogger.appState)
            }
            
            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationKey)
            UserDefaults.standard.synchronize()
            AppLogger.info("Draft migration completed successfully", category: AppLogger.appState)
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let appDataDidReconcileAfterCloudKitImport = Notification.Name("AppDataDidReconcileAfterCloudKitImport")
}

// MARK: - Testable helpers
enum AppSeedingGating {
    /// Determines whether the app should gate initial data seeding awaiting CloudKit signals.
    /// Returns true when CloudKit is available, a CloudKit container is in use, and the database is empty,
    /// and no seeding lease has been acquired.
    static func shouldGateSeeding(isICloudAvailable: Bool,
                                  isCloudKitContainer: Bool,
                                  isDatabaseEmpty: Bool,
                                  hasSeedingLease: Bool) -> Bool {
        if hasSeedingLease { return false }
        return isICloudAvailable && isCloudKitContainer && isDatabaseEmpty
    }

    enum GateDecision: Equatable {
        /// CloudKit delivered data (or may have): re-run the database check
        case recheckDatabase
        /// Remote is empty and this device holds the seeding lease
        case seedLocally
        /// No decision yet: keep the loading screen and run another round
        case keepWaiting
    }

    /// One round of the first-launch seeding gate. Never allows local seeding unless the remote mirror
    /// is confirmed empty, the seed marker is confirmed absent (or for another version), and the seeding lease was acquired.
    @MainActor
    static func runGateRound(service: CloudKitSeedingService, version: String, maxWait: TimeInterval) async -> GateDecision {
        let markerStatus = await service.isAccountSeeded(version: version)
        let outcome = await service.waitForImportOrRemoteEmpty(maxWait: maxWait)
        switch outcome {
        case .importCompleted:
            AppLogger.info("CloudKit import completed – proceeding", category: AppLogger.cloudKit)
            return .recheckDatabase
        case .timedOut:
            AppLogger.info("CloudKit gating timed out – continue waiting without seeding", category: AppLogger.cloudKit)
            return .keepWaiting
        case .remoteAppearsEmpty:
            switch markerStatus {
            case .seeded:
                // Another device seeded this version but has not exported its records yet
                AppLogger.info("Account already seeded but remote mirror still empty – waiting for import", category: AppLogger.cloudKit)
                return .keepWaiting
            case .unknown:
                AppLogger.info("Account seed marker unreadable – waiting instead of seeding", category: AppLogger.cloudKit)
                return .keepWaiting
            case .notSeeded:
                break
            }
            // Acquire a seeding lease to prevent multiple devices seeding simultaneously
            if await service.tryAcquireSeedingLease() {
                AppLogger.info("Seeding lease acquired – allowing local seed", category: AppLogger.cloudKit)
                return .seedLocally
            }
            AppLogger.info("Seeding lease not acquired – waiting for remote import", category: AppLogger.cloudKit)
            return .keepWaiting
        }
    }
}

/// How `AppStateManager` starts, derived from the process environment
enum StartupMode: Equatable {
    /// Unit tests / CI: no startup work at all
    case skipped
    /// UI tests or `-DisableCloudKit`: local store only, no iCloud account check
    case localOnly
    /// Normal launch: resolve the iCloud account status before deciding on seeding
    case cloudKitAware

    static func detect(environment: [String: String] = ProcessInfo.processInfo.environment,
                       arguments: [String] = ProcessInfo.processInfo.arguments,
                       isXCTestLoaded: Bool = NSClassFromString("XCTestCase") != nil) -> StartupMode {
        if environment["GITHUB_ACTIONS"] != nil ||
            environment["CI"] != nil ||
            environment["XCTestConfigurationFilePath"] != nil {
            return .skipped
        }
        if arguments.contains("-UITests") ||
            arguments.contains("-DisableCloudKit") ||
            isXCTestLoaded {
            return .localOnly
        }
        return .cloudKitAware
    }
}

/// Store operations `AppStateManager` needs during startup. Live implementation: `PersistenceStartupDataStore`.
@MainActor
protocol StartupDataStore {
    var isReady: Bool { get }
    var userFriendlyErrorMessage: String? { get }
    /// CloudKit container the store mirrors to, or nil when CloudKit mirroring is off (tests, simulator)
    var cloudKitContainerIdentifier: String? { get }
    var preloadDataVersion: String { get }
    func isDatabaseEmpty() -> Bool
    func needsDataPopulation() -> Bool
    func performStartupMaintenance()
    func generateInitialData(isCloudImportInProgress: Bool, completion: @escaping (Bool) -> Void)
    /// Called once the store has data and the UI can load
    func didFinishLoading()
    func attemptRecovery(completion: @escaping (Bool) -> Void)
}

@MainActor
struct PersistenceStartupDataStore: StartupDataStore {
    private var persistence: PersistenceController { PersistenceController.shared }
    private var viewContext: NSManagedObjectContext { persistence.container.viewContext }

    var isReady: Bool { persistence.isReady }
    var userFriendlyErrorMessage: String? { persistence.userFriendlyErrorMessage }
    var cloudKitContainerIdentifier: String? {
        guard persistence.container is NSPersistentCloudKitContainer else { return nil }
        return persistence.container.persistentStoreDescriptions.first?.cloudKitContainerOptions?.containerIdentifier
    }
    var preloadDataVersion: String { persistence.getCurrentPreloadDataVersion() }

    func isDatabaseEmpty() -> Bool { persistence.isDatabaseEmpty(context: viewContext) }
    func needsDataPopulation() -> Bool { persistence.isDatabaseEmptyOrOutdated(context: viewContext) }
    func performStartupMaintenance() { AppStateManager.performDraftMaintenance(context: viewContext) }

    func generateInitialData(isCloudImportInProgress: Bool, completion: @escaping (Bool) -> Void) {
        persistence.generateInitialDataInBackground(isCloudImportInProgress: isCloudImportInProgress, completion: completion)
    }

    func didFinishLoading() { StaticDataCacheManager.shared.initialize(with: viewContext) }

    func attemptRecovery(completion: @escaping (Bool) -> Void) {
        persistence.attemptRecovery(completion: completion)
    }
}
