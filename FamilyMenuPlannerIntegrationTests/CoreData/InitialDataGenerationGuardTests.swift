import XCTest
import CoreData
@testable import FamilyMenuPlanner

/// Generation must not be skipped just because UserDefaults records the current preload version:
/// an iCloud account change purges the store and leaves that version behind.
final class InitialDataGenerationGuardTests: BaseIntegrationTest {
    private let versionKeys = ["PreloadDataVersion", "PreloadDataVersionSync"]
    private var savedVersions: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        let version = PersistenceController.shared.getCurrentPreloadDataVersion()
        for key in versionKeys {
            savedVersions[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.set(version, forKey: key)
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

    func testPurgedStoreWithCurrentVersionRecordedNeedsGeneration() {
        XCTAssertFalse(PersistenceController.shared.hasCurrentStaticData(context: context))
    }

    func testIncompleteStaticDataWithCurrentVersionRecordedNeedsGeneration() {
        _ = createUnit(name: "kg")
        saveContext()

        XCTAssertFalse(PersistenceController.shared.hasCurrentStaticData(context: context))
    }
}
