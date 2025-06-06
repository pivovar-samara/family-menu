//
//  AppLogger.swift
//  FamilyMenuPlanner
//
//  Created by Performance Optimization on 28.01.25.
//
//  TODO: Update remaining files to use AppLogger instead of print statements:
//  - Menu/BaseMenu/MenuService.swift (menu generation logging)
//  - Menu/DishSelection/DishSelectionService.swift (dish selection errors)
//  - Products/ProductList/ProductListService.swift (product loading errors)  
//  - Dishes/ProductSelection/ProductSelectionService.swift (product selection errors)
//  - Persistence.swift (remaining print statements for recovery operations)
//

import Foundation
import os

/// Centralized logging framework for the FamilyMenuPlanner app
/// Uses Apple's structured logging system (os.Logger) for better performance and log management
struct AppLogger {
    
    // MARK: - Subsystem Categories
    
    /// Core Data persistence operations
    static let persistence = Logger(subsystem: "com.familymenuplanner", category: "persistence")
    
    /// Application state management
    static let appState = Logger(subsystem: "com.familymenuplanner", category: "appState")
    
    /// Service layer operations
    static let service = Logger(subsystem: "com.familymenuplanner", category: "service")
    
    /// View model operations
    static let viewModel = Logger(subsystem: "com.familymenuplanner", category: "viewModel")
    
    /// Static data cache operations
    static let cache = Logger(subsystem: "com.familymenuplanner", category: "cache")
    
    /// iCloud sync operations
    static let cloudKit = Logger(subsystem: "com.familymenuplanner", category: "cloudKit")
    
    /// Menu generation and management
    static let menu = Logger(subsystem: "com.familymenuplanner", category: "menu")
    
    /// Data import/export operations
    static let dataImport = Logger(subsystem: "com.familymenuplanner", category: "dataImport")
    
    // MARK: - Convenience Methods
    
    /// Log a debug message for development
    static func debug(_ message: String, category: Logger = .general) {
        #if DEBUG
        category.debug("\(message)")
        #endif
    }
    
    /// Log informational message
    static func info(_ message: String, category: Logger = .general) {
        category.info("\(message)")
    }
    
    /// Log a warning message
    static func warning(_ message: String, category: Logger = .general) {
        category.warning("\(message)")
    }
    
    /// Log an error message
    static func error(_ message: String, error: Error? = nil, category: Logger = .general) {
        if let error = error {
            category.error("\(message): \(error.localizedDescription)")
        } else {
            category.error("\(message)")
        }
    }
    
    /// Log a critical error that may cause app failure
    static func critical(_ message: String, error: Error? = nil, category: Logger = .general) {
        if let error = error {
            category.critical("\(message): \(error.localizedDescription)")
        } else {
            category.critical("\(message)")
        }
    }
    
    /// Log performance metrics
    static func performance(_ message: String, duration: TimeInterval? = nil, category: Logger = .general) {
        if let duration = duration {
            category.info("📊 Performance: \(message) - Duration: \(String(format: "%.3f", duration))s")
        } else {
            category.info("📊 Performance: \(message)")
        }
    }
}

// MARK: - Logger Extensions

private extension Logger {
    /// General purpose logger for uncategorized messages
    static let general = Logger(subsystem: "com.familymenuplanner", category: "general")
}

// MARK: - Testing Support

#if DEBUG
extension AppLogger {
    /// Disable logging for tests to reduce noise
    static var isTestEnvironment: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               NSClassFromString("XCTestCase") != nil ||
               ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
               ProcessInfo.processInfo.environment["CI"] != nil
    }
}
#endif 