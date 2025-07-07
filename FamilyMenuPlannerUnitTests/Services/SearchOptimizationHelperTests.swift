//
//  SearchOptimizationHelperTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Performance Optimization on 28.01.25.
//

import XCTest
import Combine
@testable import FamilyMenuPlanner

/// Test model for SearchOptimizationHelper testing
struct TestItem: Equatable {
    let id: String
    let name: String?
    
    init(id: String, name: String?) {
        self.id = id
        self.name = name
    }
}

class SearchOptimizationHelperTests: XCTestCase {
    var searchHelper: SearchOptimizationHelper<TestItem>!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // Create helper with name-based filtering using inline predicate
        searchHelper = SearchOptimizationHelper<TestItem> { item, searchText in
            guard let name = item.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    override func tearDown() {
        cancellables = nil
        searchHelper = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialState() {
        XCTAssertTrue(searchHelper.filteredItems.isEmpty)
        XCTAssertTrue(searchHelper.searchText.isEmpty)
        XCTAssertFalse(searchHelper.isSearchActive)
    }
    
    func testUpdateItems() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: "Banana"),
            TestItem(id: "3", name: "Orange")
        ]
        
        searchHelper.updateItems(items)
        
        XCTAssertEqual(searchHelper.filteredItems.count, 3)
        XCTAssertEqual(searchHelper.currentFilteredItems.count, 3)
        XCTAssertFalse(searchHelper.isSearchActive)
    }
    
    func testSearchActiveState() {
        XCTAssertFalse(searchHelper.isSearchActive)
        
        searchHelper.searchText = "test"
        XCTAssertTrue(searchHelper.isSearchActive)
        
        searchHelper.searchText = "   "
        XCTAssertFalse(searchHelper.isSearchActive)
        
        searchHelper.searchText = ""
        XCTAssertFalse(searchHelper.isSearchActive)
    }
    
    // MARK: - Filtering Tests
    
    func testBasicFiltering() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: "Banana"),
            TestItem(id: "3", name: "Apricot")
        ]
        searchHelper.updateItems(items)
        
        let expectation = XCTestExpectation(description: "Filtering completes")
        
        searchHelper.searchText = "Ap"
        
        // Wait for debounce period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(self.searchHelper.filteredItems.count, 2)
            XCTAssertTrue(self.searchHelper.filteredItems.contains { $0.name == "Apple" })
            XCTAssertTrue(self.searchHelper.filteredItems.contains { $0.name == "Apricot" })
            XCTAssertFalse(self.searchHelper.filteredItems.contains { $0.name == "Banana" })
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCaseInsensitiveFiltering() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: "BANANA"),
            TestItem(id: "3", name: "Orange")
        ]
        searchHelper.updateItems(items)
        
        let expectation = XCTestExpectation(description: "Case insensitive filtering")
        
        searchHelper.searchText = "apple"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(self.searchHelper.filteredItems.count, 1)
            XCTAssertEqual(self.searchHelper.filteredItems.first?.name, "Apple")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFilteringWithNilNames() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: nil),
            TestItem(id: "3", name: "Banana")
        ]
        searchHelper.updateItems(items)
        
        let expectation = XCTestExpectation(description: "Nil name filtering")
        
        searchHelper.searchText = "Apple"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(self.searchHelper.filteredItems.count, 1)
            XCTAssertEqual(self.searchHelper.filteredItems.first?.name, "Apple")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testEmptySearchShowsAllItems() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: "Banana"),
            TestItem(id: "3", name: "Orange")
        ]
        searchHelper.updateItems(items)
        
        let expectation = XCTestExpectation(description: "Empty search shows all")
        
        // First set search text
        searchHelper.searchText = "App"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // Then clear it
            self.searchHelper.searchText = ""
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                XCTAssertEqual(self.searchHelper.filteredItems.count, 3)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testWhitespaceHandling() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: "Banana")
        ]
        searchHelper.updateItems(items)
        
        let expectation = XCTestExpectation(description: "Whitespace handling")
        
        searchHelper.searchText = "   Apple   "
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(self.searchHelper.filteredItems.count, 1)
            XCTAssertEqual(self.searchHelper.filteredItems.first?.name, "Apple")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Performance Optimization Tests
    
    func testDuplicateResultOptimization() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: "Banana")
        ]
        searchHelper.updateItems(items)
        
        var updateCount = 0
        
        // Monitor filtered items changes
        searchHelper.$filteredItems
            .sink { _ in
                updateCount += 1
            }
            .store(in: &cancellables)
        
        let expectation = XCTestExpectation(description: "Duplicate result optimization")
        
        // Set the same search text multiple times
        searchHelper.searchText = "Apple"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.searchHelper.searchText = "Apple"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.searchHelper.searchText = "Apple"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // Should only trigger one update after the initial state
                    // (initial empty state + one actual update)
                    XCTAssertLessThanOrEqual(updateCount, 3)
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.5)
    }
    
    func testDebounceEffectiveness() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: "Application"),
            TestItem(id: "3", name: "Banana")
        ]
        searchHelper.updateItems(items)
        
        var updateCount = 0
        
        searchHelper.$filteredItems
            .dropFirst() // Skip initial empty state
            .sink { _ in
                updateCount += 1
            }
            .store(in: &cancellables)
        
        let expectation = XCTestExpectation(description: "Debounce effectiveness")
        
        // Rapidly change search text
        searchHelper.searchText = "A"
        searchHelper.searchText = "Ap"
        searchHelper.searchText = "App"
        searchHelper.searchText = "Appl"
        searchHelper.searchText = "Apple"
        
        // Wait for debounce to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Should only have one update due to debouncing
            XCTAssertEqual(updateCount, 1)
            XCTAssertEqual(self.searchHelper.filteredItems.count, 1)
            XCTAssertEqual(self.searchHelper.filteredItems.first?.name, "Apple")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyItemsList() {
        searchHelper.updateItems([])
        
        let expectation = XCTestExpectation(description: "Empty items list")
        
        searchHelper.searchText = "test"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertTrue(self.searchHelper.filteredItems.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNoMatchingResults() {
        let items = [
            TestItem(id: "1", name: "Apple"),
            TestItem(id: "2", name: "Banana")
        ]
        searchHelper.updateItems(items)
        
        let expectation = XCTestExpectation(description: "No matching results")
        
        searchHelper.searchText = "Orange"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertTrue(self.searchHelper.filteredItems.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Custom Filter Predicate Tests
    
    func testCustomFilterPredicate() {
        // Create helper with custom predicate that matches by ID
        let customHelper = SearchOptimizationHelper<TestItem> { item, searchText in
            return item.id.contains(searchText)
        }
        
        let items = [
            TestItem(id: "item1", name: "Apple"),
            TestItem(id: "item2", name: "Banana"),
            TestItem(id: "product1", name: "Orange")
        ]
        customHelper.updateItems(items)
        
        let expectation = XCTestExpectation(description: "Custom filter predicate")
        
        customHelper.searchText = "item"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(customHelper.filteredItems.count, 2)
            XCTAssertTrue(customHelper.filteredItems.contains { $0.id == "item1" })
            XCTAssertTrue(customHelper.filteredItems.contains { $0.id == "item2" })
            XCTAssertFalse(customHelper.filteredItems.contains { $0.id == "product1" })
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        weak var weakHelper: SearchOptimizationHelper<TestItem>?
        
        autoreleasepool {
            let helper = SearchOptimizationHelper<TestItem> { item, searchText in
                guard let name = item.name else { return false }
                return name.localizedCaseInsensitiveContains(searchText)
            }
            weakHelper = helper
            
            let items = [TestItem(id: "1", name: "Test")]
            helper.updateItems(items)
            helper.searchText = "Test"
        }
        
        // Helper should be deallocated
        XCTAssertNil(weakHelper)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetPerformance() {
        let largeItemSet = (1...1000).map { i in
            TestItem(id: "\(i)", name: "Item \(i)")
        }
        
        searchHelper.updateItems(largeItemSet)
        
        let expectation = XCTestExpectation(description: "Large dataset performance")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        searchHelper.searchText = "Item 1"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let endTime = CFAbsoluteTimeGetCurrent()
            let executionTime = endTime - startTime
            
            // Should complete within reasonable time (less than 1 second)
            XCTAssertLessThan(executionTime, 1.0)
            
            // Should find all items containing "Item 1" (Item 1, Item 10, Item 11, etc.)
            XCTAssertGreaterThan(self.searchHelper.filteredItems.count, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
} 
