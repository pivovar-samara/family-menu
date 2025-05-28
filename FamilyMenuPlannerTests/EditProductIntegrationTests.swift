//
//  EditProductIntegrationTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class EditProductIntegrationTests: XCTestCase {
    var context: NSManagedObjectContext!
    var editProductService: EditProductService!
    var viewModel: EditProductViewModel!
    var testProduct: Product!
    
    override func setUp() {
        super.setUp()
        context = TestCoreDataStack.shared.viewContext
        cleanUpTestData()
        setupTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        context = nil
        editProductService = nil
        viewModel = nil
        testProduct = nil
        super.tearDown()
    }
    
    private func cleanUpTestData() {
        let entities = ["Product", "Unit"]
        
        for entityName in entities {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: entityName)
            do {
                let objects = try context.fetch(fetchRequest)
                for object in objects {
                    context.delete(object)
                }
            } catch {
                print("Error cleaning up \(entityName): \(error)")
            }
        }
        
        try? context.save()
    }
    
    private func setupTestData() {
        // Create units
        let pieces = Unit(context: context)
        pieces.name = "pcs"
        pieces.sortOrder = 0
        
        let grams = Unit(context: context)
        grams.name = "g"
        grams.sortOrder = 1
        
        // Create test product
        testProduct = Product(context: context)
        testProduct.name = "Test Product"
        testProduct.unit = pieces
        
        try? context.save()
        context.refreshAllObjects()
        
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
} 