//
//  EditProductUnitTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
@testable import FamilyMenuPlanner

// MARK: - Mock Service
class MockEditProductService: EditProductServiceProtocol {
    var error: Error?
    var saveChangesCalled = false
    var rollbackCalled = false
    var units: [MockUnit] = []
    
    func saveChanges() throws {
        if let error = error {
            throw error
        }
        saveChangesCalled = true
    }
    
    func saveChangesInBackground(completion: @escaping (Result<Void, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
        } else {
            saveChangesCalled = true
            completion(.success(()))
        }
    }
    
    func rollback() {
        rollbackCalled = true
    }
    
    func fetchAllUnits() -> [Unit] {
        if let error = error {
            print("Error fetching units: \(error)")
            return []
        }
        // Convert MockUnit to Unit - in real tests we'd return the mock objects
        return []
    }
}

// MARK: - View Model for Unit Tests
class MockEditProductViewModel {
    var product: MockProduct
    var selectedUnit: MockUnit?
    var validationError: String?
    var units: [MockUnit] = []
    
    private let editProductService: MockEditProductService
    
    init(product: MockProduct, editProductService: MockEditProductService) {
        self.product = product
        self.editProductService = editProductService
        self.selectedUnit = product.unit
        self.units = editProductService.units
    }
    
    func saveChanges(completion: @escaping () -> Void) {
        guard validateProduct() else { return }
        
        do {
            product.unit = selectedUnit
            try editProductService.saveChanges()
            completion()
        } catch {
            validationError = "Error saving changes: \(error.localizedDescription)"
        }
    }
    
    func rollback() {
        editProductService.rollback()
    }
    
    func validateProduct() -> Bool {
        validationError = nil
        
        if product.name?.isEmpty ?? true {
            validationError = "Product name cannot be empty."
            return false
        }
        
        if selectedUnit == nil {
            validationError = "Please select a unit for the product."
            return false
        }
        
        return true
    }
    
    func setupSelectedUnit() {
        selectedUnit = product.unit
    }
}

// MARK: - Unit Tests
class EditProductUnitTests: XCTestCase {
    var mockService: MockEditProductService!
    var viewModel: MockEditProductViewModel!
    var testProduct: MockProduct!
    var testUnit: MockUnit!
    
    override func setUp() {
        super.setUp()
        mockService = MockEditProductService()
        testUnit = MockUnit(name: "pcs", sortOrder: 0)
        testProduct = MockProduct(name: "Test Product", unit: testUnit)
        viewModel = MockEditProductViewModel(product: testProduct, editProductService: mockService)
    }
    
    override func tearDown() {
        mockService = nil
        viewModel = nil
        testProduct = nil
        testUnit = nil
        super.tearDown()
    }
    
    // MARK: - Validation Tests
    
    func testValidateProduct() {
        // Test valid product
        XCTAssertTrue(viewModel.validateProduct())
        XCTAssertNil(viewModel.validationError)
        
        // Test empty name
        viewModel.product.name = ""
        XCTAssertFalse(viewModel.validateProduct())
        XCTAssertNotNil(viewModel.validationError)
        
        // Test nil name
        viewModel.product.name = nil
        XCTAssertFalse(viewModel.validateProduct())
        XCTAssertNotNil(viewModel.validationError)
        
        // Test missing unit
        viewModel.product.name = "Test"
        viewModel.selectedUnit = nil
        XCTAssertFalse(viewModel.validateProduct())
        XCTAssertNotNil(viewModel.validationError)
    }
    
    // MARK: - Save Tests
    
    func testSaveChangesSuccess() {
        var completionCalled = false
        
        // Save changes
        viewModel.saveChanges {
            completionCalled = true
        }
        
        // Verify changes were saved
        XCTAssertTrue(mockService.saveChangesCalled)
        XCTAssertTrue(completionCalled)
        XCTAssertNil(viewModel.validationError)
    }
    
    func testSaveChangesWithError() {
        var completionCalled = false
        mockService.error = NSError(domain: "test", code: -1, userInfo: nil)
        
        // Try to save changes
        viewModel.saveChanges {
            completionCalled = true
        }
        
        // Verify error handling
        XCTAssertFalse(completionCalled)
        XCTAssertNotNil(viewModel.validationError)
    }
    
    func testSaveChangesWithInvalidProduct() {
        var completionCalled = false
        viewModel.product.name = ""
        
        // Try to save changes
        viewModel.saveChanges {
            completionCalled = true
        }
        
        // Verify validation prevented save
        XCTAssertFalse(completionCalled)
        XCTAssertFalse(mockService.saveChangesCalled)
        XCTAssertNotNil(viewModel.validationError)
    }
    
    // MARK: - Rollback Tests
    
    func testRollback() {
        // Perform rollback
        viewModel.rollback()
        
        // Verify rollback was called
        XCTAssertTrue(mockService.rollbackCalled)
    }
    
    // MARK: - Unit Selection Tests
    
    func testSetupSelectedUnit() {
        // Change selected unit
        let newUnit = MockUnit(name: "g", sortOrder: 1)
        viewModel.selectedUnit = newUnit
        
        // Setup selected unit
        viewModel.setupSelectedUnit()
        
        // Verify unit is set to product's unit
        XCTAssertEqual(viewModel.selectedUnit, testProduct.unit)
    }
    
    func testChangeSelectedUnit() {
        // Change selected unit
        let newUnit = MockUnit(name: "g", sortOrder: 1)
        viewModel.selectedUnit = newUnit
        
        // Save changes
        var completionCalled = false
        viewModel.saveChanges {
            completionCalled = true
        }
        
        // Verify changes
        XCTAssertTrue(completionCalled)
        XCTAssertEqual(testProduct.unit, newUnit)
    }
} 