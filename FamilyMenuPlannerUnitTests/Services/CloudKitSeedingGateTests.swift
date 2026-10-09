import XCTest
import CloudKit
@testable import FamilyMenuPlanner

final class CloudKitSeedingGateUnitTests: XCTestCase {
    override func setUpWithError() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Skipping CloudKitSeedingGate tests on simulator")
        #endif
    }
    func testWaitForImportOrTimeoutTimesOut() async {
        let didImport = await CloudKitSeedingGate.waitForImportOrTimeout(timeout: 0.05)
        XCTAssertFalse(didImport)
    }

    func testWaitForImportOrRemoteEmptyTimesOutQuickly() async {
        // Small maxWait to avoid any real CloudKit polling - function should return .timedOut
        let outcome = await CloudKitSeedingGate.waitForImportOrRemoteEmpty(maxWait: 0.2)
        XCTAssertEqual(outcome, .timedOut)
    }
}


final class CloudKitSeedingGatePureTests: XCTestCase {
    func testVersionSatisfiesWhenEqual() {
        XCTAssertTrue(CloudKitSeedingGate.doesStoredSeedVersionSatisfy(stored: "1.1", required: "1.1"))
    }

    func testVersionDoesNotSatisfyWhenNil() {
        XCTAssertFalse(CloudKitSeedingGate.doesStoredSeedVersionSatisfy(stored: nil, required: "1.1"))
    }

    func testVersionDoesNotSatisfyWhenEmpty() {
        XCTAssertFalse(CloudKitSeedingGate.doesStoredSeedVersionSatisfy(stored: "", required: "1.1"))
    }

    func testVersionDoesNotSatisfyWhenDifferent() {
        XCTAssertFalse(CloudKitSeedingGate.doesStoredSeedVersionSatisfy(stored: "1.0", required: "1.1"))
    }
}


final class CloudKitSeedingLeaseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testLeaseWithoutTimestampIsStale() {
        XCTAssertTrue(CloudKitSeedingGate.isLeaseStale(leaseDate: nil, now: now))
    }

    func testFreshLeaseIsNotStale() {
        XCTAssertFalse(CloudKitSeedingGate.isLeaseStale(leaseDate: now.addingTimeInterval(-60), now: now))
    }

    func testLeaseOlderThanIntervalIsStale() {
        let leaseDate = now.addingTimeInterval(-(CloudKitSeedingGate.staleLeaseInterval + 1))
        XCTAssertTrue(CloudKitSeedingGate.isLeaseStale(leaseDate: leaseDate, now: now))
    }

    func testGateUsesEntitledContainerNotBundleDefault() {
        XCTAssertEqual(CloudKitSeedingGate.containerIdentifier, "iCloud.container.menu")
        XCTAssertEqual(LiveCloudKitSeedingService().containerIdentifier, "iCloud.container.menu")
    }
}

final class CloudKitSeedingLeaseAcquisitionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func existingLease(age: TimeInterval) -> CKRecord {
        let record = CKRecord(recordType: CloudKitSeedingGate.seedAnchorRecordName,
                              recordID: CKRecord.ID(recordName: CloudKitSeedingGate.seedAnchorRecordName))
        record["timestamp"] = now.addingTimeInterval(-age) as CKRecordValue
        return record
    }

    func testCreatesLeaseWhenNoneExists() async {
        let database = MockRecordDatabase()

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertTrue(acquired)
        XCTAssertEqual(database.savedRecords.count, 1)
        XCTAssertEqual(database.savedRecords.first?["timestamp"] as? Date, now)
    }

    func testFreshLeaseHeldByAnotherDeviceIsNotAcquired() async {
        let database = MockRecordDatabase()
        database.serverRecord = existingLease(age: 60)

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertFalse(acquired)
        XCTAssertEqual(database.savedRecords.count, 1, "Only the create attempt, no takeover")
    }

    func testStaleLeaseIsTakenOverByUpdatingServerRecord() async {
        let database = MockRecordDatabase()
        let server = existingLease(age: CloudKitSeedingGate.staleLeaseInterval + 60)
        database.serverRecord = server

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertTrue(acquired)
        XCTAssertEqual(database.savedRecords.count, 2)
        // The takeover saves the fetched server record (carrying its change tag), not a fresh one
        XCTAssertTrue(database.savedRecords.last === server)
        XCTAssertEqual(server["timestamp"] as? Date, now)
    }

    func testCompetingTakeoverIsRejected() async {
        let database = MockRecordDatabase()
        database.serverRecord = existingLease(age: CloudKitSeedingGate.staleLeaseInterval + 60)
        // Another device updates the lease between our fetch and our save
        database.rejectTakeover = true

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertFalse(acquired)
    }

    func testSaveErrorDoesNotAcquireLease() async {
        let database = MockRecordDatabase()
        database.createError = CKError(.networkUnavailable)

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertFalse(acquired)
    }
}

/// Mimics `.ifServerRecordUnchanged` saves of a single record
private final class MockRecordDatabase: CloudKitRecordSaving {
    /// The lease already on the server, if any
    var serverRecord: CKRecord?
    var createError: Error?
    var rejectTakeover = false
    private(set) var savedRecords: [CKRecord] = []

    func save(_ record: CKRecord) async throws -> CKRecord {
        savedRecords.append(record)
        if let createError { throw createError }
        if let serverRecord {
            if record === serverRecord && !rejectTakeover {
                return record
            }
            throw CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: serverRecord])
        }
        serverRecord = record
        return record
    }
}
