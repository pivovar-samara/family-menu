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
        checkPersistenceState()
        checkICloudAccountStatus()
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
        CKContainer.default().accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.isICloudAvailable = (status == .available)
                if self?.isICloudAvailable == true {
                    NotificationCenter.default.addObserver(
                        forName: NSPersistentCloudKitContainer.eventChangedNotification,
                        object: nil,
                        queue: .main
                    ) { [weak self] notification in
                        self?.handleCloudKitEvent(notification)
                    }
                } else {
                    print("❌ iCloud is not available. Disabling iCloud sync.")
                }
            }
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
           event.type == .import, event.endDate != nil {
            print("✅ iCloud sync completed.")
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
        isLoading = false
    }
}
