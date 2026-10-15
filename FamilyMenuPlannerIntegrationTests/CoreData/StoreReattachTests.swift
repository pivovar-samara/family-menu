import XCTest
import CoreData
@testable import FamilyMenuPlanner

/// The store reload for a CloudKit mirroring restart must report a failed re-add (not fall back to another
/// store), and a later attempt must be able to re-add the store with its data.
final class StoreReattachTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("StoreReattachTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func reattach(_ container: NSPersistentContainer) -> Error? {
        var result: Error?
        let done = expectation(description: "Reattached")
        PersistenceController.reattachStores(of: container) { error in
            result = error
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return result
    }

    func testFailedReaddReportsErrorAndCanBeRetried() throws {
        let model = TestCoreDataStack.shared.persistentContainer.managedObjectModel
        let container = NSPersistentContainer(name: "FamilyMenuPlanner", managedObjectModel: model)
        let storeURL = directory.appendingPathComponent("Store.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError)

        let unit = Unit(context: container.viewContext)
        unit.name = "kg"
        try container.viewContext.save()

        // Re-adding fails: the store's parent "directory" is a regular file
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: blocker)
        description.url = blocker.appendingPathComponent("Store.sqlite")
        XCTAssertNotNil(reattach(container))
        XCTAssertTrue(container.persistentStoreCoordinator.persistentStores.isEmpty, "No fallback store is attached")

        // A later attempt re-adds the original store with its data
        description.url = storeURL
        XCTAssertNil(reattach(container))
        XCTAssertEqual(try container.viewContext.count(for: Unit.fetchRequest()), 1)
    }
}
