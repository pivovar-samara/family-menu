import XCTest
import CoreData
@testable import FamilyMenuPlanner

class CachePerformanceTests: BaseIntegrationTest {
    var persistenceController: PersistenceController!
    var cacheManager: StaticDataCacheManager!
    
    override func setUp() async throws {
        try await super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        testDataFactory = TestDataFactory(context: context)
        cleanUpTestData()
        
        cacheManager = StaticDataCacheManager.createTestInstance()
        cacheManager.initialize(with: context)
        cacheManager.invalidateCacheSync()
    }
    
    override func tearDown() async throws {
        cacheManager?.invalidateCacheSync()
        cleanUpTestData()
        cacheManager = nil
        persistenceController = nil
        testDataFactory = nil
        try await super.tearDown()
    }
    
    func testCacheFirstLoadPerformance() {
        // Create test data
        createUnitsInBackground(count: 100)
        
        // Give a moment for any pending notifications to settle
        let expectation = XCTestExpectation(description: "Settle notifications")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        cacheManager.invalidateCacheSync()
        
        measure {
            let _ = cacheManager.getUnits()
        }
    }
    
    func testCacheSubsequentAccessPerformance() {
        // Create test data and prime cache
        createUnitsInBackground(count: 100)
        
        // Give a moment for any pending notifications to settle
        let expectation = XCTestExpectation(description: "Settle notifications")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        cacheManager.invalidateCacheSync()
        let _ = cacheManager.getUnits() // Prime the cache
        
        measure {
            for _ in 0..<1000 {
                let _ = cacheManager.getUnits()
            }
        }
    }
    
    func testMealTypeCachePerformance() {
        // Create test meal types
        for i in 1...50 {
            _ = createMealType(name: "Meal Type \(i)", sortOrder: Int16(i))
        }
        
        cacheManager.invalidateCacheSync()
        
        measure {
            let _ = cacheManager.getMealTypes()
        }
    }
    
    func testDishCategoryCachePerformance() {
        // Create test dish categories
        for i in 1...50 {
            _ = createDishCategory(name: "Category \(i)", sortOrder: Int16(i))
        }
        
        cacheManager.invalidateCacheSync()
        
        measure {
            let _ = cacheManager.getDishCategories()
        }
    }
    
    func testCacheInvalidationPerformance() {
        // Create test data
        createUnitsInBackground(count: 100)
        
        // Prime the cache
        let _ = cacheManager.getUnits()
        let _ = cacheManager.getMealTypes()
        let _ = cacheManager.getDishCategories()
        
        measure {
            cacheManager.invalidateCacheSync()
        }
    }
    
    private func createUnitsInBackground(count: Int) {
        let backgroundContext = persistenceController.newBackgroundContext()
        
        backgroundContext.performAndWait {
            guard let entityDescription = NSEntityDescription.entity(forEntityName: "Unit", in: backgroundContext) else {
                XCTFail("Failed to get Unit entity description")
                return
            }
            
            for i in 1...count {
                let unit = Unit(entity: entityDescription, insertInto: backgroundContext)
                unit.name = "Unit \(i)"
                unit.sortOrder = Int16(i)
            }
            
            do {
                try backgroundContext.save()
            } catch {
                XCTFail("Failed to save units: \(error)")
            }
        }
        
        context.performAndWait {
            context.refreshAllObjects()
        }
    }
} 