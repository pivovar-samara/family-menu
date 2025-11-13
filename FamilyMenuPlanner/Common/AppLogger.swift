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
/// Falls back to print statements in CI environments for better compatibility
struct AppLogger {
    
    // MARK: - CI Detection
    
    /// Check if running in CI environment early to avoid logging issues
    static let isCI: Bool = {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
               ProcessInfo.processInfo.environment["CI"] != nil ||
               ProcessInfo.processInfo.environment["BUILD_NUMBER"] != nil ||
               ProcessInfo.processInfo.arguments.contains("test") ||
               ProcessInfo.processInfo.arguments.contains("-XCTest") ||
               NSClassFromString("XCTestCase") != nil
    }()
    
    // MARK: - Subsystem Categories
    
    /// Core Data persistence operations
    static let persistence = isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "persistence")
    
    /// Application state management
    static let appState = isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "appState")
    
    /// Service layer operations
    static let service = isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "service")
    
    /// View model operations
    static let viewModel = isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "viewModel")
    
    /// Static data cache operations
    static let cache = isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "cache")
    
    /// iCloud sync operations
    static let cloudKit = isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "cloudKit")
    
    /// Menu generation and management
    static let menu = isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "menu")
    
    /// Data import/export operations
    static let dataImport = isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "dataImport")
    
    // MARK: - Convenience Methods
    
    /// Internal helper to mirror messages into the in-memory diagnostics buffer
    private static func capture(_ message: String) {
        AppLogCapture.shared.append(message)
    }
    
    /// Log a debug message for development
    static func debug(_ message: String, category: Logger? = .general) {
        #if DEBUG
        capture(message)
        if isCI {
            print("🔍 DEBUG: \(message)")
        } else {
            category?.debug("\(message, privacy: .public)")
        }
        #endif
    }
    
    /// Log informational message
    static func info(_ message: String, category: Logger? = .general) {
        capture(message)
        if isCI {
            print("ℹ️ INFO: \(message)")
        } else {
            category?.info("\(message, privacy: .public)")
        }
    }
    
    /// Log a warning message
    static func warning(_ message: String, category: Logger? = .general) {
        capture(message)
        if isCI {
            print("⚠️ WARNING: \(message)")
        } else {
            category?.warning("\(message, privacy: .public)")
        }
    }
    
    /// Log an error message
    static func error(_ message: String, error: Error? = nil, category: Logger? = .general) {
        let fullMessage = {
            if let error = error {
                return "\(message): \(error.localizedDescription)"
            } else {
                return message
            }
        }()
        capture(fullMessage)
        
        if isCI {
            print("❌ ERROR: \(fullMessage)")
        } else {
            if let error = error {
                category?.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                category?.error("\(message, privacy: .public)")
            }
        }
    }
    
    /// Log a critical error that may cause app failure
    static func critical(_ message: String, error: Error? = nil, category: Logger? = .general) {
        let fullMessage = {
            if let error = error {
                return "\(message): \(error.localizedDescription)"
            } else {
                return message
            }
        }()
        capture(fullMessage)
        
        if isCI {
            print("💥 CRITICAL: \(fullMessage)")
        } else {
            if let error = error {
                category?.critical("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                category?.critical("\(message, privacy: .public)")
            }
        }
    }
    
    /// Log performance metrics
    static func performance(_ message: String, duration: TimeInterval? = nil, category: Logger? = .general) {
        let fullMessage = {
            if let duration = duration {
                return "📊 Performance: \(message) - Duration: \(String(format: "%.3f", duration))s"
            } else {
                return "📊 Performance: \(message)"
            }
        }()
        capture(fullMessage)
        
        if isCI {
            print(fullMessage)
        } else {
            if let duration = duration {
                category?.info("📊 Performance: \(message, privacy: .public) - Duration: \(String(format: "%.3f", duration), privacy: .public)s")
            } else {
                category?.info("📊 Performance: \(message, privacy: .public)")
            }
        }
    }
}

// MARK: - Logger Extensions

private extension Logger {
    /// General purpose logger for uncategorized messages
    static let general: Logger? = AppLogger.isCI ? nil : Logger(subsystem: "com.familymenuplanner", category: "general")
}

// MARK: - Testing Support

#if DEBUG
extension AppLogger {
    /// Check if running in test environment
    static var isTestEnvironment: Bool {
        return isCI
    }
}
#endif 
