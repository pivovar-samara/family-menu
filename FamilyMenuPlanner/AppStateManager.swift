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

    func checkDatabaseState() {
        let persistence = PersistenceController.shared
        
        // Double-check that persistence is ready before proceeding
        guard persistence.isReady else {
            self.persistenceError = persistence.userFriendlyErrorMessage
            self.showPersistenceErrorAlert = true
            self.isLoading = false
            return
        }
        
        let context = persistence.container.viewContext
        isDatabaseEmpty = persistence.isDatabaseEmpty(context: context)
        
        if isDatabaseEmpty {
            persistence.generateInitialData(context: context)
        }
        
        // Initialize static data cache after database is ready
        // This will preload all static data to ensure immediate availability
        StaticDataCacheManager.shared.initialize(with: context)
        
        isLoading = false
    }
}
