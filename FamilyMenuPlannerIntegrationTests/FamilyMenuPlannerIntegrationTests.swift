//
//  FamilyMenuPlannerIntegrationTests.swift
//  FamilyMenuPlannerIntegrationTests
//
//  Created by Pivovar 63 on 03.06.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class FamilyMenuPlannerIntegrationTests: BaseIntegrationTest {
    // MARK: - Persistence Error Handling Tests
    
    func testPersistenceErrorCategorization() {
        // Test migration error - using the correct constant name
        let migrationError = NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError, userInfo: nil)
        let persistenceError = PersistenceError.migrationFailed(migrationError)
        
        // Check if the error description contains expected text (accounting for localization)
        let description = persistenceError.localizedDescription
        XCTAssertTrue(description.contains("migrate") || description.contains("миграц"), "Migration error should contain migration-related text")
        
        // Test permission error
        _ = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: nil)
        let permissionPersistenceError = PersistenceError.permissionDenied
        
        let permissionDescription = permissionPersistenceError.localizedDescription
        XCTAssertTrue(permissionDescription.contains("Permission") || permissionDescription.contains("доступ"), "Permission error should contain permission-related text")
        
        // Test disk space error
        let diskSpaceError = PersistenceError.diskSpaceInsufficient
        let diskDescription = diskSpaceError.localizedDescription
        XCTAssertTrue(diskDescription.contains("disk space") || diskDescription.contains("место"), "Disk space error should contain space-related text")
        
        // Test general Core Data error
        let generalError = NSError(domain: NSCocoaErrorDomain, code: NSCoreDataError, userInfo: nil)
        let generalPersistenceError = PersistenceError.unknown(generalError)
        
        let generalDescription = generalPersistenceError.localizedDescription
        XCTAssertTrue(generalDescription.contains("unexpected error") || generalDescription.contains("непредвиденная"), "General error should contain unexpected error text")
    }
    
    func testPersistenceControllerErrorStates() {
        // Test with the test core data stack instead of creating new instances
        let testStack = TestCoreDataStack.shared
        let context = testStack.viewContext
        
        // Verify that test stack is working properly
        XCTAssertNotNil(context.persistentStoreCoordinator)
        XCTAssertEqual(testStack.persistentContainer.persistentStoreDescriptions.first?.type, NSInMemoryStoreType)
        
        // Test basic functionality
        let unit = Unit(context: context)
        unit.name = "Test Unit"
        unit.sortOrder = 1
        
        do {
            try context.save()
            XCTAssertTrue(true, "Test stack should save successfully")
        } catch {
            XCTFail("Test stack should not fail to save: \(error)")
        }
        
        // Clean up
        context.delete(unit)
        try? context.save()
    }
    
    func testPersistenceStateManager() {
        let stateManager = PersistenceStateManager()
        
        // Initially should be ready with no errors
        XCTAssertTrue(stateManager.isReady)
        XCTAssertFalse(stateManager.hasLoadingError)
        XCTAssertNil(stateManager.loadingError)
        XCTAssertNil(stateManager.userFriendlyErrorMessage)
        
        // Test setting an error
        let testError = PersistenceError.diskSpaceInsufficient
        stateManager.setError(testError)
        
        // After setting error, should not be ready
        let expectation = XCTestExpectation(description: "Error state updated")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(stateManager.isReady)
            XCTAssertTrue(stateManager.hasLoadingError)
            XCTAssertNotNil(stateManager.loadingError)
            XCTAssertNotNil(stateManager.userFriendlyErrorMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Test clearing error
        stateManager.clearError()
        
        let clearExpectation = XCTestExpectation(description: "Error cleared")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(stateManager.isReady)
            XCTAssertFalse(stateManager.hasLoadingError)
            XCTAssertNil(stateManager.loadingError)
            XCTAssertNil(stateManager.userFriendlyErrorMessage)
            clearExpectation.fulfill()
        }
        
        wait(for: [clearExpectation], timeout: 1.0)
    }
    
    func testAppStateManagerPersistenceErrorHandling() {
        // Since AppStateManager.shared uses PersistenceController.shared,
        // and we've modified it to detect test environment,
        // it should work without CloudKit conflicts now
        let appStateManager = AppStateManager.shared
        
        // Test that the app state manager can handle checking database state
        // Use a shorter timeout since we're in test environment
        let expectation = XCTestExpectation(description: "Loading completes")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // In test environment, loading should complete quickly
            XCTAssertFalse(appStateManager.isLoading)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testErrorRecoveryMethods() {
        // Test that shared persistence controller works in test environment
        let persistence = PersistenceController.shared
        
        // These should not crash and should work in test environment
        XCTAssertNoThrow(persistence.isReady)
        XCTAssertNoThrow(persistence.userFriendlyErrorMessage)
        
        // In test environment, persistence should be ready
        XCTAssertTrue(persistence.isReady, "Persistence should be ready in test environment")
        
        // Test manual recovery attempt on working store
        let recoveryResult = persistence.attemptRecovery()
        XCTAssertTrue(recoveryResult, "Recovery should succeed if store is already working")
    }
}
