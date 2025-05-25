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
    private var isDatabaseEmpty: Bool = false

    private init() {
        checkICloudAccountStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
                self?.checkDatabaseState()
            }
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
           event.type == .import, event.endDate != nil {
            print("✅ iCloud sync completed.")
            DispatchQueue.main.async {
                self.checkDatabaseState()
            }
        }
    }

    func checkDatabaseState() {
        let persistence = PersistenceController.shared
        let context = persistence.container.viewContext
        isDatabaseEmpty = persistence.isDatabaseEmpty(context: context)
        
        if isDatabaseEmpty {
            persistence.generateInitialData(context: context)
        }
        isLoading = false
    }
}
