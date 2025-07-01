//
//  AppStateManager.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 13.01.25.
//

import CoreData
import SwiftUI
import CloudKit

final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var isLoading: Bool = true
    @Published var isICloudAvailable: Bool = false
    @Published var persistenceError: String? = nil
    @Published var showPersistenceErrorAlert: Bool = false
    private var isDatabaseEmpty: Bool = false

    private init() {
        // Early CI detection to prevent potential startup issues
        let isCI = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
                   ProcessInfo.processInfo.environment["CI"] != nil ||
                   ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        
        if isCI {
            print("ℹ️ AppStateManager: Running in CI environment")
            // Set safe defaults for CI
            self.isLoading = false
            self.isICloudAvailable = false
            return
        }
        
        AppLogger.info("AppStateManager initializing...", category: AppLogger.appState)
        
        checkPersistenceState()
        checkICloudAccountStatus()
        AppLogger.info("AppStateManager initialized successfully", category: AppLogger.appState)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkPersistenceState() {
        let persistence = PersistenceController.shared
        
        if !persistence.isReady {
            // Handle persistence errors
            self.persistenceError = persistence.userFriendlyErrorMessage
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
        
        let persistence = PersistenceController.shared
        
        // Use the new asynchronous recovery method to avoid blocking the UI
        persistence.attemptRecovery { [weak self] success in
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

    private func checkICloudAccountStatus() {
        // Check if running in test or CI environment
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
                            ProcessInfo.processInfo.environment["CI"] != nil ||
                            ProcessInfo.processInfo.arguments.contains("-UITests") ||
                            ProcessInfo.processInfo.arguments.contains("-DisableCloudKit") ||
                            NSClassFromString("XCTestCase") != nil
        
        // Skip CloudKit checks in test/CI environments
        if isRunningTests {
            AppLogger.debug("Running in test/CI environment - skipping iCloud account status check", category: AppLogger.appState)
            DispatchQueue.main.async {
                self.isICloudAvailable = false
            }
            return
        }
        
        // Only check CloudKit status in production environment with additional safety
        CKContainer.default().accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.error("iCloud account check failed", error: error, category: AppLogger.cloudKit)
                    self.isICloudAvailable = false
                } else {
                    self.isICloudAvailable = (status == .available)
                    if self.isICloudAvailable {
                        NotificationCenter.default.addObserver(
                            forName: NSPersistentCloudKitContainer.eventChangedNotification,
                            object: nil,
                            queue: .main
                        ) { [weak self] notification in
                            self?.handleCloudKitEvent(notification)
                        }
                        AppLogger.info("iCloud is available - CloudKit sync enabled", category: AppLogger.cloudKit)
                    } else {
                        AppLogger.info("iCloud is not available - running in local mode", category: AppLogger.cloudKit)
                    }
                }
            }
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
           event.type == .import, event.endDate != nil {
            AppLogger.info("iCloud sync completed", category: AppLogger.cloudKit)
            DispatchQueue.main.async {
                // Only check database state if persistence is ready
                if PersistenceController.shared.isReady {
                    self.checkDatabaseState()
                }
            }
        }
    }

    private func checkDatabaseState() {
        let persistence = PersistenceController.shared
        
        // Double-check that persistence is ready before proceeding
        guard persistence.isReady else {
            self.persistenceError = persistence.userFriendlyErrorMessage
            self.showPersistenceErrorAlert = true
            self.isLoading = false
            return
        }
        
        let context = persistence.container.viewContext
        
        let needsDataPopulation = persistence.isDatabaseEmptyOrOutdated(context: context)
        
        // Clean up any existing duplicate static data from previous CloudKit sync issues
        persistence.cleanupAllDuplicateStaticData(context: context)
        
        // One-time migration: Restore user data that was incorrectly marked as drafts
        restoreUserDataFromDrafts(context: context)
        
        // Clean up any abandoned draft entities from incomplete creation flows
        cleanupAbandonedDrafts(context: context)
        
        if needsDataPopulation {
            // Use background context for initial data generation to avoid blocking UI
            persistence.generateInitialDataInBackground { [weak self] success in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if success {
                        // Initialize static data cache after database is ready
                        // This will preload all static data to ensure immediate availability
                        StaticDataCacheManager.shared.initialize(with: context)
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
            StaticDataCacheManager.shared.initialize(with: context)
            isLoading = false
        }
    }
    
    /// Cleans up abandoned draft entities that were created but never completed
    /// Uses intelligent cleanup strategy to balance safety with database cleanliness
    private func cleanupAbandonedDrafts(context: NSManagedObjectContext) {
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
            }
            
            // Save changes if any entities were deleted
            if entitiesDeleted > 0 {
                do {
                    try context.save()
                    AppLogger.info("Successfully cleaned up \(entitiesDeleted) truly abandoned draft entities", category: AppLogger.appState)
                } catch {
                    AppLogger.error("Failed to save after cleaning up draft entities", error: error, category: AppLogger.appState)
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
    private func restoreUserDataFromDrafts(context: NSManagedObjectContext) {
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
            }
            
            // Save changes if any entities were restored
            if entitiesRestored > 0 {
                do {
                    try context.save()
                    AppLogger.info("Successfully restored \(entitiesRestored) user entities from incorrect draft status", category: AppLogger.appState)
                } catch {
                    AppLogger.error("Failed to save after restoring entities from draft status", error: error, category: AppLogger.appState)
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
