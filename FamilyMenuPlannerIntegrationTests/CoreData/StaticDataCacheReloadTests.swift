import XCTest
import CoreData
@testable import FamilyMenuPlanner

/// After a purge the cache can load empty collections before re-seeding finishes; `reload(with:completion:)`
/// must then pick up the seeded data, which `initialize(with:)` would keep as already loaded.
final class StaticDataCacheReloadTests: BaseIntegrationTest {
    func testReloadAfterReseedingShowsSeededData() {
        let cache = StaticDataCacheManager.shared
        // Purged store: the cache loads (empty) collections and marks them loaded
        cache.invalidateCacheSync()
        XCTAssertTrue(cache.getUnits().isEmpty)
        XCTAssertTrue(cache.getMealTypes().isEmpty)

        // Seeding finishes
        _ = createUnit(name: "kg")
        _ = createMealType(name: "Lunch")
        _ = createDishCategory(name: "Soups")
        saveContext()

        // What initialize alone would do: keep the empty collections
        cache.initialize(with: context)
        XCTAssertTrue(cache.getUnits().isEmpty, "initialize keeps already loaded collections")

        let reloaded = expectation(description: "Cache reloaded")
        cache.reload(with: context) { reloaded.fulfill() }
        wait(for: [reloaded], timeout: 5)

        XCTAssertEqual(cache.getUnits().map(\.name), ["kg"])
        XCTAssertEqual(cache.getMealTypes().map(\.name), ["Lunch"])
        XCTAssertEqual(cache.getDishCategories().map(\.name), ["Soups"])
    }
}
