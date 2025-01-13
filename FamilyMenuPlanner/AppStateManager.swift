//
//  AppStateManager.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 13.01.25.
//

import CoreData
import SwiftUI

final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var isLoading: Bool = true
    private var isDatabaseEmpty: Bool = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
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
