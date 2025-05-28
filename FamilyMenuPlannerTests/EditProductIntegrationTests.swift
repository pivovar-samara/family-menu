//
//  EditProductIntegrationTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class EditProductIntegrationTests: BaseIntegrationTest {
    var editProductService: EditProductService!
    var viewModel: EditProductViewModel!
    var testProduct: Product!
    
    override func setUp() {
        super.setUp()
        setupTestData()
    }
    
    override func tearDown() {
        editProductService = nil
        viewModel = nil
        testProduct = nil
        super.tearDown()
    }
    
    private func setupTestData() {
        // Create units
        let pieces = createUnit(name: "pcs")
        _ = createUnit(name: "g", sortOrder: 1)  // Create but don't need to reference
        
        // Create test product
        testProduct = createProduct(name: "Test Product", unit: pieces)
        
        // Initialize service and view model
        editProductService = EditProductService(context: context)
        viewModel = EditProductViewModel(product: testProduct, editProductService: editProductService)
    }
    
    // MARK: - Tests
    
    func testEditProductName() {
        // Change product name
        viewModel.product.name = "Updated Product"
        
        // Save changes
        var saveSuccessful = false
        viewModel.saveChanges {
            saveSuccessful = true
        }
        
        // Verify changes were saved
        XCTAssertTrue(saveSuccessful)
        XCTAssertEqual(testProduct.name, "Updated Product")
        
        // Verify changes persist after refresh
        context.refreshAllObjects()
        XCTAssertEqual(testProduct.name, "Updated Product")
    }
    
    func testChangeProductUnit() {
        // Get available units
        let units = viewModel.units
        XCTAssertEqual(units.count, 2)
        
        // Get the unit that's not currently selected
        let newUnit = units.first { $0 != testProduct.unit }!
        
        // Change unit
        viewModel.selectedUnit = newUnit
        viewModel.product.unit = newUnit
        
        // Save changes
        var saveSuccessful = false
        viewModel.saveChanges {
            saveSuccessful = true
        }
        
        // Verify changes were saved
        XCTAssertTrue(saveSuccessful)
        XCTAssertEqual(testProduct.unit, newUnit)
        
        // Verify changes persist after refresh
        context.refreshAllObjects()
        XCTAssertEqual(testProduct.unit, newUnit)
    }
    
    func testRollback() {
        // Store original values
        let originalName = testProduct.name
        let originalUnit = testProduct.unit
        
        // Make changes
        viewModel.product.name = "Changed Name"
        viewModel.selectedUnit = viewModel.units.first { $0 != originalUnit }
        
        // Rollback changes
        viewModel.rollback()
        
        // Verify original values are restored
        XCTAssertEqual(testProduct.name, originalName)
        XCTAssertEqual(testProduct.unit, originalUnit)
    }
    
    func testValidation() {
        // Test empty name
        viewModel.product.name = ""
        var saveSuccessful = false
        viewModel.saveChanges {
            saveSuccessful = true
        }
        XCTAssertFalse(saveSuccessful)
        
        // Test valid name
        viewModel.product.name = "Valid Name"
        saveSuccessful = false
        viewModel.saveChanges {
            saveSuccessful = true
        }
        XCTAssertTrue(saveSuccessful)
    }
    
    func testSetupSelectedUnit() {
        // Initial setup
        viewModel.setupSelectedUnit()
        XCTAssertEqual(viewModel.selectedUnit, testProduct.unit)
        
        // Change unit and setup again
        let newUnit = viewModel.units.first { $0 != testProduct.unit }!
        testProduct.unit = newUnit
        viewModel.setupSelectedUnit()
        XCTAssertEqual(viewModel.selectedUnit, newUnit)
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveWithNilName() {
        // Set name to nil
        viewModel.product.name = nil
        
        // Create expectation for alert
        let exp = expectation(description: "Alert shown")
        
        // Try to save
        var saveSuccessful = false
        viewModel.saveChanges {
            saveSuccessful = true
        }
        
        // Wait a short time for alert to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify save failed and alert was shown
            XCTAssertFalse(saveSuccessful)
            XCTAssertNotNil(self.viewModel.currentAlert)
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func testConcurrentEditing() {
        // Create expectation for async operations
        let exp = expectation(description: "Concurrent editing")
        
        // Simulate another context modifying the same product
        let otherContext = TestCoreDataStack.shared.persistentContainer.newBackgroundContext()
        let otherProductID = testProduct.objectID
        
        // First, modify in background context
        otherContext.performAndWait {
            let otherProduct = otherContext.object(with: otherProductID) as! Product
            otherProduct.name = "Changed by other context"
            try? otherContext.save()
        }
        
        // Ensure main context is refreshed to see the changes
        context.refreshAllObjects()
        
        // Now try to save our changes
        viewModel.product.name = "Our change"
        var saveSuccessful = false
        viewModel.saveChanges {
            saveSuccessful = true
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
        
        // Verify save was successful (last write wins)
        XCTAssertTrue(saveSuccessful)
        
        // Refresh and verify our change won (last write wins)
        context.refreshAllObjects()
        XCTAssertEqual(testProduct.name, "Our change")
        
        // Verify the change is also visible in the other context
        otherContext.performAndWait {
            otherContext.refreshAllObjects()
            let otherProduct = otherContext.object(with: otherProductID) as! Product
            XCTAssertEqual(otherProduct.name, "Our change")
        }
    }
    
    func testUnitValidation() {
        // Remove unit
        viewModel.product.unit = nil
        viewModel.selectedUnit = nil
        
        // Try to save
        var saveSuccessful = false
        viewModel.saveChanges {
            saveSuccessful = true
        }
        
        // Save should still succeed as unit is optional
        XCTAssertTrue(saveSuccessful)
        XCTAssertNil(testProduct.unit)
    }
} 