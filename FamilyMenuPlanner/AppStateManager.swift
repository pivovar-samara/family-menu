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
        // Enhanced test environment detection - same as in PersistenceController with additional CI checks
        // Also check for UI test environment which launches the actual app
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            NSClassFromString("XCTestCase") != nil ||
                            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
                            ProcessInfo.processInfo.environment["CI"] != nil ||
                            ProcessInfo.processInfo.environment["BUILD_NUMBER"] != nil ||    // Xcode Cloud
                            ProcessInfo.processInfo.arguments.contains("test") ||
                            ProcessInfo.processInfo.arguments.contains("-XCTest") ||
                            ProcessInfo.processInfo.arguments.contains("xctest") ||         // Additional test detection
                            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil || // UI test detection
                            Bundle.main.bundlePath.contains("UITests") ||                   // UI test bundle detection
                            ProcessInfo.processInfo.processName.contains("test") ||        // Process name contains test
                            ProcessInfo.processInfo.environment["UI_TESTS"] != nil ||      // UI test environment variable
                            ProcessInfo.processInfo.environment["DISABLE_CLOUDKIT"] != nil || // CloudKit disable flag
                            ProcessInfo.processInfo.arguments.contains("-UITests") ||      // UI test launch argument
                            ProcessInfo.processInfo.arguments.contains("-DisableCloudKit") // CloudKit disable argument
        
        // Skip CloudKit checks in test/CI environments - be extra defensive
        if isRunningTests {
            AppLogger.debug("Running in test/CI environment - skipping iCloud account status check", category: AppLogger.appState)
            DispatchQueue.main.async {
                self.isICloudAvailable = false
            }
            return
        }
        
        // Additional safety check - wrap CloudKit access in try-catch equivalent
        guard !ProcessInfo.processInfo.arguments.contains("-UITests") else {
            AppLogger.debug("UI test launch argument detected - skipping CloudKit", category: AppLogger.appState)
            DispatchQueue.main.async {
                self.isICloudAvailable = false
            }
            return
        }
        
        // Check for explicit CloudKit disable arguments
        guard !ProcessInfo.processInfo.arguments.contains("-DisableCloudKit") else {
            AppLogger.debug("CloudKit disabled by launch argument", category: AppLogger.appState)
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
    /// Only deletes truly empty draft entities, not user data
    private func cleanupAbandonedDrafts(context: NSManagedObjectContext) {
        AppLogger.info("Cleaning up abandoned draft entities", category: AppLogger.appState)
        
        context.performAndWait {
            var entitiesDeleted = 0
            
            // Clean up truly empty draft dishes
            let dishFetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
            dishFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftDishes = try context.fetch(dishFetchRequest)
                for dish in draftDishes {
                    // Only delete if it's truly empty (no meaningful content)
                    let hasName = !(dish.name?.isEmpty ?? true)
                    let hasIngredients = (dish.ingredientDetails?.count ?? 0) > 0
                    let hasMealTypes = (dish.mealTypes?.count ?? 0) > 0
                    
                    if !hasName && !hasIngredients && !hasMealTypes {
                        context.delete(dish)
                        entitiesDeleted += 1
                    } else {
                        AppLogger.warning("Found draft dish with content that should have been restored: \(dish.name ?? "unnamed")", category: AppLogger.appState)
                    }
                }
                AppLogger.info("Found \(draftDishes.count) draft dishes, deleted \(entitiesDeleted) empty ones", category: AppLogger.appState)
            } catch {
                AppLogger.error("Failed to fetch draft dishes for cleanup", error: error, category: AppLogger.appState)
            }
            
            // Clean up truly empty draft products
            let productFetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            productFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftProducts = try context.fetch(productFetchRequest)
                let initialDeletedCount = entitiesDeleted
                for product in draftProducts {
                    // Only delete if it's truly empty (no meaningful content)
                    let hasName = !(product.name?.isEmpty ?? true)
                    let hasUnit = product.unit != nil
                    
                    if !hasName && !hasUnit {
                        context.delete(product)
                        entitiesDeleted += 1
                    } else {
                        AppLogger.warning("Found draft product with content that should have been restored: \(product.name ?? "unnamed")", category: AppLogger.appState)
                    }
                }
                AppLogger.info("Found \(draftProducts.count) draft products, deleted \(entitiesDeleted - initialDeletedCount) empty ones", category: AppLogger.appState)
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
