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
        }
        
        // Customize TabBar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground() // Makes the background opaque
        if let tabBarColor = UIColor(named: "BackgroundColor") {
            tabBarAppearance.backgroundColor = tabBarColor
        }
        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray
        ]
        tabBarItemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(named: "AccentColor") ?? UIColor.blue
        ]
        tabBarItemAppearance.normal.iconColor = UIColor.gray
        tabBarItemAppearance.selected.iconColor = UIColor(named: "AccentColor") ?? UIColor.blue

        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance // For scrollable content
        
        // Customize UINavigationBarAppearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        if let navigationBarColor = UIColor(named: "BackgroundColor") {
            navBarAppearance.backgroundColor = navigationBarColor
        }
        
        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(named: "AccentColor") ?? UIColor.blue
        ]
        buttonAppearance.highlighted.titleTextAttributes = [
            .foregroundColor: UIColor(named: "AccentColor") ?? UIColor.blue
        ]

        navBarAppearance.buttonAppearance = buttonAppearance
        navBarAppearance.doneButtonAppearance = buttonAppearance
        
        let scrollEdgeNavBarAppearance = navBarAppearance.copy()
        scrollEdgeNavBarAppearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeNavBarAppearance
        UINavigationBar.appearance().tintColor = UIColor(named: "BackgroundColor")
        
        // Customize Search bar
        UISearchBar.appearance().tintColor = UIColor(named: "AccentColor")
        
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(named: "SecondaryBackgroundColor")
        UISegmentedControl.appearance().backgroundColor = UIColor(named: "BackgroundColor")
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
