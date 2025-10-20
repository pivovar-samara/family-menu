//
//  FamilyMenuPlannerApp.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI
import UIKit

@main
struct FamilyMenuPlannerApp: App {
    let persistenceController: PersistenceController
    private let isUITestEnvironment: Bool
    
    init() {
        // Initialize persistence controller based on environment
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            NSClassFromString("XCTestCase") != nil ||
                            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
                            ProcessInfo.processInfo.environment["CI"] != nil
        
        let isRunningUITests = ProcessInfo.processInfo.environment["UI_TESTS"] != nil ||
                              ProcessInfo.processInfo.arguments.contains("-UITests") ||
                              ProcessInfo.processInfo.arguments.contains("-DisableCloudKit")
        self.isUITestEnvironment = isRunningUITests
        
        if isRunningUITests {
            // For UI tests, use persistent storage (not in-memory) but disable CloudKit
            AppLogger.info("UI test environment detected - using persistent storage without CloudKit", category: AppLogger.persistence)
            self.persistenceController = PersistenceController(inMemory: false)
            // Disable animations to avoid XCTest idling timeouts and flakiness
            UIView.setAnimationsEnabled(false)
        } else if isRunningTests {
            // For other tests, use in-memory database to avoid interference
            self.persistenceController = PersistenceController(inMemory: true)
        } else {
            // For production, use the shared instance
            self.persistenceController = PersistenceController.shared
            
            AnalyticsBootstrap.configure(
                amplitudeApiKey: AppConfig.amplitudeKey,
                environment: "prod",
                additionalProviders: [], // add other providers here in the future
                initialUserId: nil,
                additionalConfiguration: [
                    "trackingSessionEvents": true
                ]
            )
        }
        
        // Customize TabBar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground() // Makes the background opaque
        tabBarAppearance.backgroundColor = UIColor.appBackground
        
        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]
        tabBarItemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.accent
        ]
        tabBarItemAppearance.normal.iconColor = UIColor.secondaryLabel
        tabBarItemAppearance.selected.iconColor = UIColor.accent

        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance // For scrollable content
        
        if #unavailable (iOS 26.0) {
            // Customize UINavigationBarAppearance
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = UIColor.appBackground
            UINavigationBar.appearance().standardAppearance = navBarAppearance
        }
        
        // Customize Search bar
        UISearchBar.appearance().tintColor = UIColor.accent
        UINavigationBar.appearance().tintColor = UIColor.accent
        
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor.appSecondaryBackground
        UISegmentedControl.appearance().backgroundColor = UIColor.appBackground
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // Ensure SwiftUI animations are disabled during UI tests
                .transaction { txn in
                    if isUITestEnvironment {
                        txn.disablesAnimations = true
                    }
                }
        }
    }
}
