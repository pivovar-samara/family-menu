import XCTest
import CoreData
@testable import FamilyMenuPlanner

/// The preload version is stored only in this device's UserDefaults. A new device of an iCloud account imports
/// the preload data from CloudKit and must record the version instead of running generation over it.
final class PreloadVersionAdoptionTests: BaseIntegrationTest {
    private let versionKeys = ["PreloadDataVersion", "PreloadDataVersionSync"]
    private var savedVersions: [String: Any] = [:]
    private var persistence: PersistenceController { PersistenceController.shared }

    override func setUp() {
        super.setUp()
        for key in versionKeys {
            savedVersions[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in versionKeys {
            if let value = savedVersions[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testMissingVersionWithImportedPreloadDataRecordsVersionWithoutGeneration() throws {
        try populateStore(with: preloadData())

        XCTAssertFalse(persistence.isDatabaseEmptyOrOutdated(context: context))
        XCTAssertTrue(persistence.hasCurrentStaticData(context: context))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "PreloadDataVersion"), persistence.getCurrentPreloadDataVersion())
        XCTAssertEqual(UserDefaults.standard.string(forKey: "PreloadDataVersionSync"), persistence.getCurrentPreloadDataVersion())
    }

    func testMissingVersionAcceptsPreloadDataOfEveryBundledLanguage() throws {
        let variants = PersistenceController.loadAllLocalizedPreloadData()
        XCTAssertGreaterThanOrEqual(variants.count, 2, "Expected en and ru preload data in the app bundle")

        for variant in variants {
            cleanUpTestData()
            for key in versionKeys { UserDefaults.standard.removeObject(forKey: key) }
            try populateStore(with: variant)

            XCTAssertFalse(persistence.isDatabaseEmptyOrOutdated(context: context))
        }
    }

    func testMissingVersionWithEmptyStoreNeedsGeneration() {
        XCTAssertTrue(persistence.isDatabaseEmptyOrOutdated(context: context))
        XCTAssertNil(UserDefaults.standard.string(forKey: "PreloadDataVersion"))
    }

    func testMissingVersionWithPartialImportNeedsGeneration() throws {
        // Reference data arrived, products not yet (or they come from an older preload version)
        try populateStore(with: preloadData(), includeProducts: false)

        XCTAssertTrue(persistence.isDatabaseEmptyOrOutdated(context: context))
        XCTAssertNil(UserDefaults.standard.string(forKey: "PreloadDataVersion"))
    }

    func testMissingVersionWithDifferentReferenceDataNeedsGeneration() throws {
        let preload = preloadData()
        try populateStore(with: preload)
        _ = testDataFactory.createUnit(name: "Not in preload", sortOrder: 999)

        XCTAssertTrue(persistence.isDatabaseEmptyOrOutdated(context: context))
        XCTAssertNil(UserDefaults.standard.string(forKey: "PreloadDataVersion"))
    }

    func testOlderStoredVersionStillUpgrades() throws {
        try populateStore(with: preloadData())
        UserDefaults.standard.set("0.9", forKey: "PreloadDataVersion")
        UserDefaults.standard.set("0.9", forKey: "PreloadDataVersionSync")

        XCTAssertTrue(persistence.isDatabaseEmptyOrOutdated(context: context))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "PreloadDataVersion"), "0.9", "An outdated version must not be replaced without generation")
    }

    // MARK: - Helpers

    private func preloadData() -> PreloadedData {
        guard let data = PersistenceController.loadAllLocalizedPreloadData().first else {
            XCTFail("No preload data in the app bundle")
            return PreloadedData(units: [], products: [], dishes: [], mealTypes: [], dishCategories: [])
        }
        return data
    }

    /// Fills the store the way a CloudKit import of a seeded account would
    private func populateStore(with preload: PreloadedData, includeProducts: Bool = true) throws {
        var units: [String: Unit] = [:]
        for unitData in preload.units {
            units[unitData.name] = testDataFactory.createUnit(name: unitData.name, sortOrder: unitData.sortOrder)
        }
        for mealType in preload.mealTypes {
            _ = testDataFactory.createMealType(name: mealType.name, sortOrder: mealType.sortOrder)
        }
        for category in preload.dishCategories {
            _ = testDataFactory.createDishCategory(name: category.name, sortOrder: category.sortOrder)
        }
        if includeProducts {
            for productData in preload.products {
                let unit = try XCTUnwrap(units[productData.unit], "Unknown unit \(productData.unit)")
                _ = testDataFactory.createProduct(name: productData.name, unit: unit)
            }
        }
    }
}
