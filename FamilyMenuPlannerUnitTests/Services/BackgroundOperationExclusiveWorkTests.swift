import XCTest
import CoreData
@testable import FamilyMenuPlanner

/// The store reload for a CloudKit mirroring restart runs through `runExclusivelyOnMain`: it must not overlap
/// background writes queued before or after it.
final class BackgroundOperationExclusiveWorkTests: XCTestCase {
    private let lock = NSLock()
    private var events: [String] = []

    private func record(_ event: String) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func testExclusiveWorkWaitsForPendingWriteAndBlocksLaterOnes() {
        let manager = BackgroundOperationManager(testPersistenceController: PersistenceController.shared)
        let firstWrite = expectation(description: "Write queued before")
        let exclusive = expectation(description: "Exclusive work")
        let laterWrite = expectation(description: "Write queued after")

        manager.executeBulkOperation(operation: { _ in
            self.record("write before: start")
            Thread.sleep(forTimeInterval: 0.2)
            self.record("write before: end")
        }, completion: { _ in firstWrite.fulfill() })

        manager.runExclusivelyOnMain {
            XCTAssertTrue(Thread.isMainThread)
            self.record("exclusive: start")
            Thread.sleep(forTimeInterval: 0.2)
            self.record("exclusive: end")
            exclusive.fulfill()
        }

        manager.executeBulkOperation(operation: { _ in
            self.record("write after")
        }, completion: { _ in laterWrite.fulfill() })

        wait(for: [firstWrite, exclusive, laterWrite], timeout: 5)
        XCTAssertEqual(events, ["write before: start", "write before: end", "exclusive: start", "exclusive: end", "write after"])
    }
}
